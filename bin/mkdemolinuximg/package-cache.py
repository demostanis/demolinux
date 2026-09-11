#!/usr/bin/env python3
"""Plan clean package builds using pacman's resolver and fresh SRCINFO."""

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
from urllib.parse import unquote, urlsplit


REPO = "demolinux-build-inputs"


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def run(args, **kwargs):
    return subprocess.run(
        args, check=True, text=True, stdout=subprocess.PIPE, **kwargs
    ).stdout


def srcinfo(text, arch):
    base, outputs = {}, {}
    section = base
    for line in text.splitlines():
        key, sep, value = line.strip().partition("=")
        if not sep:
            continue
        key, value = key.strip(), value.strip()
        if key == "pkgname":
            if value in outputs:
                raise ValueError(f"Duplicate output: {value}")
            section = outputs.setdefault(value, {})
        else:
            section.setdefault(key, [])
            if value:
                section[key].append(value)
    if not outputs or "pkgver" not in base or "pkgrel" not in base:
        raise ValueError("Incomplete SRCINFO")

    def values(fields, key):
        return fields.get(key, []) + fields.get(f"{key}_{arch}", [])

    version = base["pkgver"][0] + "-" + base["pkgrel"][0]
    if base.get("epoch", ["0"])[0] != "0":
        version = base["epoch"][0] + ":" + version
    packages = []
    build = values(base, "makedepends") + values(base, "checkdepends")
    for name, fields in outputs.items():
        package = {"name": name, "version": version}
        for key in ("depends", "provides", "conflicts", "replaces"):
            # Split-package fields override the corresponding pkgbase field.
            package[key] = []
            for field in (key, f"{key}_{arch}"):
                package[key].extend(fields.get(field, base.get(field, [])))
        architectures = fields.get("arch", base.get("arch", [arch]))
        if arch not in architectures and "any" not in architectures:
            raise ValueError(f"{name} does not support architecture {arch}")
        package["arch"] = arch if arch in architectures else "any"
        packages.append(package)
        build.extend(package["depends"])
    return packages, sorted(set(build))


def satisfies(package, dependency):
    match = re.fullmatch(r"([^<>=]+)(>=|<=|=|>|<)?(.*)", dependency)
    if not match:
        raise ValueError(f"Invalid dependency: {dependency}")
    name, operator, version = match.groups()
    candidates = [(package["name"], package["version"])]
    candidates += [
        (p.partition("=")[0], p.partition("=")[2]) for p in package["provides"]
    ]
    for candidate, candidate_version in candidates:
        if candidate != name:
            continue
        if not operator:
            return True
        if candidate_version:
            comparison = int(run(["vercmp", candidate_version, version]).strip())
            if {
                "=": comparison == 0,
                ">": comparison > 0,
                "<": comparison < 0,
                ">=": comparison >= 0,
                "<=": comparison <= 0,
            }[operator]:
                return True
    return False


def write_repository(path, recipes, excluded):
    with tarfile.open(path, "w:gz") as archive:
        for recipe, data in sorted(recipes.items()):
            if recipe == excluded:
                continue
            for package in sorted(data["outputs"], key=lambda p: p["name"]):
                fields = {
                    "NAME": [package["name"]],
                    "VERSION": [package["version"]],
                    "BASE": [recipe],
                    "ARCH": [package["arch"]],
                    "FILENAME": [f"{package['name']}.pkg.tar.zst"],
                    "DESC": ["Build dependency metadata (not a downloadable archive)"],
                    "CSIZE": ["1"],
                    "ISIZE": ["1"],
                }
                fields.update(
                    {
                        key.upper(): package[key]
                        for key in ("depends", "provides", "conflicts", "replaces")
                    }
                )
                content = "".join(
                    f"%{key}%\n" + "\n".join(values) + "\n\n"
                    for key, values in fields.items()
                    if values
                ).encode()
                entry = tarfile.TarInfo(f"{package['name']}-{package['version']}/desc")
                entry.size = len(content)
                archive.addfile(entry, io.BytesIO(content))


