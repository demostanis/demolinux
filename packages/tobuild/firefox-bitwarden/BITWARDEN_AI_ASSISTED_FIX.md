# Bitwarden Passkey Startup Debugging

This notes the AI-assisted debugging workflow used for the Firefox Bitwarden package and the scripts added under `dev/`.

## Problem

On a fresh Firefox start, Bitwarden could miss conditional passkey requests created by restored pages. The visible symptom on `passkeys.eu` was that the inline credential popup showed a normal login entry, or no passkey entry, even though the vault item contained a passkey.

The important runtime state was checked from the Firefox browser/chrome context, not the page context:

- `navigator.credentials.get` on the page was inspected to see whether Bitwarden had patched WebAuthn.
- `bitwardenMain.fido2ActiveRequestManager.getActiveRequest(tabId)` was inspected from `background.html`.
- `overlayBackground.inlineMenuFido2Credentials` and `overlayBackground.focusedFieldData` were inspected to see why the inline menu filtered entries.
- The inline menu iframe (`overlay/menu-list.html`) was inspected to verify rendered entries and aria labels.

## Fix Tried

Patch `0004-refresh-fido2-content-scripts-on-unlock.patch` implements the less-invasive startup refresh approach:

- After Bitwarden reaches a non-logged-out auth state and passkeys are enabled, it injects FIDO2 content scripts into already-open HTTPS tabs.
- It then reloads those HTTPS tabs once so page startup JavaScript can run again after Bitwarden's WebAuthn patch is available.

This is intentionally narrower than showing passkeys without an active FIDO2 request or doing click-time recovery.

## Package Workflow

From `packages/tobuild/firefox-bitwarden`:

```sh
updpkgsums
makepkg -s
```

The package build should produce:

```text
firefox-bitwarden-2026.1.1-13-any.pkg.tar.zst
```

## VM Scripts

The scripts are stored in `packages/tobuild/firefox-bitwarden/dev/` and are copied into the VM at:

```text
/home/demostanis/downloads/bitwarden-dev-scripts/
```

### Reset Firefox With Debugging

Installed in the VM as:

```text
/home/demostanis/.local/bin/reset-firefox-debug
```

It resets the Firefox profile and starts Firefox with:

```sh
firefox-hardened --start-debugger-server
```

### Load Extension

Loads the unpacked build from `/home/demostanis/downloads/bitwarden-build`, syncing it into Firefox's private `/tmp` first:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/load-extension.py
```

### Reload Extension

Reloads the temporary Bitwarden extension after rebuilding/syncing:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/reload-extension.py
```

### Log Into Bitwarden EU

Switches the extension login screen from `self-hosted` to `bitwarden.eu` and logs into the throwaway test account:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/login-vault-eu.py
```

### Unlock Existing Vault

If the account is already logged in but locked, unlock it with:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/unlock-vault.py
```

### Show Bitwarden Logs

Show recent Bitwarden-related browser console logs:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/show-logs.py -n 30
```

Follow logs:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/show-logs.py -f
```

### Test Passkey Popup

Open `passkeys.eu`, focus the email field, and inspect inline menu iframe state:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/test-passkey-popup.py
```

Inspect the login form variant:

```sh
python /home/demostanis/downloads/bitwarden-dev-scripts/test-passkey-popup.py --login-form
```

## Manual End-to-End Flow

```sh
./dctrl shell 'setsid /home/demostanis/.local/bin/reset-firefox-debug >/tmp/reset-firefox-debug.log 2>&1 < /dev/null &'
./dctrl shell 'python /home/demostanis/downloads/bitwarden-dev-scripts/load-extension.py'
./dctrl shell 'python /home/demostanis/downloads/bitwarden-dev-scripts/login-vault-eu.py'
./dctrl shell 'python /home/demostanis/downloads/bitwarden-dev-scripts/firefox_eval.py "await (async()=>{ const win=Services.wm.getMostRecentWindow(\"navigator:browser\"); win.gBrowser.selectedBrowser.loadURI(Services.io.newURI(\"https://passkeys.eu/\"), { triggeringPrincipal: Services.scriptSecurityManager.getSystemPrincipal() }); return {opened:\"https://passkeys.eu/\"}; })()"'
```

Then test the page manually in the VM.
