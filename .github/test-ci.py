#!/usr/bin/env python3
"""Host-side CI regressions; no root, network, or disk image build required."""

import hashlib
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
loader = importlib.machinery.SourceFileLoader(
    "build_inputs", str(ROOT / "bin/build-inputs")
)
spec = importlib.util.spec_from_loader(loader.name, loader)
assert spec is not None
inputs = importlib.util.module_from_spec(spec)
loader.exec_module(inputs)
protocol_spec = importlib.util.spec_from_file_location(
    "firefox_protocol", ROOT / "tests/firefox/protocol.py"
)
assert protocol_spec is not None and protocol_spec.loader is not None
protocol = importlib.util.module_from_spec(protocol_spec)
protocol_spec.loader.exec_module(protocol)
release_spec = importlib.util.spec_from_file_location(
    "prepare_release", ROOT / ".github/prepare-release.py"
)
assert release_spec is not None and release_spec.loader is not None
release = importlib.util.module_from_spec(release_spec)
release_spec.loader.exec_module(release)
publisher_spec = importlib.util.spec_from_file_location(
    "publish_release", ROOT / ".github/publish-release.py"
)
assert publisher_spec is not None and publisher_spec.loader is not None
publisher = importlib.util.module_from_spec(publisher_spec)
publisher_spec.loader.exec_module(publisher)


def function(name):
    source = (ROOT / "bin/mkarchiso").read_text()
    match = re.search(rf"^{name}\(\) \{{.*?^}}", source, re.M | re.S)
    assert match is not None, name
    return match[0]


class TemporaryTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="demolinux-ci-")
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)

    def write(self, name, text, executable=False):
        path = self.path / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)
        return path


class InputTests(TemporaryTest):
    def setUp(self):
        super().setUp()
        subprocess.run(["git", "init", "-q", str(self.path)], check=True)
        old = inputs.ROOT
        setattr(inputs, "ROOT", self.path)
        self.addCleanup(setattr, inputs, "ROOT", old)
        self.write("packages/tobuild/demo/PKGBUILD", "pkgver=1\npkgrel=1\n")
        self.patch = self.write("packages/tobuild/demo/fix.patch", "old\n")
        self.write(".gitignore", "packages/tobuild/*/src/\n")

    def key(self):
        return inputs.fingerprint(["packages/tobuild"])

    def test_patch_change_invalidates_without_version_bump(self):
        old = self.key()
        self.patch.write_text("new\n")
        self.assertNotEqual(old, self.key())

    def test_modes_and_deleted_inputs_invalidate(self):
        old = self.key()
        self.patch.chmod(0o755)
        self.assertNotEqual(old, self.key())
        old = self.key()
        self.patch.unlink()
        self.assertNotEqual(old, self.key())

    def test_ignored_build_outputs_do_not_invalidate(self):
        old = self.key()
        self.write("packages/tobuild/demo/src/output", "build noise")
        self.assertEqual(old, self.key())

    def test_symlink_target_invalidates(self):
        link = self.path / "packages/tobuild/demo/link"
        link.symlink_to("one")
        old = self.key()
        link.unlink()
        link.symlink_to("two")
        self.assertNotEqual(old, self.key())


