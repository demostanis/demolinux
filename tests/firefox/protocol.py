"""Framing and asynchronous replies for Firefox's remote debugging protocol."""

import json
import time


def encode_packet(packet):
    payload = json.dumps(packet, ensure_ascii=False).encode("utf-8")
    return str(len(payload)).encode("ascii") + b":" + payload


def receive_packet(sock):
    length = bytearray()
    while True:
        byte = sock.recv(1)
        if not byte:
            raise EOFError("Firefox debugger closed the connection")
        if byte == b":":
            break
        if not byte.isdigit() or len(length) >= 8:
            raise ValueError("Invalid Firefox debugger packet length")
        length.extend(byte)
    size = int(length)
    if size > 16 * 1024 * 1024:
        raise ValueError("Firefox debugger packet exceeds 16 MiB")
    payload = bytearray()
    while len(payload) < size:
        chunk = sock.recv(size - len(payload))
        if not chunk:
            raise EOFError("Firefox debugger closed mid-packet")
        payload.extend(chunk)
    return json.loads(payload)


def receive_reply(sock, key):
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        packet = receive_packet(sock)
        if "error" in packet:
            raise RuntimeError(packet)
        if key in packet:
            return packet
    raise TimeoutError(f"Firefox debugger did not return {key}")


def decode_result(packet):
    if packet.get("exceptionMessage"):
        raise RuntimeError(packet["exceptionMessage"])
    result = packet["result"]
    try:
        return json.loads(result["preview"]["ownProperties"]["<value>"]["value"])
    except (KeyError, TypeError, ValueError):
        return result


def evaluate(sock, console, code):
    sock.sendall(
        encode_packet(
            {
                "type": "evaluateJSAsync",
                "to": console,
                "text": "(async()=>{return JSON.stringify(" + code + ")})();",
            }
        )
    )
    result_id = None
    completed = {}
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        packet = receive_packet(sock)
        if "error" in packet:
            raise RuntimeError(packet)
        if "resultID" not in packet:
            continue
        if packet.get("type") == "evaluationResult" or "result" in packet:
            completed[packet["resultID"]] = packet
        else:
            result_id = packet["resultID"]
        # The acknowledgement and completion can be interleaved with events,
        # and must both be consumed before starting another evaluation.
        if result_id in completed:
            return decode_result(completed[result_id])
    raise TimeoutError("Firefox debugger did not finish evaluation")
