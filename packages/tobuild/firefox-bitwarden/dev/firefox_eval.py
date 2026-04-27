#!/usr/bin/env python3
import json
import shutil
import socket
import subprocess
import sys
import time
from pathlib import Path


FHOST = "localhost"
FPORT = 6000


def _packet(data):
    stringified = json.dumps(data)
    return bytes(f"{len(stringified)}:{stringified}", "utf-8")


def _read_packet(sock):
    packet_len = 0
    while True:
        byte = sock.recv(1)
        if not byte:
            raise RuntimeError("Firefox debugger connection closed")
        if byte == b":":
            break
        packet_len *= 10
        packet_len += int(byte)

    data = sock.recv(packet_len)
    if b"frameUpdate" in data:
        return _read_packet(sock)
    return json.loads(data)


def _process_packet():
    return _packet({"type": "getProcess", "id": 0, "to": "root"})


def _target_packet(desc):
    return _packet({"type": "getTarget", "to": desc})


def _eval_packet(code, console):
    wrapped = "(async()=>{return JSON.stringify(" + code + ")})();"
    return _packet({"type": "evaluateJSAsync", "text": wrapped, "to": console})


def _recv_process(sock):
    res = _read_packet(sock)
    if "processDescriptor" not in res:
        raise RuntimeError("bad json data: no processDescriptor")
    return res["processDescriptor"]["actor"]


def _recv_target(sock):
    res = _read_packet(sock)
    if "process" not in res or "consoleActor" not in res["process"]:
        raise RuntimeError("bad json data: no consoleActor")
    return res["process"]["consoleActor"]


_PENDING = object()


def _parse_eval_result(res):
    if "exceptionMessage" in res:
        raise RuntimeError(res["exceptionMessage"])
    if "result" not in res:
        raise RuntimeError("bad json data: no result")
    try:
        props = res["result"]["preview"]["ownProperties"]
        if props.get("<state>", {}).get("value") == "pending":
            return _PENDING
        if props.get("<state>", {}).get("value") == "rejected":
            reason = props.get("<reason>", {}).get("value", {})
            preview = reason.get("preview", {}) if isinstance(reason, dict) else {}
            message = preview.get("message") or json.dumps(reason)
            raise RuntimeError(message)
        value = props["<value>"]["value"]
        return json.loads(value)
    except Exception:
        if isinstance(sys.exc_info()[1], RuntimeError):
            raise
        return res["result"]


def _recv_eval(sock, timeout=30):
    deadline = time.monotonic() + timeout
    while True:
        result = _parse_eval_result(_read_packet(sock))
        if result is not _PENDING:
            return result
        if time.monotonic() > deadline:
            raise RuntimeError("timed out waiting for Firefox evaluation result")
        time.sleep(0.1)


def eval_firefox(code):
    try:
        sock = socket.create_connection((FHOST, FPORT), timeout=5)
    except OSError as exc:
        raise RuntimeError(
            "could not connect to Firefox debugger on localhost:6000; "
            "start Firefox with `firefox-hardened --start-debugger-server`"
        ) from exc
    sock.settimeout(None)

    with sock:
        _read_packet(sock)
        sock.sendall(_process_packet())
        desc = _recv_process(sock)
        sock.sendall(_target_packet(desc))
        console = _recv_target(sock)

        sock.sendall(_eval_packet(code, console))
        while True:
            res = _read_packet(sock)
            if "resultID" in res:
                break

        return _recv_eval(sock)


def _list_addons_packet():
    return _packet({"type": "listAddons", "to": "root"})


def _watcher_packet(addon_actor):
    return _packet({"type": "getWatcher", "to": addon_actor})


def _watch_frame_targets_packet(watcher):
    return _packet({"type": "watchTargets", "targetType": "frame", "to": watcher})


def _eval_console_packet(code, console):
    wrapped = "(async()=>JSON.stringify(await (" + code + ")))()"
    return _packet({"type": "evaluateJSAsync", "text": wrapped, "to": console})


def _recv_console_eval(sock, timeout=30):
    deadline = time.monotonic() + timeout
    while True:
        res = _read_packet(sock)
        if res.get("type") != "evaluationResult":
            continue
        if res.get("hasException"):
            raise RuntimeError(res.get("exceptionMessage", "Firefox evaluation failed"))

        result = res.get("result")
        try:
            props = result["preview"]["ownProperties"]
            state = props.get("<state>", {}).get("value")
            if state == "pending":
                if time.monotonic() > deadline:
                    raise RuntimeError(
                        "timed out waiting for Firefox evaluation result"
                    )
                time.sleep(0.1)
                continue
            if state == "rejected":
                reason = props.get("<reason>", {}).get("value", {})
                preview = reason.get("preview", {}) if isinstance(reason, dict) else {}
                raise RuntimeError(preview.get("message") or json.dumps(reason))
            return json.loads(props["<value>"]["value"])
        except KeyError:
            pass

        if isinstance(result, str):
            return json.loads(result)
        if isinstance(result, dict) and result.get("type") == "longString":
            return json.loads(result.get("initial", "null"))
        return result


def eval_bitwarden_background(code, addon_id="{446900e4-71c2-419f-a6a7-df9c091e268b}"):
    try:
        sock = socket.create_connection((FHOST, FPORT), timeout=5)
    except OSError as exc:
        raise RuntimeError(
            "could not connect to Firefox debugger on localhost:6000; "
            "start Firefox with `firefox-hardened --start-debugger-server`"
        ) from exc
    sock.settimeout(None)

    with sock:
        _read_packet(sock)
        sock.sendall(_list_addons_packet())
        addons = _read_packet(sock).get("addons", [])
        addon = next((addon for addon in addons if addon.get("id") == addon_id), None)
        if not addon:
            raise RuntimeError(f"Bitwarden addon not found: {addon_id}")

        sock.sendall(_watcher_packet(addon["actor"]))
        watcher = _read_packet(sock)["actor"]
        sock.sendall(_watch_frame_targets_packet(watcher))

        background_console = None
        while background_console is None:
            res = _read_packet(sock)
            target = res.get("target", {})
            if res.get("type") == "target-available-form" and target.get(
                "url", ""
            ).endswith("/background.html"):
                background_console = target["consoleActor"]

        sock.sendall(_eval_console_packet(code, background_console))
        while True:
            res = _read_packet(sock)
            if "resultID" in res:
                break

        return _recv_console_eval(sock)


def sync_to_firefox_tmp(source, name):
    source = Path(source)
    if not source.exists():
        raise RuntimeError(f"source path does not exist: {source}")

    pid = subprocess.check_output(["pgrep", "-n", "firefox"], text=True).strip()
    dest = Path(f"/proc/{pid}/root/tmp/{name}")
    if dest.resolve() == source.resolve():
        return dest

    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(source, dest, symlinks=True)
    return dest


def main():
    if len(sys.argv) > 1:
        code = " ".join(sys.argv[1:])
    else:
        code = sys.stdin.read()

    result = eval_firefox(code)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
