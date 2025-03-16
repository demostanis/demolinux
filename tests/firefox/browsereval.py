import socket
from json import dumps, loads

fhost = "localhost"
fport = 6000

def fpacket(data):
    stringified = dumps(data)
    return bytes(f"{len(stringified)}:{stringified}", "utf-8")

def rfpacket(s):
    plen = 0
    while True:
        n = s.recv(1)
        if n == b':':
            break
        plen *= 10
        plen += int(n)

    data = s.recv(plen)
    if b"frameUpdate" in data:
        return rfpacket(s)
    return loads(data)

def process_packet():
    return fpacket(
        {"type":"getProcess","id":0,"to":"root"}
    )

def target_packet(desc):
    return fpacket(
        {"type":"getTarget","to":desc}
    )

def eval_packet(code,console):
    code = "(async()=>{return JSON.stringify("+code+")})();"
    return fpacket(
        {"type":"evaluateJSAsync","text":code,"to":console}
    )

def recv_process(s):
    res = rfpacket(s)
    if not "processDescriptor" in res:
        raise Exception("bad json data: no processDescriptor")
    return res["processDescriptor"]["actor"]

def recv_target(s):
    res = rfpacket(s)
    if not "process" in res or not "consoleActor" in res["process"]:
        raise Exception("bad json data: no consoleActor")
    return res["process"]["consoleActor"]

def recv_eval(s):
    res = rfpacket(s)
    if "exceptionMessage" in res:
        raise Exception(res["exceptionMessage"])
    if not "result" in res:
        raise Exception("bad json data: no result")
    try:
        # what the fuck
        return loads(res["result"]["preview"]["ownProperties"]["<value>"]["value"])
    except:
        return res["result"]

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
    s.connect((fhost, fport))

    # ignore first packet
    rfpacket(s)

    s.sendall(process_packet())
    desc = recv_process(s)
    s.sendall(target_packet(desc))
    console = recv_target(s)

    def eval(code):
        s.sendall(eval_packet(code, console))
        # wait for resultID
        while True:
            res = rfpacket(s)
            if "resultID" in res:
                break

        return recv_eval(s)

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
