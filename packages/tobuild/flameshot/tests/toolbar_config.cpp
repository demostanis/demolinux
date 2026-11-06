// SPDX-License-Identifier: GPL-3.0-or-later
#include <QDataStream>
#include <QList>
#include <QSettings>
#include <QVariant>

int main(int argc, char** argv)
{
    if (argc < 2) {
        return 1;
    }
    qRegisterMetaTypeStreamOperators<QList<int>>("QList<int>");
    QList<int> buttons;
    for (int i = 2; i < argc; ++i) {
        buttons.append(QString::fromLocal8Bit(argv[i]).toInt());
    }
    QSettings settings(QString::fromLocal8Bit(argv[1]), QSettings::IniFormat);
    settings.setValue("buttons", QVariant::fromValue(buttons));
    settings.sync();
    return settings.status() == QSettings::NoError ? 0 : 1;
}
