#!/usr/bin/env python3
import json
from pathlib import Path

from firefox_eval import eval_firefox, sync_to_firefox_tmp


ADDON_ID = "{446900e4-71c2-419f-a6a7-df9c091e268b}"
ADDON_PATH = Path("/tmp/bitwarden-build")
HOST_BUILD_PATH = Path("/home/demostanis/downloads/bitwarden-build")


def main():
    sync_to_firefox_tmp(HOST_BUILD_PATH, "bitwarden-build")
    addon_path = str(ADDON_PATH)
    code = f"""
      await (async () => {{
        const addonId = {json.dumps(ADDON_ID)};
        const addonPath = {json.dumps(addon_path)};
        const addon = await AddonManager.getAddonByID(addonId);

        if (addon?.temporarilyInstalled && typeof addon.reload === "function") {{
          setTimeout(() => {{
            addon.reload().catch(console.error);
          }}, 0);
          return {{
            action: "reload-started",
            id: addon.id,
            name: addon.name,
            isActive: addon.isActive,
            temporarilyInstalled: addon.temporarilyInstalled,
          }};
        }}

        if (addon?.temporarilyInstalled) {{
          await addon.uninstall();
        }}

        const addonFile = FileUtils.File(addonPath);
        const manifestFile = addonFile.clone();
        manifestFile.append("manifest.json");
        if (!manifestFile.exists()) {{
          throw new Error(`manifest not found: ${{manifestFile.path}}`);
        }}

        setTimeout(() => {{
          AddonManager.installTemporaryAddon(addonFile).catch(console.error);
        }}, 0);
        return {{
          action: addon ? "reinstall-started" : "install-started",
          id: addonId,
          name: addon?.name ?? null,
          isActive: addon?.isActive ?? false,
          temporarilyInstalled: addon?.temporarilyInstalled ?? false,
        }};
      }})()
    """
    print(json.dumps(eval_firefox(code), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
