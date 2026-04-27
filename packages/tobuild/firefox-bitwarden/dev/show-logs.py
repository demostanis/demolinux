#!/usr/bin/env python3
import argparse
import json
import time

from firefox_eval import eval_firefox


ADDON_ID = "{446900e4-71c2-419f-a6a7-df9c091e268b}"


def fetch_logs(limit):
    code = f"""
      await (async () => {{
        const addonId = {json.dumps(ADDON_ID)};
        const matches = Services.console.getMessageArray()
          .map((message, index) => ({{
            index,
            timeStamp: message.timeStamp ?? null,
            logLevel: message.logLevel ?? null,
            sourceName: message.sourceName ?? null,
            text: (message.message || String(message)).replace(/\\s+/g, " "),
          }}))
          .filter((entry) =>
            entry.text.includes(addonId) || entry.text.toLowerCase().includes("bitwarden")
          );

        return matches.slice(-{limit});
      }})()
    """
    return eval_firefox(code)


def print_logs(logs, seen):
    for log in logs:
        key = (log.get("index"), log.get("timeStamp"), log.get("text"))
        if key in seen:
            continue
        seen.add(key)

        level = log.get("logLevel")
        level_name = {0: "debug", 1: "info", 2: "warn", 3: "error"}.get(
            level, str(level)
        )
        text = log.get("text", "")
        source = log.get("sourceName") or "browser-console"
        print(f"[{log.get('index')}] {level_name} {source}: {text}", flush=True)


def main():
    parser = argparse.ArgumentParser(
        description="Show Bitwarden-related Firefox browser logs."
    )
    parser.add_argument(
        "-n", "--limit", type=int, default=25, help="number of recent logs to show"
    )
    parser.add_argument("-f", "--follow", action="store_true", help="poll for new logs")
    parser.add_argument(
        "-i", "--interval", type=float, default=1.0, help="follow poll interval"
    )
    args = parser.parse_args()

    seen = set()
    while True:
        print_logs(fetch_logs(args.limit), seen)
        if not args.follow:
            break
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
