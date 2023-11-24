### demolinux
###### My own Arch-based Linux distro which I spend too much time working on, attempt nº2 
-----

![image](https://github.com/demostanis/demolinux/assets/40673815/4b168f1d-3fde-4426-a0e9-c58dad82706a)
<table>
  <tr>
    <td>
      <img src="https://github.com/demostanis/demolinux/assets/40673815/23787c38-c567-48a9-8099-a9f0cdf642c6" />
      <img src="https://github.com/demostanis/demolinux/assets/40673815/e040b0b9-3119-41fb-bddc-9f789e24be75" />
    </td>
    <td>
      <img src="https://github.com/demostanis/demolinux/assets/40673815/f1c09504-671a-4a8d-88c0-4b2810fc3f19" />
      <img src="https://github.com/demostanis/demolinux/assets/40673815/1439176a-e124-4fa6-ba93-e92234d0f1d7" />
    </td>
  </tr>
</table>

-----
I wanted more than just dotfiles.

So I forked [archiso](https://wiki.archlinux.org/title/Archiso), and made it output a disk image containing:
 - a BIOS boot partition
 - an EFI system partition, which contains the kernel and the initramfs (also used for BIOS booting)
 - a Btrfs filesystem

The Btrfs filesystem is where all the fun resides, since it has the following subvolumes:
 - *airootfs*, which contains the system in read-only
 - *swap*
 - *data*, which stores persistent data
 - *persistfs*, which stores manually committed files (through a custom tool named `persistfs`) such as edited configuration files without having to rebuild the image
 - *snapshots*, of the airootfs, to revert in case of failed updates

A custom mkinitcpio hook resizes the btrfs filesystem on first boot.

On every boot, this hook mounts `/` as an `overlayfs` of:
 - airootfs/copytoram
 - persistfs
 - a tmpfs (cowspace)

**Which lets me have a read-only system where every file I create is deleted on reboot, except the ones in /data, and the ones I manually make persistent.**

Complementary to that, I wrote my own AwesomeWM configuration in Lua. It features:
 - A dock
 - A panel (with its widgets)
 - An overview
 - An emoji picker
 - A small screen locker
 - Custom terminal tabs

Which provides a very comfy experience.

Also written in Lua is my [small Neovim configuration](airootfs/etc/skel/.config/nvim).
It has basic auto-completion, and [a few other plugins](nvim_packages) that don't get too much in my way.

Another very pimped application in demolinux is Firefox.
It comes with addons such as uBlock Origin, Dark Reader, CanvasBlocker, or even VimFx (which uses [legacyfox](https://gir.st/blog/legacyfox.htm)),
and a custom [user.js](airootfs/etc/skel/.mozilla/firefox/default.profile/user.js).

All this and many other additions which make a very pleasant use of my desktop, after many months of work and hundreds of commits.
