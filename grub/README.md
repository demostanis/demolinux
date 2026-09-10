# Image boot menu

`grub.cfg.in` is the entire demolinux boot menu. The image builder substitutes
the boot and system filesystem UUIDs, checks it with `grub-script-check`, and
installs it as `/grub/grub.cfg` on the EFI system partition. No host GRUB defaults,
OS probing, or patched `grub-mkconfig` scripts are involved.

Keep normal boot, RAM boot, and recovery first, followed by the snapshot submenu
when snapshots exist. Firmware setup, iPXE, and memtest are shown only when the
firmware or corresponding binary supports them. BIOS and UEFI use the same file.

Kernels and initramfs images are loaded from the Btrfs system partition, including
each snapshot's own boot files. Available microcode images and the initramfs are
loaded with one `initrd` command.

The `99999199999` resume-offset placeholder is updated by the initramfs after
first-boot swapfile creation. RAM boot deliberately does not request disk resume.

RAM mode copies only the root and saved persistence to tmpfs, preserving ACLs,
extended attributes, and hard links. It unmounts the boot disk before starting
the desktop. Disk `/data` is not copied: the session gets an empty, temporary
`/data` instead. Writes to `/data` and `persistfs` in this mode are lost on reboot.
Disk swap and snapshots are unavailable. A copy failure stops boot rather than
pretending that the disk is safe to unplug.
