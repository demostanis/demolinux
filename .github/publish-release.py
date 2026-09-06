#!/usr/bin/env python3
"""Stream release assets without buffering the entire disk image in RAM."""

import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import quote


class GitHub:
    def __init__(self, repository):
        self.repository = repository

    def api(self, method, path, data=None, missing_ok=False):
        command = ["gh", "api", "--method", method, f"repos/{self.repository}/{path}"]
        if data is not None:
            command += ["--input", "-"]
        result = subprocess.run(
            command,
            input=json.dumps(data) if data is not None else None,
            capture_output=True,
            text=True,
        )
        if result.returncode:
            if missing_ok and "HTTP 404" in result.stderr:
                return None
            raise RuntimeError(result.stderr.strip() or "GitHub API request failed")
        return json.loads(result.stdout) if result.stdout.strip() else None

    def upload(self, tag, files):
        subprocess.run(
            [
                "gh",
                "release",
                "upload",
                tag,
                "--repo",
                self.repository,
                *map(str, files),
            ],
            check=True,
        )


def find_release(github, tag):
    release = github.api("GET", f"releases/tags/{quote(tag, safe='')}", missing_ok=True)
    if release is not None:
        return release
    # A failed previous upload may have left a draft, which tag lookup can omit.
    page = 1
    while True:
        releases = github.api("GET", f"releases?per_page=100&page={page}")
        for release in releases:
            if release["tag_name"] == tag:
                return release
        if len(releases) < 100:
            return None
        page += 1


def publish(github, tag, sha, title, body, files):
    if not files or any(
        not Path(path).is_file() or Path(path).stat().st_size == 0 for path in files
    ):
        raise ValueError("Missing or empty release assets")
    release = find_release(github, tag)
    ref = github.api("GET", f"git/ref/tags/{quote(tag, safe='')}", missing_ok=True)
    expected_assets = {Path(path).name: Path(path).stat().st_size for path in files}
    existing_assets = (
        {asset["name"]: asset["size"] for asset in release.get("assets", [])}
        if release
        else {}
    )
    if (
        release
        and not release["draft"]
        and ref
        and ref["object"]["sha"] == sha
        and existing_assets == expected_assets
    ):
        print(f"Release {tag} already points at {sha}; publication skipped")
        return release["html_url"]

    if release is None:
        release = github.api(
            "POST",
            "releases",
            {
                "tag_name": tag,
                "target_commitish": sha,
                "name": title,
                "draft": True,
                "prerelease": True,
            },
        )
    else:
        github.api("PATCH", f"releases/{release['id']}", {"draft": True})

    for asset in release.get("assets", []):
        github.api("DELETE", f"releases/assets/{asset['id']}")
    github.upload(tag, files)

    if ref is None:
        github.api("POST", "git/refs", {"ref": f"refs/tags/{tag}", "sha": sha})
    elif ref["object"]["sha"] != sha:
        github.api("PATCH", f"git/refs/tags/{quote(tag, safe='')}", {"sha": sha})
    published = github.api(
        "PATCH",
        f"releases/{release['id']}",
        {
            "name": title,
            "body": body,
            "draft": False,
            "prerelease": True,
            "target_commitish": sha,
        },
    )
    return published["html_url"]


if __name__ == "__main__":
    branch, sha = os.environ["GITHUB_REF_NAME"], os.environ["GITHUB_SHA"]
    if branch == "trigger":
        tag, title = "nightly", "Nightly release"
        body = "Automatically built and tested from the trigger branch.\nProbably unstable.\n"
    elif branch == "master":
        tag, title = f"master-{sha}", "Release build"
        body = "Automatically built and tested from master.\n"
    else:
        sys.exit(f"Refusing to publish from unsupported branch: {branch}")
    body += "Reassemble the image with: cat demolinux-* > demolinux.img"
    files = sorted(Path(".").glob("demolinux-[a-z][a-z]"))
    if not files:
        sys.exit("No release chunks found")
    files.append(Path("sha256sums.txt"))
    try:
        print(
            publish(
                GitHub(os.environ["GITHUB_REPOSITORY"]), tag, sha, title, body, files
            )
        )
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
