# demolinux image builder

Use `./demolinux build` from the repository root, or run
`sudo bin/mkdemolinuximg/build -o out -w work .` directly.
Only GPT disk images are built, with GRUB for both BIOS and UEFI and a
compressed Btrfs system partition. ISO, bootstrap, and netboot build modes
are not supported.

- `build`: command-line entry point and environment initialization.
- `build.sh`: build stages, resume markers, and image output.
- `common.sh`: logging, manifest parsing, and run-once helpers.
- `config.sh`: profile loading, options, and dependency lock validation.
- `packages.sh`: pacman configuration, source caches, and package compilation.
- `rootfs.sh`: root filesystem installation, caching, and customization.
- `disk.sh`: partitioning, mounts, boot files, and GRUB installation.
- `build-inputs`: cache fingerprints for compiler, packages, and root filesystem.
- `package-cache.py`: SRCINFO metadata, pacman dependency resolution, and package cache keys.
- `update-deps-lock`: explicitly refresh pinned AUR, Neovim, and Zsh commits.

The shell modules are sourced by `build`, not executed independently.
`profiledef.sh` sets `image_id`, `image_version`, package configuration,
SSH access, data directories, and file permissions.

CI and release helpers live in `.github/scripts/`; workflows remain in
`.github/workflows/`. The VM runner remains `bin/run_archiso`.

Start with a clean work directory after migrating from `mkarchiso`;
old resume markers are not compatible. Cache keys include the new module
paths, so existing package/rootfs caches are invalidated automatically.

## Package cache

Package keys include their own recipe inputs, the build environment, and the keys
of their resolved custom dependencies, not preceding entries in `available_packages`.
Fresh `makepkg --printsrcinfo` output supplies runtime, build, and check dependencies,
including architecture-specific and split-package fields. Checked-in `.SRCINFO`
files are not used. Metadata generation runs as the build user, not root.

The planner creates a temporary metadata-only repository and uses pacman with an
empty local database and the build chroot's pinned official databases to resolve
versions, providers, and transitive runtime dependencies. Custom recipes take
precedence over official packages; a recipe's own outputs are excluded while
resolving its build environment. Cycles between recipe builds and duplicate
outputs fail explicitly. Dependencies are built before consumers.

Each build uses a freshly reset chroot and installs only the selected dependency
archives (including the base toolchain). Only needed outputs of split dependencies
are installed. Official downloads reuse pacman's cache and honor
`DEMOLINUX_PACMAN_CACHE`; otherwise new downloads go in `packages/downloads/`.
Makepkg checks dependencies but cannot silently fetch an unplanned replacement.
Packages that rely on undeclared dependencies previously present in the dirty
chroot will need their recipes corrected.

`packages/db/.inputs/<recipe>` retains the key and output filenames;
`<recipe>.json` records the individual inputs and dependency keys for cache-miss
diagnostics. Missing archives still force a rebuild. Toolchain/snapshot changes
remain conservative global invalidations, but image-only `profiledef.sh` changes
do not invalidate package builds. Pristine build environments are kept under
`packages/chroots/<environment-key>/`, separate from legacy `packages/chroot/`.

The first build after this cache-format migration rebuilds existing packages once.
Subsequent unrelated recipe edits or package-list reordering retain cache hits.
For example, changing `awesome` does not invalidate `emoji-test`; changing custom
`pambase` can, since it is a transitive dependency of the base toolchain.

Run the host-side tests without building an image or installing packages:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s bin/mkdemolinuximg -p 'test_package_cache.py' -v
```

Resolver/archive integration tests require Arch's `pacman`, `vercmp`, and `bsdtar`.