class PackageCacheTests(TemporaryTest):
    def setUp(self):
        super().setUp()
        self.write("packages/db/packages.db.tar.gz", "database")
        self.manifest = self.write(
            "packages/db/.inputs/demo", "key\ndemo.pkg.tar.zst\n"
        )
        self.archive = self.write("packages/db/demo.pkg.tar.zst", "package")

    def cached(self, key="key"):
        command = function("_package_is_cached") + '\n_package_is_cached demo "$KEY"'
        return (
            subprocess.run(
                ["bash", "-eu", "-c", command],
                env={
                    **os.environ,
                    "profile": str(self.path),
                    "KEY": key,
                },
                check=False,
            ).returncode
            == 0
        )

    def test_exact_input_match(self):
        self.assertTrue(self.cached())
        self.assertFalse(self.cached("changed"))

    def test_missing_archive_or_database_is_a_miss(self):
        self.archive.unlink()
        self.assertFalse(self.cached())
        self.archive.write_text("package")
        (self.path / "packages/db/packages.db.tar.gz").unlink()
        self.assertFalse(self.cached())

    def test_empty_manifest_does_not_pass(self):
        self.manifest.write_text("key\n")
        self.assertFalse(self.cached())

    def test_all_split_outputs_are_required(self):
        self.manifest.write_text("key\ndemo.pkg.tar.zst\nsplit.pkg.tar.zst\n")
        self.assertFalse(self.cached())
        self.write("packages/db/split.pkg.tar.zst", "split package")
        self.assertTrue(self.cached())

    def test_warm_packages_skip_chroot_and_source_clone(self):
        key = hashlib.sha256(b"base\naur-demo\ncommit\n").hexdigest()
        self.write("packages/db/.inputs/aur-demo", f"{key}\ndemo.pkg.tar.zst\n")
        self.write("bin/build-inputs", 'print("base")\n')
        command = (
            "\n".join(
                function(name)
                for name in (
                    "_package_is_cached",
                    "_make_chroot",
                    "_wait_for_background_jobs",
                )
            )
            + r"""
        _msg_info() { :; }
        mkarchroot() { exit 99; }
        _cache_locked_commit() { exit 98; }
        aur_pkg_list=(aur-demo)
        local_pkg_list=() nvim_pkg_list=() zsh_pkg_list=() pkg_list=()
        declare -A locked_commits=([aur:aur-demo]=commit)
        _make_chroot
        [[ "${pkg_list[*]}" == aur-demo ]]
        [[ ! -d "$profile/packages/chroot" ]]
        """
        )
        subprocess.run(
            ["bash", "-eu", "-c", command],
            check=True,
            env={**os.environ, "profile": str(self.path)},
        )


@unittest.skipUnless(shutil.which("zstd"), "zstd is required for rootfs round-trip")
class RootCacheTests(TemporaryTest):
    def setUp(self):
        super().setUp()
        self.write("bin/build-inputs", 'import os\nprint(os.environ["INPUT_KEY"])\n')
        self.write("packages/db/packages.db.tar.gz", "package repository")
        self.work = self.path / "work"
        self.root = self.work / "x86_64/airootfs"

    def build(self, key):
        source = (
            function("_make_disk_root")
            + r"""
        pkg_list=(base)
        aur_pkg_list=(aur-demo)
        local_pkg_list=(local-demo)
        buildmode_pkg_list=()
        _msg_info() { :; }
        _make_custom_airootfs() {
            mkdir -p "$pacstrap_dir"
            printf '%s' "$INPUT_KEY" > "$pacstrap_dir/input"
            chmod 640 "$pacstrap_dir/input"
            ln -s input "$pacstrap_dir/link"
        }
        _make_chroot() { pkg_list+=(aur-demo local-demo); }
        _make_packages() { printf 'installed\n' >> "$profile/installations"; }
        _make_disk_root
        [[ "${buildmode_pkg_list[*]}" == 'base aur-demo local-demo' ]]
        """
        )
        subprocess.run(
            ["bash", "-eu", "-c", source],
            check=True,
            env={
                **os.environ,
                "profile": str(self.path),
                "work_dir": str(self.work),
                "pacstrap_dir": str(self.root),
                "arch": "x86_64",
                "INPUT_KEY": key,
                "DEMOLINUX_ROOTFS_CACHE": str(self.path / "cache"),
            },
        )

    def test_warm_restore_preserves_modes_and_excludes_customization(self):
        self.build("first")
        (self.root / "test-ssh-key").write_text("must not enter cache")
        shutil.rmtree(self.work)
        shutil.rmtree(self.path / "packages/db")
        self.build("first")
        self.assertEqual((self.path / "installations").read_text(), "installed\n")
        self.assertFalse((self.root / "test-ssh-key").exists())
        self.assertEqual((self.root / "input").stat().st_mode & 0o777, 0o640)
        self.assertTrue((self.root / "link").is_symlink())
        self.assertTrue((self.path / "packages/db/packages.db.tar.gz").exists())

    def test_changed_inputs_reinstall(self):
        self.build("first")
        shutil.rmtree(self.work)
        self.build("second")
        self.assertEqual(
            (self.path / "installations").read_text(), "installed\ninstalled\n"
        )
        self.assertEqual((self.root / "input").read_text(), "second")


