#!/usr/bin/env python3
import json
import socket
import sys
import time


def packet(data):
    stringified = json.dumps(data)
    return f"{len(stringified)}:{stringified}".encode()


def read_packet(sock):
    packet_len = 0
    while True:
        byte = sock.recv(1)
        if byte == b":":
            break
        packet_len = packet_len * 10 + int(byte)
    data = sock.recv(packet_len)
    if b"frameUpdate" in data:
        return read_packet(sock)
    return json.loads(data)


def eval_console(sock, console, code):
    sock.sendall(packet({"type": "evaluateJSAsync", "text": code, "to": console}))
    while True:
        response = read_packet(sock)
        if "resultID" in response:
            break
    response = read_packet(sock)
    if response.get("hasException"):
        return {
            "exception": response.get("exceptionMessage"),
            "input": response.get("input"),
        }
    result = response.get("result")
    if isinstance(result, str):
        try:
            return json.loads(result)
        except json.JSONDecodeError:
            return result
    if isinstance(result, dict) and result.get("type") == "longString":
        initial = result.get("initial", "")
        try:
            return json.loads(initial)
        except json.JSONDecodeError:
            return initial
    try:
        return json.loads(result["preview"]["ownProperties"]["<value>"]["value"])
    except Exception:
        return result


def request_until(sock, request, key):
    sock.sendall(packet(request))
    while True:
        response = read_packet(sock)
        if key in response:
            return response


def main():
    with socket.create_connection(("localhost", 6000), timeout=10) as sock:
        sock.settimeout(40)
        read_packet(sock)
        tab = request_until(sock, {"type": "listTabs", "to": "root"}, "tabs")["tabs"][0]
        target = request_until(
            sock, {"type": "getTarget", "to": tab["actor"]}, "frame"
        )["frame"]
        target_actor = target["actor"]
        console = target["consoleActor"]

        if "--no-reload" not in sys.argv:
            print(
                "load",
                eval_console(
                    sock,
                    console,
                    "location.href = 'https://passkeys.eu/'; JSON.stringify({ ok: true })",
                ),
            )
            time.sleep(6)
        if "--login-form" in sys.argv:
            print(
                "login-form",
                eval_console(
                    sock,
                    console,
                    "JSON.stringify((() => { const el = [...document.querySelectorAll('a, button')].find((e) => /log in/i.test(e.innerText)); el?.click(); return { clicked: !!el, text: el?.innerText, tag: el?.tagName }; })())",
                ),
            )
            time.sleep(2)
        print(
            "focus",
            eval_console(
                sock,
                console,
                "JSON.stringify((() => { const e = document.querySelector('input[type=email], #email, input'); e?.focus(); e?.click(); return { url: location.href, ready: document.readyState, autocomplete: e?.getAttribute('autocomplete'), patched: String(navigator.credentials.get).includes('CredentialGetRequest') }; })())",
            ),
        )
        time.sleep(2)

        tab = request_until(sock, {"type": "listTabs", "to": "root"}, "tabs")["tabs"][0]
        target = request_until(
            sock, {"type": "getTarget", "to": tab["actor"]}, "frame"
        )["frame"]
        target_actor = target["actor"]
        console = target["consoleActor"]

        frames = request_until(
            sock, {"type": "listFrames", "to": target_actor}, "frames"
        )["frames"]
        frame_ids = [
            frame["id"] for frame in frames if frame["url"].endswith("menu-list.html")
        ]
        print("frames", frame_ids)

        results = []
        for frame_id in frame_ids:
            sock.sendall(
                packet(
                    {"type": "switchToFrame", "windowId": frame_id, "to": target_actor}
                )
            )
            read_packet(sock)
            if "--click" in sys.argv:
                print(
                    "click",
                    eval_console(
                        sock,
                        console,
                        "JSON.stringify((() => { const host = document.querySelector('autofill-inline-menu-list'); const button = host?.shadowDom?.querySelector('.fill-cipher-button'); button?.click(); return { clicked: !!button, aria: button?.getAttribute('aria-label') }; })())",
                    ),
                )
                time.sleep(5)
            result = eval_console(
                sock,
                console,
                "JSON.stringify((() => { const host = document.querySelector('autofill-inline-menu-list'); const root = host?.shadowDom; return { href: location.href, body: document.body.innerHTML.slice(0, 1000), frameId: "
                + str(frame_id)
                + ", authStatus: host?.authStatus, fillType: host?.inlineMenuFillType, showPasskeysLabels: host?.showPasskeysLabels, ciphers: host?.ciphers?.map((c) => ({ name: c.name, login: c.login })), text: root?.innerText, entries: [...(root?.querySelectorAll('button, li, span, div') || [])].map((e, i) => ({ i, tag: e.tagName, cls: e.className?.toString(), text: (e.innerText || e.textContent || '').trim(), aria: e.getAttribute('aria-label') })).filter((e) => e.text || e.aria).slice(0, 80) }; })())",
            )
            results.append(result)

        print(json.dumps(results, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