def fingerprints(recipes, resolved, base):
    owners = {}
    for recipe, data in recipes.items():
        for output in data["outputs"]:
            name = output["name"]
            if name in owners:
                raise ValueError(
                    f"Duplicate package output {name}: {owners[name]}, {recipe}"
                )
            owners[name] = recipe
    result, order, visiting = {}, [], []

    def visit(recipe):
        if recipe in visiting:
            raise ValueError(
                "Build dependency cycle: " + " -> ".join(visiting + [recipe])
            )
        if recipe in result:
            return result[recipe]["key"]
        visiting.append(recipe)
        dependencies = {}
        for package in resolved[recipe]:
            if package["repo"] == REPO:
                owner = owners[package["name"]]
                dependencies[owner] = visit(owner)
        inputs = {
            "format": 1,
            "base": base,
            "recipe": recipes[recipe]["inputs"],
            "metadata": recipes[recipe]["outputs"],
            "resolved": sorted(resolved[recipe], key=lambda p: (p["repo"], p["name"])),
            "dependencies": dependencies,
        }
        result[recipe] = {
            "key": digest(inputs),
            "inputs": inputs,
            "path": recipes[recipe]["path"],
            "owners": owners,
        }
        visiting.pop()
        order.append(recipe)
        return result[recipe]["key"]

    for recipe in sorted(recipes):
        visit(recipe)
    return result, order


def pacman_args(plan, config=None):
    return [
        "pacman",
        "--config",
        str(config or plan["config"]),
        "--dbpath",
        plan["dbpath"],
        "--logfile",
        "/dev/null",
        "--noconfirm",
    ]


def plan_build(args):
    work = Path(args.work)
    resolver = work / "package-resolver"
    (resolver / "sync").mkdir(parents=True, exist_ok=True)
    (resolver / "local").mkdir(exist_ok=True)
    for database in (Path(args.chroot) / "var/lib/pacman/sync").glob("*.db*"):
        if database.is_file():
            shutil.copyfile(database, resolver / "sync" / database.name)
    config = resolver / "pacman.conf"
    original = Path(args.config).read_text()
    # Keep official repositories and signature policy, but put recipe metadata first.
    position = re.search(r"^\[(?!options\])[^\]]+\]", original, re.MULTILINE)
    if not position:
        raise ValueError("No official repositories configured")
    config.write_text(
        original[: position.start()]
        + f"[{REPO}]\nSigLevel = Never\nServer = file:///nonexistent\n"
        + original[position.start() :]
    )
    recipes = {}
    for line in Path(args.specs).read_text().splitlines():
        name, path, inputs = line.split("\t")
        if name in recipes:
            raise ValueError(f"Duplicate recipe: {name}")
        text = run(
            [
                "runuser",
                "-u",
                args.user,
                "--",
                "makepkg",
                "--config",
                str(Path(args.chroot) / "etc/makepkg.conf"),
                "--printsrcinfo",
            ],
            cwd=path,
        )
        outputs, dependencies = srcinfo(text, args.arch)
        recipes[name] = {
            "outputs": outputs,
            "requires": dependencies,
            "path": path,
            "inputs": inputs,
        }
    # Validate output ownership before asking pacman to read the synthetic database.
    fingerprints(recipes, {name: [] for name in recipes}, args.base)
    plan = {
        "config": str(config),
        "official_config": args.config,
        "dbpath": str(resolver),
        "cache": args.cache,
        "archives": args.archives,
    }
    resolved = {}
    for name, data in recipes.items():
        write_repository(resolver / "sync" / f"{REPO}.db", recipes, name)
        dependencies = [
            d
            for d in data["requires"]
            if not any(satisfies(p, d) for p in data["outputs"])
        ]
        # The base toolchain is an input too, including custom runtime providers.
        text = run(
            pacman_args(plan)
            + [
                "-Sp",
                "--print-format",
                "%r\t%n\t%v\t%l",
                "--",
                "base-devel",
                *dependencies,
            ]
        )
        resolved[name] = []
        for line in text.splitlines():
            fields = line.split("\t")
            if len(fields) != 4:
                raise ValueError(f"Unexpected pacman resolver output: {line}")
            fields[3] = unquote(urlsplit(fields[3]).path.rsplit("/", 1)[-1])
            resolved[name].append(
                dict(zip(("repo", "name", "version", "filename"), fields))
            )
    plan["packages"], order = fingerprints(recipes, resolved, args.base)
    (work / "package-plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    (work / "package-order").write_text("".join(name + "\n" for name in order))


def load_plan(args):
    plan = json.loads(Path(args.plan).read_text())
    return plan, plan["packages"][args.package]


def package_info(path):
    text = run(["bsdtar", "-xOf", str(path), ".PKGINFO"])
    return dict(line.split(" = ", 1) for line in text.splitlines() if " = " in line)


def prepare_archives(args):
    plan, package = load_plan(args)
    dependencies = package["inputs"]["resolved"]
    official = [p for p in dependencies if p["repo"] != REPO]
    cache = Path(os.environ.get("DEMOLINUX_PACMAN_CACHE") or plan["cache"])
    cache.mkdir(parents=True, exist_ok=True)
    existing_caches = (
        [os.environ["DEMOLINUX_PACMAN_CACHE"]]
        if os.environ.get("DEMOLINUX_PACMAN_CACHE")
        else run(["pacman-conf", "CacheDir"]).splitlines()
    )
    caches = [cache] + [Path(path) for path in existing_caches if Path(path).is_dir()]
    if official:
        # Resolve once, then download exactly that selection without re-resolving it
        # against a database containing the last recipe's synthetic metadata.
        subprocess.run(
            pacman_args(plan, plan["official_config"])
            + ["-Sddw"]
            + [argument for path in caches for argument in ("--cachedir", str(path))]
            + ["--"]
            + [f"{p['repo']}/{p['name']}" for p in official],
            check=True,
        )
    archives = []
    for dependency in dependencies:
        if dependency["repo"] != REPO:
            filename = dependency["filename"]
            if Path(filename).name != filename:
                raise ValueError(f"Invalid dependency filename: {filename}")
            path = next(
                (
                    directory / filename
                    for directory in caches
                    if (directory / filename).is_file()
                ),
                cache / filename,
            )
        else:
            owner = package["owners"][dependency["name"]]
            manifest = Path(plan["archives"]) / ".inputs" / owner
            lines = manifest.read_text().splitlines()
            if not lines or lines[0] != plan["packages"][owner]["key"]:
                raise ValueError(
                    f"Dependency {owner} has not been built with the planned inputs"
                )
            candidates = []
            for filename in lines[1:]:
                if Path(filename).name != filename:
                    raise ValueError(f"Invalid archive filename: {filename}")
                candidate = Path(plan["archives"]) / filename
                if package_info(candidate).get("pkgname") == dependency["name"]:
                    candidates.append(candidate)
            if len(candidates) != 1:
                raise ValueError(
                    f"Expected one archive for {dependency['name']}, got {candidates}"
                )
            path = candidates[0]
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f"Missing dependency archive: {path}")
        archives.append(str(path))
    Path(args.output).write_text("".join(path + "\n" for path in archives))


