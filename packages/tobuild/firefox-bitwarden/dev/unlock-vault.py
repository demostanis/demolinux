#!/usr/bin/env python3
import json
import time

from firefox_eval import eval_bitwarden_background


EMAIL = "delepo6704@4heats.com"
PASSWORD = "delepo6704@4heats.com"


def main():
    start_code = f"""
      (() => {{
        const email = {json.dumps(EMAIL)};
        const password = {json.dumps(PASSWORD)};
        const main = globalThis.bitwardenMain;
        globalThis.__opencodeUnlockResult = {{ status: "pending" }};

        const first = (observable) => new Promise((resolve, reject) => {{
          const subscription = observable.subscribe({{
            next: (value) => {{
              resolve(value);
              setTimeout(() => subscription.unsubscribe(), 0);
            }},
            error: reject,
          }});
        }});

        (async () => {{
          try {{
            const activeAccount = await first(main.accountService.activeAccount$);
            if (!activeAccount) {{
              throw new Error("No active Bitwarden account. Log in once before using this helper.");
            }}
            if (activeAccount.email !== email) {{
              throw new Error(`Unexpected active Bitwarden account: ${{activeAccount.email}}`);
            }}

            const beforeStatus = await first(main.authService.activeAccountStatus$);
            if (beforeStatus === 2) {{
              globalThis.__opencodeUnlockResult = {{
                email,
                status: "already-unlocked",
                beforeStatus,
                afterStatus: beforeStatus,
              }};
              return;
            }}

            const unlockData = await first(
              main.masterPasswordService.masterPasswordUnlockData$(activeAccount.id),
            );
            if (!unlockData) {{
              throw new Error("No master password unlock data found for active Bitwarden account.");
            }}

            const userKey = await main.masterPasswordService.unwrapUserKeyFromMasterPasswordUnlockData(
              password,
              unlockData,
            );
            const masterKey = await main.keyService.makeMasterKey(
              password,
              unlockData.salt,
              unlockData.kdf,
            );
            const localKeyHash = await main.keyService.hashMasterKey(password, masterKey, 2);

            await main.masterPasswordService.setMasterKeyHash(localKeyHash, activeAccount.id);
            await main.masterPasswordService.setMasterKey(masterKey, activeAccount.id);
            await main.keyService.setUserKey(userKey, activeAccount.id);
            await main.pinService.userUnlocked(activeAccount.id);
            main.deviceTrustService.trustDeviceIfRequired(activeAccount.id).catch(console.error);
            main.messagingService.send("unlocked");
            main.initOverlayAndTabsBackground?.().catch(console.error);

            globalThis.__opencodeUnlockResult = {{
              email,
              status: "unlocked",
              beforeStatus,
              afterStatus: 2,
            }};
          }} catch (error) {{
            globalThis.__opencodeUnlockResult = {{
              status: "error",
              message: error?.message ?? String(error),
              stack: error?.stack ?? null,
            }};
          }}
        }})();

        return {{ status: "started" }};
      }})()
    """
    eval_bitwarden_background(start_code)

    deadline = time.monotonic() + 20
    while True:
        result = eval_bitwarden_background("globalThis.__opencodeUnlockResult ?? null")
        if result and result.get("status") != "pending":
            print(json.dumps(result, indent=2, sort_keys=True))
            return
        if time.monotonic() > deadline:
            raise RuntimeError("timed out waiting for Bitwarden unlock result")
        time.sleep(0.25)


if __name__ == "__main__":
    main()
