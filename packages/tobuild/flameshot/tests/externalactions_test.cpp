// SPDX-License-Identifier: GPL-3.0-or-later
#include "externalactions.h"
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>
#include <csignal>
#include <cerrno>

class ExternalActionsTest : public QObject
{
    Q_OBJECT
    ExternalAction action(const QStringList& arguments)
    {
        ExternalAction a;
        a.program = "/usr/bin/python3";
        a.arguments = QStringList{ HELPER } + arguments;
        return a;
    }
    QByteArray read(const QString& path)
    {
        QFile f(path);
        if (!f.open(QIODevice::ReadOnly))
            return {};
        return f.readAll();
    }
    void write(const QString& path, const QByteArray& data)
    {
        QFile f(path);
        QVERIFY(f.open(QIODevice::WriteOnly));
        QCOMPARE(f.write(data), qint64(data.size()));
    }

private slots:
    void configuration()
    {
        QTemporaryDir dir;
        const auto old = qgetenv("XDG_CONFIG_HOME");
        qputenv("XDG_CONFIG_HOME", dir.path().toUtf8());
        const QString path = dir.path() + "/flameshot/actions.d/";
        QVERIFY(QDir().mkpath(path));
        const QJsonObject good{
            { "name", "Show on TV" }, { "program", "/usr/bin/python3" },
            { "arguments", QJsonArray{ "/absolute/path/send-to-tv.py" } },
            { "shortcut", "Ctrl+Shift+T" }, { "icon", "video-display" }, { "timeout", 60000 }
        };
        write(path + "b.json", QJsonDocument(good).toJson());
        auto minimal = good;
        minimal.remove("timeout");
        minimal.remove("icon");
        minimal.remove("shortcut");
        write(path + "a.json", QJsonDocument(minimal).toJson());
        auto actions = loadExternalActions();
        QCOMPARE(actions.size(), 2);
        QCOMPARE(actions[0].timeout, 60000);
        QVERIFY(actions[0].shortcut.isEmpty());
        QCOMPARE(actions[1].shortcut, QString("Ctrl+Shift+T"));
        QCOMPARE(actions[1].arguments, QStringList{ "/absolute/path/send-to-tv.py" });
        int i = 0;
        for (const auto& field : QStringList{ "name", "program", "arguments", "timeout", "shortcut", "icon" }) {
            auto bad = good;
            bad[field] = false;
            write(path + QString("bad%1.json").arg(i++), QJsonDocument(bad).toJson());
        }
        for (const auto& value : QList<QJsonValue>{ 0, -1, 300001, 1.5, "60000" }) {
            auto bad = good;
            bad["timeout"] = value;
            write(path + QString("bad%1.json").arg(i++), QJsonDocument(bad).toJson());
        }
        for (const auto& value : QStringList{ "relative/program", QString("/bin/a") + QChar::Null + "b" }) {
            auto bad = good;
            bad["program"] = value;
            write(path + QString("bad%1.json").arg(i++), QJsonDocument(bad).toJson());
        }
        auto bad = good;
        bad["arguments"] = QJsonArray{ 42 };
        write(path + "bad-args.json", QJsonDocument(bad).toJson());
        write(path + "bad-huge.json", QByteArray(65537, 'x'));
        write(path + "bad-syntax.json", "{");
        write(path + "ignored.txt", QJsonDocument(good).toJson());
        QCOMPARE(loadExternalActions().size(), 2);
        qputenv("XDG_CONFIG_HOME", old);
    }

    void defaultsAndFileLimit()
    {
        QTemporaryDir dir;
        const auto oldHome = qgetenv("HOME");
        const auto oldConfig = qgetenv("XDG_CONFIG_HOME");
        const QString path = dir.path() + "/.config/flameshot/actions.d/";
        QVERIFY(QDir().mkpath(path));
        for (int i = 0; i < 130; ++i) {
            const QString name = QString("%1").arg(i, 3, 10, QChar('0'));
            write(path + name + ".json", QJsonDocument(QJsonObject{
                { "name", name }, { "program", "/usr/bin/python3" },
                { "arguments", QJsonArray{} }
            }).toJson());
        }
        qputenv("HOME", dir.path().toUtf8());
        qunsetenv("XDG_CONFIG_HOME");
        const auto defaults = loadExternalActions();
        qputenv("XDG_CONFIG_HOME", "relative-config");
        const auto relative = loadExternalActions();
        qputenv("HOME", oldHome);
        qputenv("XDG_CONFIG_HOME", oldConfig);
        QCOMPARE(defaults.size(), 128);
        QCOMPARE(relative.size(), 128);
        QCOMPARE(defaults.first().name, QString("000"));
        QCOMPARE(defaults.last().name, QString("127"));
    }

