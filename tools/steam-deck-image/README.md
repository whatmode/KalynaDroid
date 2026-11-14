# KalynaOS CachyOS Handheld microSD image

This builder creates a raw GPT disk image intended for Balena Etcher. It composes a pinned CachyOS Handheld bootc base, installs the native Kalyna package, and exports a systemd-boot image with a FAT EFI System Partition and an ext4 Linux root partition.

## Build

On a Linux host with Podman, loop-device support, `xz`, `bmaptool`, `dosfstools` and `e2fsprogs`:

```sh
sudo bash tools/steam-deck-image/build.sh ./kalyna-native-*-x86_64.pkg.tar.zst
```

The output is `out/kalynaos/KalynaOS-CachyOS-Handheld-SteamDeck.img.xz` with a SHA-256 file and a matching `.bmap` block map. Select the compressed image and the microSD card in Balena Etcher. Flashing erases the selected card.

## Image layout and CI validation

- GPT partition table.
- Architecture-specific BIOS boot partition and UEFI EFI System Partition.
- FAT EFI filesystem with an EFI executable and systemd-boot loader files.
- ext4 Linux root filesystem, created with the bootc composefs/fs-verity requirements.
- CI checks GPT partition types, filesystem signatures, FAT and ext4 consistency, and EFI payload before compression. It also verifies the compressed stream and SHA-256 checksum.

The bootc installer controls exact partition sizing; its documented layout guarantees an ESP of at least 512 MiB but treats exact sizes as implementation details. The previously observed 2 GiB ESP is therefore not assumed to be a required KalynaOS size, and CI records the actual layout rather than changing bootc partitioning internals blindly.

## Validation status

The base composition is pinned to the CachyOS Deckify bootc project, a community CachyOS Handheld composition, not an official CachyOS-produced image. KDE/Gamescope components are retained from that base.

Passing CI proves image construction and offline partition/filesystem checks, not a successful physical boot. RAM-copy boot with persistent microSD data, first-boot storage expansion, automatic graphical-session integration, and physical Steam Deck LCD/OLED/controller validation remain separate acceptance tests. This workflow installs only into a regular image file and does not target the build runner's internal disk.
