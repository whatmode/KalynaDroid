# Kalyna Steam Deck bootable image

This produces a **UEFI-bootable x86_64 Arch Linux live ISO** containing the repository's
`kalyna-native` package. It is intended for Steam Deck LCD (Jupiter) and OLED (Galileo)
hardware. The native shell already detects those product names and rotates the panel.

## Build locally on Arch Linux / CachyOS

Install the image tooling:

```sh
sudo pacman -S --needed archiso pacman-contrib
```

Build the native pacman package first:

```sh
cd kalyna/native/packaging
makepkg -s
cd ../../..
```

Then build the ISO (use the exact package filename produced by makepkg):

```sh
sudo bash tools/steam-deck-image/build.sh \
  kalyna/native/packaging/kalyna-native-2.0.0-4-x86_64.pkg.tar.zst
```

The result is written to `out/steam-deck-image/kalyna-steam-deck-x86_64.iso`,
with a `SHA256SUMS` file beside it.

## Write to a USB drive

Use a USB-C drive or a USB-C hub with a USB drive. Verify the target device carefully;
the following command erases it:

```sh
lsblk
sudo dd if=out/steam-deck-image/kalyna-steam-deck-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Replace `/dev/sdX` with the whole USB device, not a partition. Alternatively, use
Balena Etcher or another ISO writer. Shut down the Deck, hold **Volume Down** while
pressing Power, and choose the USB device in the boot menu.

This is a live image; it does not repartition or install to the Deck's internal SSD.
The ISO build and checksum can be verified in CI, but hardware-specific Wi-Fi, audio,
controls, suspend/resume, and touch behavior still need testing on a physical Deck.