def explain(args):
    _, package = load_plan(args)
    old = Path(args.previous)
    if not old.is_file():
        print("no dependency-aware cache record")
        return
    try:
        previous = json.loads(old.read_text())
    except (ValueError, OSError):
        print("unreadable cache record")
        return
    current = package["inputs"]
    changed = [key for key in current if previous.get(key) != current[key]]
    dependencies = current["dependencies"]
    old_dependencies = previous.get("dependencies", {})
    names = sorted(
        name
        for name in dependencies.keys() | old_dependencies.keys()
        if dependencies.get(name) != old_dependencies.get(name)
    )
    print(
        ("changed " + ", ".join(changed) + (": " + ", ".join(names) if names else ""))
        if changed
        else "missing cache manifest, repository database, or package archive"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    planner = sub.add_parser("plan")
    for name in (
        "work",
        "specs",
        "config",
        "chroot",
        "arch",
        "base",
        "user",
        "cache",
        "archives",
    ):
        planner.add_argument("--" + name, required=True)
    for command in ("get", "archives", "explain", "record"):
        child = sub.add_parser(command)
        child.add_argument("plan")
        child.add_argument("package")
        if command == "get":
            child.add_argument("field", choices=("key", "path"))
        elif command in ("archives", "record"):
            child.add_argument("output")
        elif command == "explain":
            child.add_argument("previous")
    args = parser.parse_args()
    if args.command == "plan":
        plan_build(args)
    elif args.command == "archives":
        prepare_archives(args)
    elif args.command == "explain":
        explain(args)
    else:
        _, package = load_plan(args)
        if args.command == "get":
            print(package[args.field])
        else:
            Path(args.output).write_text(json.dumps(package["inputs"], indent=2) + "\n")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Package cache: {error}") from error
