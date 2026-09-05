import socket
import sys
import time
from subprocess import check_output
from protocol import encode_packet, evaluate, receive_packet, receive_reply

fhost = "localhost"
fport = 6000

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.settimeout(15)
    s.connect((fhost, fport))

    # ignore first packet
    receive_packet(s)

    s.sendall(encode_packet({"type": "getProcess", "id": 0, "to": "root"}))
    desc = receive_reply(s, "processDescriptor")["processDescriptor"]["actor"]
    s.sendall(encode_packet({"type": "getTarget", "to": desc}))
    console = receive_reply(s, "process")["process"]["consoleActor"]

    def eval(code):
        return evaluate(s, console, code)

    if len(sys.argv) > 1:
        if len(sys.argv) != 3 or sys.argv[1] != "--wait":
            sys.exit("usage: browsereval.py [--wait JAVASCRIPT_CONDITION]")
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if eval(sys.argv[2]) is True:
                sys.exit(0)
            time.sleep(0.1)
        value = eval(
            'Services.wm.getMostRecentWindow("navigator:browser").gURLBar.value'
        )
        raise RuntimeError(
            f"Browser condition did not become true: {sys.argv[2]} (URL bar: {value!r})"
        )

    enabled_addons = eval("""
            await (async () => {
                const addons = await AddonManager.getAllAddons()

                const enabledAddons = addons
                    .filter(addon => addon.isActive)
                    .map(addon => addon.id)

                return enabledAddons
            })()
         """)

    print("checking if firefox addons are enabled...")
    assert "uBlock0@raymondhill.net" in enabled_addons
    assert "mellow-purple@demostanis" in enabled_addons
    assert "VimFx-unlisted@akhodakivskiy.github.com" in enabled_addons
    assert "CanvasBlocker@kkapsner.de" in enabled_addons
    assert "mellow-purple@demostanis" in enabled_addons
    assert "{446900e4-71c2-419f-a6a7-df9c091e268b}" in enabled_addons  # Bitwarden

    # taken from https://searchfox.org/mozilla-central/source/toolkit/content/aboutSupport.js#1670
    eval("""
        await (async () => {
          function getLoadContext() {
            return window.docShell.QueryInterface(Ci.nsILoadContext);
          }

          let supportsStringClass = Cc["@mozilla.org/supports-string;1"];
          let ssText = supportsStringClass.createInstance(Ci.nsISupportsString);

          let transferable = Cc["@mozilla.org/widget/transferable;1"].createInstance(
            Ci.nsITransferable
          );
          transferable.init(getLoadContext());

          transferable.addDataFlavor("text/plain");
          ssText.data = "copied from firefox";
          transferable.setTransferData("text/plain", ssText);

          Services.clipboard.setData(
            transferable,
            null,
            Services.clipboard.kGlobalClipboard
          );
        })()
    """)
    time.sleep(1)
    clipboard = check_output(["xsel", "-ob"])
    assert clipboard == b"copied from firefox"