    void stdinAndLiteralArguments()
    {
        QTemporaryDir dir;
        const auto png = QByteArray::fromHex("89504e470d0a1a0a0000ff") + QByteArray(2 * 1024 * 1024, 'x');
        ExternalActionRunner runner;
        QSignalSpy spy(&runner, &ExternalActionRunner::finished);
        const QStringList literals{ "a b", "$(touch NEVER)", "; exit 9", "'quoted'", "*.png" };
        QVERIFY(runner.start(action(QStringList{ "receive", dir.filePath("png"), dir.filePath("args") } + literals), png));
        QVERIFY(!runner.start(action({ "fail" }), png));
        QTRY_COMPARE_WITH_TIMEOUT(spy.size(), 1, 5000);
        QVERIFY(spy[0][0].toBool());
        QCOMPARE(read(dir.filePath("png")), png);
        QCOMPARE(QJsonDocument::fromJson(read(dir.filePath("args"))).array(), QJsonArray::fromStringList(literals));
        QVERIFY(!runner.running());
    }

    void completion_data()
    {
        QTest::addColumn<QString>("mode");
        QTest::addColumn<bool>("success");
        QTest::newRow("nonzero") << "fail" << false;
        QTest::newRow("crash") << "crash" << false;
        QTest::newRow("16-MiB-output-discarded") << "flood" << true;
        QTest::newRow("missing-program") << "missing" << false;
    }

    void completion()
    {
        QFETCH(QString, mode);
        QFETCH(bool, success);
        auto a = action({ mode });
        if (mode == "missing")
            a.program = "/nonexistent/flameshot-test-program";
        ExternalActionRunner runner;
        QSignalSpy spy(&runner, &ExternalActionRunner::finished);
        QVERIFY(runner.start(a, "PNG"));
        QTRY_COMPARE_WITH_TIMEOUT(spy.size(), 1, 5000);
        QCOMPARE(spy[0][0].toBool(), success);
        QCOMPARE(spy[0][1].toString().isEmpty(), success);
        // A completed runner may be reused, including after failure to start.
        QVERIFY(runner.start(action({ "flood" }), "PNG"));
        QTRY_COMPARE_WITH_TIMEOUT(spy.size(), 2, 5000);
        QVERIFY(spy[1][0].toBool());
    }

    void cancellation_data()
    {
        QTest::addColumn<bool>("timeout");
        QTest::newRow("cancel") << false;
        QTest::newRow("timeout") << true;
    }

    void cancellation()
    {
        QFETCH(bool, timeout);
        QTemporaryDir dir;
        const auto pidFile = dir.filePath("pid");
        auto a = action({ "sleep", pidFile });
        a.timeout = timeout ? 500 : 60000;
        ExternalActionRunner runner;
        QSignalSpy spy(&runner, &ExternalActionRunner::finished);
        QVERIFY(runner.start(a, "PNG"));
        QTRY_VERIFY_WITH_TIMEOUT(!read(pidFile).isEmpty(), 2000);
        const auto pid = read(pidFile).toInt();
        if (!timeout)
            runner.cancel();
        QTRY_COMPARE_WITH_TIMEOUT(spy.size(), 1, 3000);
        QVERIFY(!spy[0][0].toBool());
        QVERIFY(spy[0][1].toString().contains(timeout ? "timed out" : "cancelled"));
        QCOMPARE(::kill(pid, 0), -1);
        QCOMPARE(errno, ESRCH);
    }

    void destruction()
    {
        QTemporaryDir dir;
        const auto pidFile = dir.filePath("pid");
        auto* runner = new ExternalActionRunner;
        QVERIFY(runner->start(action({ "sleep", pidFile }), "PNG"));
        QTRY_VERIFY_WITH_TIMEOUT(!read(pidFile).isEmpty(), 2000);
        const auto pid = read(pidFile).toInt();
        delete runner;
        QCOMPARE(::kill(pid, 0), -1);
        QCOMPARE(errno, ESRCH);
        QTest::qWait(50);
    }

    void immediateCancellation()
    {
        QTemporaryDir dir;
        ExternalActionRunner runner;
        QSignalSpy spy(&runner, &ExternalActionRunner::finished);
        QVERIFY(runner.start(action({ "sleep", dir.filePath("pid") }), "PNG"));
        runner.cancel();
        QTRY_COMPARE_WITH_TIMEOUT(spy.size(), 1, 3000);
        QVERIFY(!spy[0][0].toBool());
        QVERIFY(!runner.running());
        auto* pending = new ExternalActionRunner;
        QVERIFY(pending->start(action({ "sleep", dir.filePath("pid2") }), "PNG"));
        delete pending;
        QTest::qWait(100);
        const auto pid = read(dir.filePath("pid2")).toInt();
        if (pid > 0) {
            QCOMPARE(::kill(pid, 0), -1);
            QCOMPARE(errno, ESRCH);
        }
    }

    void bounds()
    {
        ExternalActionRunner runner;
        QVERIFY(!runner.start(action({ "fail" }), {}));
        QVERIFY(!runner.start(action({ "fail" }), QByteArray(64 * 1024 * 1024 + 1, 'x')));
        auto a = action({ "fail" });
        a.timeout = 300001;
        QVERIFY(!runner.start(a, "PNG"));
        QVERIFY(!runner.running());
    }
};

QTEST_GUILESS_MAIN(ExternalActionsTest)
#include "externalactions_test.moc"
