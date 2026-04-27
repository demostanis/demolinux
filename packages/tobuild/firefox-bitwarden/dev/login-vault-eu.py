#!/usr/bin/env python3
import json
import socket
import time


EMAIL = "delepo6704@4heats.com"
PASSWORD = "delepo6704@4heats.com"
ADDON_ID = "{446900e4-71c2-419f-a6a7-df9c091e268b}"


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
        raise RuntimeError(response.get("exceptionMessage"))
    result = response.get("result")
    if isinstance(result, str):
        return json.loads(result)
    if isinstance(result, dict) and result.get("type") == "longString":
        return json.loads(result.get("initial", "null"))
    return result


def wait_for_selector(sock, console, selector, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        exists = eval_console(
            sock,
            console,
            f"JSON.stringify(!!document.querySelector({json.dumps(selector)}))",
        )
        if exists:
            return True
        time.sleep(0.25)
    return False


def wait_for_text(sock, console, text, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        found = eval_console(
            sock,
            console,
            f"JSON.stringify(document.body.innerText.includes({json.dumps(text)}))",
        )
        if found:
            return True
        time.sleep(0.25)
    return False


def get_tab_console(sock):
    sock.sendall(packet({"type": "listTabs", "to": "root"}))
    tab = read_packet(sock)["tabs"][0]
    sock.sendall(packet({"type": "getTarget", "to": tab["actor"]}))
    return read_packet(sock)["frame"]["consoleActor"]


def main():
    with socket.create_connection(("localhost", 6000), timeout=10) as sock:
        sock.settimeout(60)
        read_packet(sock)

        popup_url = eval_console(
            sock,
            get_tab_console(sock),
            f"""
            (async () => {{
              const host = WebExtensionPolicy.getByID({json.dumps(ADDON_ID)}).mozExtensionHostname;
              const url = "moz-extension://" + host + "/popup/index.html";
              const win = Services.wm.getMostRecentWindow("navigator:browser");
              win.gBrowser.selectedBrowser.loadURI(Services.io.newURI(url), {{
                triggeringPrincipal: Services.scriptSecurityManager.getSystemPrincipal(),
              }});
              return JSON.stringify({{ url }});
            }})()
            """,
        )
        time.sleep(4)
        console = get_tab_console(sock)
        wait_for_selector(sock, console, "input[type=email]", timeout=20)

        eval_console(
            sock,
            console,
            """
            (() => {{
              const clickText = (text) => {
                const element = [...document.querySelectorAll("button, a")]
                  .find((button) => button.innerText.trim() === text || button.innerText.includes(text));
                element?.click();
                return !!element;
              };
              return JSON.stringify({ clicked: clickText("self-hosted") || clickText("bitwarden.com") });
            })()
            """.replace("{{", "{").replace("}}", "}"),
        )
        time.sleep(0.5)
        eval_console(
            sock,
            console,
            """
            (() => {
              const button = [...document.querySelectorAll("button, a")]
                .filter((element) => element.innerText.trim() === "bitwarden.eu")
                .at(-1);
              button?.click();
              return JSON.stringify({ clicked: !!button });
            })()
            """,
        )
        wait_for_text(sock, console, "Accessing: bitwarden.eu", timeout=10)

        eval_console(
            sock,
            console,
            f"""
            (() => {{
              const setValue = (element, value) => {{
                Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), "value").set.call(
                  element,
                  value,
                );
                element.dispatchEvent(new InputEvent("input", {{ bubbles: true, inputType: "insertText", data: value }}));
                element.dispatchEvent(new Event("change", {{ bubbles: true }}));
              }};
              const emailInput = document.querySelector("input[type=email]");
              setValue(emailInput, {json.dumps(EMAIL)});

              const button = [...document.querySelectorAll("button")]
                .find((button) => button.innerText.trim() === "Continue");
              button?.click();
              return JSON.stringify({{ popupUrl: {json.dumps(popup_url.get("url"))}, clicked: !!button }});
            }})()
            """,
        )
        wait_for_text(sock, console, "Welcome back", timeout=20)

        console = get_tab_console(sock)
        if not wait_for_selector(sock, console, "input[type=password]", timeout=20):
            raise RuntimeError("timed out waiting for Bitwarden password input")
        result = eval_console(
            sock,
            console,
            f"""
            (() => {{
              const setValue = (element, value) => {{
                Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), "value").set.call(
                  element,
                  value,
                );
                element.dispatchEvent(new InputEvent("input", {{ bubbles: true, inputType: "insertText", data: value }}));
                element.dispatchEvent(new Event("change", {{ bubbles: true }}));
              }};
              const passwordInput = document.querySelector("input[type=password]");
              setValue(passwordInput, {json.dumps(PASSWORD)});
              const button = [...document.querySelectorAll("button")]
                .find((button) => button.innerText.includes("Log in with master password"));
              button?.click();
              return JSON.stringify({{ clicked: !!button }});
            }})()
            """,
        )

        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            time.sleep(1)
            console = get_tab_console(sock)
            state = eval_console(
                sock,
                console,
                "JSON.stringify({ url: location.href, text: document.body.innerText.slice(0, 800) })",
            )
            if "Vault loaded" in state.get("text", "") or "#/tabs/vault" in state.get(
                "url", ""
            ):
                print(
                    json.dumps(
                        {"status": "logged-in", **state}, indent=2, sort_keys=True
                    )
                )
                return

        raise RuntimeError("timed out waiting for Bitwarden vault to load")


if __name__ == "__main__":
    main()
