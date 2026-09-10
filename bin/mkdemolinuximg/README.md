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
- `update-deps-lock`: explicitly refresh pinned AUR, Neovim, and Zsh commits.

The shell modules are sourced by `build`, not executed independently.
`profiledef.sh` sets `image_id`, `image_version`, package configuration,
SSH access, data directories, and file permissions.

CI and release helpers live in `.github/scripts/`; workflows remain in
`.github/workflows/`. The VM runner remains `bin/run_archiso`.

Start with a clean work directory after migrating from `mkarchiso`;
old resume markers are not compatible. Cache keys include the new module
paths, so existing package/rootfs caches are invalidated automatically.