class LauncherTests(TemporaryTest):
    def setUp(self):
        super().setUp()
        self.image = self.write("base image.img", "do not modify the release image")
        self.write(
            "qemu-img", '#!/bin/bash\nprintf "%s\\n" "$*" >> "$IMAGE_LOG"\n', True
        )
        self.write(
            "qemu-system-x86_64",
            f"""#!{sys.executable}
import json, os, sys
with open(os.environ['QEMU_LOG'], 'w') as output:
    json.dump(sys.argv[1:], output)
sys.exit(int(os.environ.get('QEMU_EXIT', '0')))
""",
            True,
        )
        self.env = {
            **os.environ,
            "PATH": f"{self.path}:{os.environ['PATH']}",
            "IMAGE_LOG": str(self.path / "image.log"),
            "QEMU_LOG": str(self.path / "qemu.json"),
            "DEMOLINUX_SSH_PORT": "60100",
            "DEMOLINUX_QMP_PORT": "4500",
        }

    def launch(self, *args, **env):
        return subprocess.run(
            ["bash", str(ROOT / "bin/run_archiso"), "-i", str(self.image), *args],
            env={**self.env, **env},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_user_network_overlay_ports_and_image_isolation(self):
        before = hashlib.sha256(self.image.read_bytes()).digest()
        result = self.launch("-N", "user", "-S", "-T", "10G", "-H")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads((self.path / "qemu.json").read_text())
        self.assertIn("user,id=net0,hostfwd=tcp:127.0.0.1:60100-:22", args)
        self.assertIn("tcp:127.0.0.1:4500,server=on,wait=off", args)
        drive = args[args.index("-drive") + 1]
        drive_options = dict(option.split("=", 1) for option in drive.split(","))
        self.assertEqual(drive_options["format"], "qcow2")
        self.assertEqual(drive_options["if"], "virtio")
        self.assertFalse(Path(drive_options["file"]).exists())
        self.assertEqual(before, hashlib.sha256(self.image.read_bytes()).digest())
        self.assertIn("resize -q", (self.path / "image.log").read_text())

    def test_qemu_failure_propagates(self):
        self.assertEqual(self.launch("-N", "user", QEMU_EXIT="7").returncode, 7)

    def test_invalid_backend_fails_before_qemu(self):
        self.assertNotEqual(self.launch("-N", "invalid").returncode, 0)
        self.assertFalse((self.path / "qemu.json").exists())

    def test_passt_failure_propagates(self):
        self.write("passt", "#!/bin/bash\nexit 9\n", True)
        result = self.launch("-N", "passt")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("passt exited", result.stdout)

    def test_passt_death_after_socket_creation_stops_qemu(self):
        self.write(
            "passt",
            f"""#!{sys.executable}
import socket, sys, time
sock = socket.socket(socket.AF_UNIX)
sock.bind(sys.argv[sys.argv.index('--socket') + 1])
time.sleep(.3)
sys.exit(9)
""",
            True,
        )
        self.write("qemu-system-x86_64", "#!/bin/bash\nexec sleep 30\n", True)
        result = self.launch("-N", "passt")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("passt exited while QEMU was running", result.stderr)


class PacmanCacheTests(TemporaryTest):
    def test_explicit_cache_overrides_profile_default(self):
        self.write("archive_date", "2026/08/01\n")
        self.write("packages/db/.placeholder", "")
        (self.path / "work").mkdir()
        command = (
            function("_make_pacman_conf")
            + r"""
        _msg_info() { :; }
        pacman-conf() {
            if [[ "${!#}" == CacheDir ]]; then
                printf '/var/cache/pacman/pkg\n'
            else
                printf '[options]\nArchitecture = auto\n[packages]\nServer = file://<packagesdb>\n'
            fi
        }
        _make_pacman_conf
        """
        )
        cache = str(self.path / "downloads")
        subprocess.run(
            ["bash", "-eu", "-c", command],
            check=True,
            cwd=self.path,
            env={
                **os.environ,
                "profile": str(self.path),
                "work_dir": str(self.path / "work"),
                "pacstrap_dir": str(self.path / "work/root"),
                "pacman_conf": "pacman.conf",
                "buildmode": "disk_image",
                "DEMOLINUX_PACMAN_CACHE": cache,
            },
        )
        config = (self.path / "work/disk_image.pacman.conf").read_text()
        self.assertIn(f"CacheDir = {cache}\n", config)
        self.assertNotIn("CacheDir = /var/cache/pacman/pkg", config)


class CoordinatorTests(TemporaryTest):
    def setUp(self):
        super().setUp()
        self.write(
            "tests/run",
            f"""#!{sys.executable}
import json, os, sys
print(json.dumps({{name: os.environ[name] for name in (
    'DEMOLINUX_SSH_PORT', 'DEMOLINUX_QMP_PORT', 'DEMOLINUX_TEST_IMAGE',
    'DEMOLINUX_VM_MEMORY', 'DEMOLINUX_VM_CPUS')}}))
sys.exit(int(sys.argv[1] == os.environ.get('FAIL_SHARD')))
""",
            True,
        )

    def run_shards(self, fail=""):
        return subprocess.run(
            ["bash", str(ROOT / ".github/run-tests.sh"), "base.img"],
            cwd=self.path,
            env={**os.environ, "FAIL_SHARD": fail},
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_shards_have_separate_ports_and_all_run(self):
        result = self.run_shards()
        self.assertEqual(result.returncode, 0, result.stderr)
        logs = list((self.path / ".ci/tests").glob("*/tests.log"))
        self.assertEqual(len(logs), 4)
        settings = [json.loads(path.read_text()) for path in logs]
        for name in ("DEMOLINUX_SSH_PORT", "DEMOLINUX_QMP_PORT"):
            self.assertEqual(len({setting[name] for setting in settings}), 4)
        self.assertTrue(
            all(setting["DEMOLINUX_TEST_IMAGE"] == "base.img" for setting in settings)
        )
        self.assertTrue(
            all(setting["DEMOLINUX_VM_MEMORY"] == "2048" for setting in settings)
        )
        self.assertTrue(
            all(setting["DEMOLINUX_VM_CPUS"] == "1" for setting in settings)
        )

    def test_one_failed_shard_fails_the_suite(self):
        result = self.run_shards("theme")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("FAIL: system", result.stdout)
        self.assertEqual(result.stdout.count("PASS:"), 3)


@unittest.skipUnless(shutil.which("zsh"), "guest harness requires Zsh")
class GuestInputTests(TemporaryTest):
    def test_activation_waits_for_a_mapped_window(self):
        command = (
            f"source {shlex.quote(str(ROOT / 'tests/utils'))}\n"
            + """
        timeout() { shift; "$@"; }
        xdotool() { printf '%s\\n' "$@" > "$ARGS_LOG"; }
        expectfocus() { [[ "$1" == 'demo title' ]]; }
        activatewin 'demo title'
        """
        )
        log = self.path / "arguments"
        subprocess.run(
            ["zsh", "-f", "-c", command],
            check=True,
            env={**os.environ, "ARGS_LOG": str(log)},
        )
        self.assertEqual(
            log.read_text().splitlines(),
            [
                "search",
                "--sync",
                "--onlyvisible",
                "--name",
                "demo title",
                "windowactivate",
                "--sync",
            ],
        )

    def test_child_cannot_consume_the_remaining_test_list(self):
        self.write("utils", (ROOT / "tests/utils").read_text())
        self.write(".config/mpv/mpv.conf", "")
        self.write("a_consumer", 'read -r stolen || :\n[[ -z "$stolen" ]]\n', True)
        self.write("z_marker", 'print "second test executed"\n', True)
        source = (ROOT / "tests/run").read_text()
        program = source.split("./dctrl shell <<'EOC' || die\n", 1)[1].split(
            "\nEOC", 1
        )[0]
        program = program.replace("cd /tmp/tests", f"cd {shlex.quote(str(self.path))}")
        program = program.replace(
            "/data/screenshot.png", str(self.path / "screenshot.png")
        )
        stubs = """
        sudo() { :; }
        xset() { :; }
        xrefresh() { :; }
        import() { :; }
        find() { print -l ./a_consumer ./z_marker; }
        """
        result = subprocess.run(
            ["zsh", "-f", "-c", stubs + program],
            env={**os.environ, "HOME": str(self.path)},
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("second test executed", result.stdout)


class ReleaseTests(TemporaryTest):
    def test_chunks_reassemble_with_matching_checksums(self):
        image = self.path / "input image.img"
        data = bytes(range(256)) * 5
        image.write_bytes(data)
        release.prepare_release(image, self.path, chunk_size=500)
        parts = sorted(self.path.glob("demolinux-*"))
        self.assertEqual([part.stat().st_size for part in parts], [500, 500, 280])
        self.assertEqual(b"".join(part.read_bytes() for part in parts), data)
        expected = [
            f"{hashlib.sha256(part.read_bytes()).hexdigest()}  {part.name}\n"
            for part in parts
        ]
        expected.append(f"{hashlib.sha256(data).hexdigest()}  {image}\n")
        self.assertEqual((self.path / "sha256sums.txt").read_text(), "".join(expected))
        self.assertEqual(image.read_bytes(), data)

    def test_exact_boundary_does_not_create_an_empty_chunk(self):
        image = self.write("image.img", "abcdef")
        release.prepare_release(image, self.path, chunk_size=3)
        self.assertEqual(len(list(self.path.glob("demolinux-*"))), 2)

    def test_empty_image_is_rejected(self):
        image = self.write("image.img", "")
        with self.assertRaises(ValueError):
            release.prepare_release(image, self.path)

    def test_existing_chunks_are_not_overwritten(self):
        image = self.write("image.img", "new")
        part = self.write("demolinux-aa", "existing")
        with self.assertRaises(FileExistsError):
            release.prepare_release(image, self.path)
        self.assertEqual(part.read_text(), "existing")


class PublisherTests(TemporaryTest):
    class GitHub:
        def __init__(
            self, existing=True, draft=False, sha="old", lookup=True, fail=False
        ):
            self.release = (
                {
                    "id": 77,
                    "tag_name": "nightly",
                    "draft": draft,
                    "html_url": "release-url",
                    "assets": [{"id": 88, "name": "old", "size": 1}],
                }
                if existing
                else None
            )
            self.sha, self.lookup, self.fail = sha, lookup, fail
            self.events = []

        def api(self, method, path, data=None, missing_ok=False):
            self.events.append((method, path, data))
            if method == "GET" and path.startswith("releases/tags/"):
                return self.release if self.lookup else None
            if method == "GET" and path.startswith("releases?"):
                return [self.release] if self.release else []
            if method == "GET" and path.startswith("git/ref/"):
                return {"object": {"sha": self.sha}} if self.sha else None
            if method == "POST" and path == "releases":
                self.release = {
                    "id": 77,
                    "assets": [],
                    "html_url": "release-url",
                    **data,
                }
                return self.release
            if method == "PATCH" and path == "releases/77":
                self.release.update(data)
                return self.release
            if method in ("POST", "PATCH") and path.startswith("git/refs"):
                self.sha = data["sha"]
                return {"object": {"sha": self.sha}}
            if method == "DELETE" and path.startswith("releases/assets/"):
                return None
            raise AssertionError((method, path, data))

        def upload(self, tag, files):
            self.events.append(("UPLOAD", tag, list(files)))
            if self.fail:
                raise RuntimeError("upload failed")
            self.release["assets"] = [
                {"id": i, "name": Path(path).name, "size": Path(path).stat().st_size}
                for i, path in enumerate(files)
            ]

    def setUp(self):
        super().setUp()
        self.files = [
            self.write("demolinux-aa", "abc"),
            self.write("sha256sums.txt", "checksums"),
        ]

    def publish(self, client, tag="nightly"):
        return publisher.publish(client, tag, "new", "Title", "Body", self.files)

    def test_upload_finishes_before_publication_and_preserves_release_id(self):
        client = self.GitHub()
        self.assertEqual(self.publish(client), "release-url")
        upload = next(
            i for i, event in enumerate(client.events) if event[0] == "UPLOAD"
        )
        published = next(
            i
            for i, event in enumerate(client.events)
            if event[0] == "PATCH" and event[2].get("draft") is False
        )
        self.assertLess(upload, published)
        self.assertEqual(client.release["id"], 77)
        self.assertEqual(client.sha, "new")
        self.assertFalse(client.release["draft"])
        self.assertFalse(
            any(
                event[2] and "force" in event[2]
                for event in client.events
                if event[0] != "UPLOAD"
            )
        )

    def test_upload_failure_never_publishes_or_moves_the_tag(self):
        client = self.GitHub(fail=True)
        with self.assertRaisesRegex(RuntimeError, "upload failed"):
            self.publish(client)
        self.assertTrue(client.release["draft"])
        self.assertEqual(client.sha, "old")
        self.assertFalse(
            any(
                event[0] == "PATCH" and event[2].get("draft") is False
                for event in client.events
            )
        )

    def test_complete_unchanged_release_skips_upload(self):
        client = self.GitHub(sha="new")
        client.release["assets"] = [
            {"id": i, "name": path.name, "size": path.stat().st_size}
            for i, path in enumerate(self.files)
        ]
        self.publish(client)
        self.assertTrue(all(event[0] == "GET" for event in client.events))

    def test_incomplete_unchanged_release_is_repaired(self):
        client = self.GitHub(sha="new")
        self.publish(client)
        self.assertTrue(any(event[0] == "UPLOAD" for event in client.events))
        self.assertFalse(client.release["draft"])

    def test_existing_draft_is_reused_after_failure(self):
        client = self.GitHub(draft=True, lookup=False)
        self.publish(client)
        self.assertFalse(
            any(event[:2] == ("POST", "releases") for event in client.events)
        )
        self.assertEqual(client.release["id"], 77)

    def test_first_release_creates_the_tag_after_upload(self):
        client = self.GitHub(existing=False, sha=None)
        self.publish(client, "master-new")
        upload = next(
            i for i, event in enumerate(client.events) if event[0] == "UPLOAD"
        )
        create = next(
            i
            for i, event in enumerate(client.events)
            if event[:2] == ("POST", "git/refs")
        )
        self.assertLess(upload, create)
        self.assertEqual(client.release["tag_name"], "master-new")

    def test_missing_assets_cannot_modify_a_release(self):
        client = self.GitHub()
        with self.assertRaises(ValueError):
            publisher.publish(client, "nightly", "new", "Title", "Body", [])
        self.assertEqual(client.events, [])

    def test_permission_errors_are_not_treated_as_missing_releases(self):
        client = publisher.GitHub("owner/repo")
        for status in (403, 404):
            result = subprocess.CompletedProcess(
                [], 1, "", f"gh: error (HTTP {status})"
            )
            with patch.object(publisher.subprocess, "run", return_value=result):
                if status == 404:
                    self.assertIsNone(
                        client.api("GET", "releases/tags/nightly", missing_ok=True)
                    )
                else:
                    with self.assertRaises(RuntimeError):
                        client.api("GET", "releases/tags/nightly", missing_ok=True)


class FirefoxProtocolTests(unittest.TestCase):
    class Socket:
        def __init__(self, data):
            self.data = io.BytesIO(data)
            self.sent = []

        def recv(self, length):
            return self.data.read(min(length, 2))

        def sendall(self, data):
            self.sent.append(data)

    def socket(self, *packets):
        return self.Socket(
            b"".join(protocol.encode_packet(packet) for packet in packets)
        )

    def result(self):
        return {
            "type": "evaluationResult",
            "resultID": "42",
            "result": {
                "preview": {"ownProperties": {"<value>": {"value": '["enabled"]'}}}
            },
        }

    def test_fragmented_utf8_packet(self):
        packet = {"message": "caf\u00e9"}
        self.assertEqual(protocol.receive_packet(self.socket(packet)), packet)

    def test_truncated_packet_fails_instead_of_hanging(self):
        for data in (b"", b"2", b"4:{}"):
            with self.assertRaises(EOFError):
                protocol.receive_packet(self.Socket(data))

    def test_unrelated_events_are_not_evaluation_results(self):
        sock = self.socket(
            {"resultID": "42"},
            {"type": "frameUpdate"},
            {"type": "consoleAPICall"},
            self.result(),
        )
        self.assertEqual(protocol.evaluate(sock, "console", "[]"), ["enabled"])

    def test_result_before_acknowledgement_is_consumed(self):
        sock = self.socket(self.result(), {"resultID": "42"})
        self.assertEqual(protocol.evaluate(sock, "console", "[]"), ["enabled"])
        self.assertEqual(sock.recv(1), b"")

    def test_mismatched_result_id_is_ignored(self):
        other = {**self.result(), "resultID": "previous"}
        sock = self.socket({"resultID": "42"}, other, self.result())
        self.assertEqual(protocol.evaluate(sock, "console", "[]"), ["enabled"])

    def test_browser_exception_is_not_swallowed(self):
        failure = {**self.result(), "exceptionMessage": "evaluation failed"}
        with self.assertRaisesRegex(RuntimeError, "evaluation failed"):
            protocol.evaluate(self.socket({"resultID": "42"}, failure), "console", "[]")


class ShardTests(unittest.TestCase):
    def test_only_bridge_requests_a_dhcp_lease(self):
        network = ROOT / "airootfs/etc/systemd/network"
        self.assertIn("DHCP=no", (network / "20-ethernet.network").read_text())
        self.assertIn("DHCP=yes", (network / "25-virbr0.network").read_text())

    def test_every_test_is_assigned_exactly_once(self):
        script = (ROOT / ".github/run-tests.sh").read_text()
        assigned = []
        for line in script.splitlines():
            if line.startswith("shard "):
                for name in shlex.split(line)[2:]:
                    path = ROOT / "tests" / name
                    self.assertTrue(path.exists(), name)
                    paths = path.rglob("*") if path.is_dir() else [path]
                    assigned.extend(
                        p.relative_to(ROOT / "tests")
                        for p in paths
                        if p.is_file() and os.access(p, os.X_OK)
                    )
        expected = {
            p.relative_to(ROOT / "tests")
            for p in (ROOT / "tests").rglob("*")
            if p.is_file() and os.access(p, os.X_OK) and p.name not in ("run", "utils")
        }
        self.assertEqual(set(assigned), expected)
        self.assertEqual(
            len(assigned), len(set(assigned)), "test assigned to multiple VMs"
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
