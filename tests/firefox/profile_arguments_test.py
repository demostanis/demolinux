from pathlib import Path
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = (ROOT / "airootfs/usr/local/bin/firefox-hardened").read_text()
PARSER = LAUNCHER.split("bind_marionette_profile=()", 1)[1].split("# selenium runs", 1)[
    0
]


class ProfileArgumentsTest(unittest.TestCase):
    def parse(self, *args):
        result = subprocess.run(
            [
                "bash",
                "-c",
                "bind_marionette_profile=()\n"
                + PARSER
                + '\nprintf "%s\\0" "$profile" "${bind_marionette_profile[@]}"',
                "firefox-hardened",
                *args,
            ],
            check=True,
            capture_output=True,
        )
        return result.stdout.decode().split("\0")[:-1]

    def test_profile_followed_by_geckodriver_arguments(self):
        self.assertEqual(
            self.parse(
                "-profile", "/tmp/rust_mcp-abc", "--remote-debugging-port", "1234"
            ),
            ["/tmp/rust_mcp-abc", "--bind", "/tmp/rust_mcp-abc", "/tmp/rust_mcp-abc"],
        )

    def test_profile_path_with_spaces(self):
        path = "/tmp/rust_mcp-with spaces"
        self.assertEqual(
            self.parse("--profile", path, "--headless"), [path, "--bind", path, path]
        )

    def test_equals_syntax(self):
        path = "/tmp/rust_mcp-abc"
        self.assertEqual(self.parse("--profile=" + path), [path, "--bind", path, path])

    def test_non_profile_arguments_are_not_bound(self):
        for args in [
            (),
            ("https://example.test/tmp/rust_abc",),
            ("--profile", "/home/user/profile"),
            ("--profile",),
        ]:
            with self.subTest(args=args):
                self.assertEqual(self.parse(*args), [""])

    def test_argument_arrays_remain_quoted(self):
        self.assertIn('"${bind_marionette_profile[@]}"', LAUNCHER)
        self.assertIn('--new-session /usr/bin/firefox "$@"', LAUNCHER)


if __name__ == "__main__":
    unittest.main()
