# KalynaOS CachyOS Handheld microSD image

This builder creates a raw GPT disk image intended for Balena Etcher. It composes a pinned CachyOS Handheld bootc base, installs the native Kalyna package, and exports a Btrfs/systemd-boot disk image.

## Build

On a Linux host with Podman, loop-device support and xz:

```sh
sudo bash tools/steam-deck-image/build.sh ./kalyna-native-*-x86_64.pkg.tar.zst
```

The output is `out/kalynaos/KalynaOS-CachyOS-Handheld-SteamDeck.img.xz` with a SHA-256 file. Select the compressed image and the microSD card in Balena Etcher. Flashing erases the selected card.

## Validation status

The base composition is pinned to the CachyOS Deckify bootc project, a community CachyOS Handheld composition, not an official CachyOS-produced image. KDE/Gamescope components are retained from that base.

This milestone builds a bootc-installed persistent Btrfs disk image. RAM-copy boot, first-boot partition expansion, automatic graphical-session integration and physical Steam Deck LCD/OLED validation are not yet certified. CI artifact generation alone does not prove those features. This workflow does not install to the internal SSD.
