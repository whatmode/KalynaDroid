#!/usr/bin/env bash
set -euo pipefail
pkg=${1:?native Kalyna pacman package required}
out=${2:-"$PWD/out/kalynaos"}
[[ $EUID -eq 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ -s "$pkg" ]] || { echo 'Missing package.' >&2; exit 1; }
command -v podman >/dev/null
src=${KALYNAOS_UPSTREAM_DIR:-"$PWD/.cache/cachyos-deckify-bootc"}
[[ -f "$src/Containerfile" && -d "$src/files" ]] || { echo "Missing pinned upstream source: $src" >&2; exit 1; }
mkdir -p "$out"
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -a "$src/." "$work/"
cp "$pkg" "$work/kalyna-native.pkg.tar.zst"
cat >> "$work/Containerfile" <<'CONTAINER'
COPY kalyna-native.pkg.tar.zst /tmp/kalyna-native.pkg.tar.zst
RUN --mount=type=tmpfs,dst=/run pacman -U --noconfirm /tmp/kalyna-native.pkg.tar.zst && rm -f /tmp/kalyna-native.pkg.tar.zst
COPY kalyna-shell.service /etc/systemd/system/kalyna-shell.service
RUN systemctl enable kalyna-shell.service
CONTAINER
cat > "$work/kalyna-shell.service" <<'UNIT'
[Unit]
Description=KalynaOS native shell
After=systemd-user-sessions.service dbus.service NetworkManager.service
Wants=NetworkManager.service
[Service]
Type=simple
ExecStart=/usr/bin/kalyna-shell
Restart=on-failure
RestartSec=2
Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QPA_EGLFS_INTEGRATION=eglfs_kms
Environment=QT_QPA_EGLFS_ALWAYSSET=1
Environment=QT_IM_MODULE=qtvirtualkeyboard
StandardInput=tty
StandardOutput=journal
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes
[Install]
WantedBy=multi-user.target
UNIT
podman build --pull=always -t localhost/kalynaos-handheld:ci "$work"
image="$out/KalynaOS-CachyOS-Handheld-SteamDeck.img"
rm -f "$image"; fallocate -l "${KALYNAOS_IMAGE_SIZE:-24G}" "$image"
podman run --rm --privileged --pid=host -v /dev:/dev -v "$out:/out" localhost/kalynaos-handheld:ci bootc install to-disk --via-loopback "/out/$(basename "$image")" --filesystem btrfs --wipe --bootloader systemd
xz -T0 -z -f "$image"
sha256sum "$image.xz" > "$image.xz.sha256"
ls -lh "$image.xz" "$image.xz.sha256"
