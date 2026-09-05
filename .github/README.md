# CI build and test pipeline

Both `trigger` and `master` build a fresh disk image, run the entire VM suite,
and publish only after every test shard passes. Superseded runs on the same
branch are cancelled. `workflow_dispatch` can be used to measure a warm rerun.

## Baseline and five-minute target

Run 33924228733 spent 31m39s queued, 52m30s building, and 4m28s in the failing
test step. The previous successful run spent 6m48s testing and 1m46s splitting,
checksumming, and publishing the image.

The five-minute target applies to **warm-cache execution**, not a fresh build
of all dependencies or GitHub's runner queue. It is a target, not a measured
guarantee: cache transfer, runner contention, VPN tests, and multi-GB release
uploads depend on external services. Compare two runs on the same commit:
the first seeds caches, the second measures the warm path. Do not enforce the
target by skipping tests or killing a valid cold build after five minutes.

## Caches

- Compiled packages, plugin sources, and pacstrap downloads are reused across
  compatible builds. Recipe content, patches, file modes, AUR commits, and
  build environment inputs determine reuse, not just `pkgver`/`pkgrel`.
  Changing a recipe also rebuilds subsequent packages, which may depend on it.
- An exact-match installed-root cache bypasses compilation and pacstrap.
  All `airootfs` files and package inputs are in its key; configuration changes
  cannot silently retain stale files. Those changes take the package-cache
  path and regenerate the installed-root cache instead.
- The installed-root archive preserves ownership, permissions, ACLs, xattrs,
  and symlinks. It is captured **before** customization, source checkout,
  version generation, or SSH key injection. Those steps always run again.
- Caches are saved before VM tests, so test failures do not discard a completed
  dependency build. Chroots, test disks, and SSH private keys are never cached.

## VM tests

CI uses QEMU's built-in user networking rather than an Arch `passt` executable
subject to the Ubuntu runner's AppArmor profile. Local `run_archiso` still uses
`passt` by default; `-N user` explicitly selects the CI backend.
DHCP runs on `virbr0`, not its enslaved Ethernet interface. Requesting leases
on both interfaces consumes two addresses and leaves SSH forwarding pointing
at the abandoned first lease.

Four shards each have their own qcow2 overlay, SSH/QMP ports, SSH control socket,
process lifetime, and logs. The release image is never copied or modified by
tests. GUI tests run sequentially within each VM to avoid focus/input races;
the system-update and snapshot-reboot tests stay together. The host-side tests
ensure every executable guest test is assigned exactly once.

Run checks locally:

```sh
python3 .github/test-ci.py
actionlint .github/workflows/default.yml
bash .github/run-tests.sh out/demolinux-YYYY.MM.DD-x86_64.img
```

The parallel suite needs KVM, QEMU with libslirp, Zsh, and approximately 8 GiB
of guest RAM. `DEMOLINUX_SSH_KEY` can select a key authorized in the image.
Logs and failure screenshots are under `.ci/tests/<shard>/`; CI uploads them
on failure. Tests stop immediately if QEMU dies and have bounded boot/suite
timeouts. Cleanup targets only the processes owned by that shard.

MPV uses its software X11 renderer inside the test overlays, since the CI VMs
do not have GPU acceleration. Release-image renderer settings are unchanged;
GPU-specific rendering is not covered by this headless suite.
