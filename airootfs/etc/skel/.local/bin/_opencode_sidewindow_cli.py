import argparse
import ast
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


def ancestor_pids():
    ancestors = []
    pid = os.getppid()
    while pid > 1 and pid not in ancestors:
        ancestors.append(pid)
        try:
            status = Path(f"/proc/{pid}/status").read_text()
        except OSError:
            break
        match = re.search(r"^PPid:\s+(\d+)$", status, re.MULTILINE)
        if not match:
            break
        pid = int(match.group(1))
    return ancestors


def lua_string(value):
    for level in range(16):
        equals = "=" * level
        closing = f"]{equals}]"
        if closing not in value:
            return f"[{equals}[{value}]{equals}]"
    raise ValueError("value cannot be represented as a Lua string")


def target_code(owner_only=False):
    ancestors = ", ".join(f"[{pid}] = true" for pid in ancestor_pids())
    allow_fallback = "false" if owner_only else "true"
    return f"""
local sidewindow = require"opencode_sidecar"
local ancestors = {{{ancestors}}}
local allow_fallback = {allow_fallback}
local target

for _, candidate in ipairs(client.get()) do
    if sidewindow.is_opencode(candidate)
        and ancestors[tonumber(candidate.pid)] then
        target = candidate
        break
    end
end

if allow_fallback and not target and sidewindow.is_opencode(client.focus) then
    target = client.focus
end

if allow_fallback and not target then
    for _, candidate in ipairs(client.get()) do
        local ok, visible = pcall(function()
            return candidate:isvisible() and not candidate.minimized
        end)
        if ok and visible and sidewindow.is_opencode(candidate) then
            target = candidate
            break
        end
    end
end

if not target then
    return "error: no OpenCode window found"
end
"""


def api_action_code(args):
    if args.command == "name":
        return f"return sidewindow.rename(target, {lua_string(args.name)})"
    if args.command == "list":
        return "return sidewindow.list(target)"
    if args.command == "image":
        path = Path(args.path).expanduser().resolve(strict=True)
        if not path.is_file():
            raise ValueError(f"not a file: {path}")
        return f"return sidewindow.set_image(target, {lua_string(str(path))})"
    return "return sidewindow.status(target)"


def control_action_code(args):
    if args.command == "select":
        return f"return sidewindow.select(target, {lua_string(args.selector)})"
    if args.command == "next":
        return "return sidewindow.next(target)"
    if args.command == "previous":
        return "return sidewindow.previous(target)"
    if args.command == "remove":
        selector = "nil" if args.selector is None else lua_string(args.selector)
        return f"return sidewindow.remove(target, {selector})"
    if args.command == "clear":
        return "return sidewindow.clear_image(target)"
    if args.command == "capture-firefox":
        return "return sidewindow.capture_firefox(target)"
    if args.command in {"show", "hide", "toggle"}:
        return (
            "if not sidewindow.has_sidewindows(target) then "
            'return "error: no sidewindow exists" end; '
            f"sidewindow.{args.command}(target); return sidewindow.status(target)"
        )
    if args.command == "resize":
        return (
            "if not sidewindow.has_sidewindows(target) then "
            'return "error: no sidewindow exists" end; '
            f"sidewindow.resize(target, {args.width}); "
            "return sidewindow.status(target)"
        )
    raise ValueError(f"unsupported control command: {args.command}")


def decode_output(output):
    match = re.fullmatch(r'\s*string\s+(".*")\s*', output, re.DOTALL)
    if not match:
        return output.strip()
    try:
        return ast.literal_eval(match.group(1))
    except (SyntaxError, ValueError):
        return match.group(1)[1:-1]


def api_parser():
    parser = argparse.ArgumentParser(
        prog="opencode-sidewindow-api",
        description="Agent API for the sidewindow attached to this OpenCode window.",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("status", help="print selected sidewindow details")
    commands.add_parser("list", help="list sidewindows and mark the selected one")
    name = commands.add_parser("name", help="rename the selected sidewindow")
    name.add_argument("name", help="new title name")
    image = commands.add_parser(
        "image",
        help="display an image; creates the first sidewindow when needed",
    )
    image.add_argument("path", help="path to an image supported by imv")
    return parser


def control_parser():
    parser = argparse.ArgumentParser(
        prog="opencode-sidewindow-ctl",
        description="Internal controls for AwesomeWM sidewindow integration.",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    select = commands.add_parser(
        "select",
        help="select a sidewindow by exact name or one-based index",
    )
    select.add_argument("selector", help="sidewindow name or one-based index")
    commands.add_parser("next", help="select the next sidewindow")
    commands.add_parser("previous", help="select the previous sidewindow")
    remove = commands.add_parser("remove", help="remove a sidewindow")
    remove.add_argument("selector", nargs="?", help="sidewindow name or index")
    commands.add_parser("clear", help="remove the selected image")
    commands.add_parser(
        "capture-firefox",
        help="capture the next MCP-launched Firefox window",
    )
    commands.add_parser("show", help="expand the sidewindow")
    commands.add_parser("hide", help="collapse the sidewindow")
    commands.add_parser("toggle", help="toggle the sidewindow")
    resize = commands.add_parser("resize", help="set the sidewindow width in pixels")
    resize.add_argument("width", type=int)
    return parser


def run(parser, action_builder):
    args = parser.parse_args()
    if not shutil.which("awesome-client"):
        print("error: awesome-client is not installed", file=sys.stderr)
        return 1

    try:
        lua = target_code(
            owner_only=args.command == "capture-firefox"
        ) + action_builder(args)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    env = os.environ.copy()
    env.setdefault("DISPLAY", ":0")
    completed = subprocess.run(
        ["awesome-client", lua],
        capture_output=True,
        text=True,
        env=env,
    )
    if completed.returncode != 0:
        message = completed.stderr.strip() or completed.stdout.strip()
        print(message or "error: awesome-client failed", file=sys.stderr)
        return completed.returncode

    output = decode_output(completed.stdout)
    stream = sys.stderr if output.startswith("error:") else sys.stdout
    print(output, file=stream)
    return 1 if output.startswith("error:") else 0


def main_api():
    return run(api_parser(), api_action_code)


def main_control():
    return run(control_parser(), control_action_code)
