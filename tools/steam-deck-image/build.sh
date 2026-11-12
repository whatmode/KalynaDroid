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

# The pinned upstream revision hard-codes an archived Arch bootstrap URL that
# has disappeared from the mirror. Keep the upstream CachyOS composition, but
# fetch the current official bootstrap and verify it against Arch's published
# SHA256 manifest so this stage does not depend on a retired monthly snapshot.
python3 - "$work/Containerfile" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
start = text.index('ENV VERSION="')
end_marker = "    apk cache clean"
end = text.index(end_marker, start) + len(end_marker)
replacement = """RUN apk add gnutar zstd curl && \\
    curl -fL --retry 3 https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst -o /archlinux-bootstrap-x86_64.tar.zst && \\
    curl -fL --retry 3 https://geo.mirror.pkgbuild.com/iso/latest/sha256sums.txt -o /sha256sums.txt && \\
    grep -E '[[:space:]]archlinux-bootstrap-x86_64.tar.zst$' /sha256sums.txt > /bootstrap.sha256 && \\
    sha256sum -c /bootstrap.sha256 && \\
    tar -xf /archlinux-bootstrap-x86_64.tar.zst --numeric-owner && \\
    rm -f /archlinux-bootstrap-x86_64.tar.zst /sha256sums.txt /bootstrap.sha256 && \\
    apk del gnutar zstd curl && \\
    apk cache clean"""
# The upstream Containerfile invokes dracut before generating modules.dep.
# Generate the kernel module index first, otherwise dracut aborts on a clean build.
dracut_marker = '    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"'
dracut_replacement = '    kernel_version="$(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf \'%f\\n\' | sort -V | tail -n 1)" && depmod -a "$kernel_version" && dracut --force "/usr/lib/modules/$kernel_version/initramfs.img"'
if dracut_marker not in text:
    raise SystemExit("Expected upstream dracut command not found; refusing to patch an unknown recipe")
text = text.replace(dracut_marker, dracut_replacement, 1)
text = text[:start] + replacement + text[end:]
path.write_text(text)
PY

cat >> "$work/Containerfile" <<'CONTAINER'
# bootc disk installation requires bootupd for OSTree-based deployments.
RUN --mount=type=tmpfs,dst=/run pacman -Sy --needed --noconfirm bootupd && pacman -S --clean --noconfirm
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

# Keep this path-filtered image workflow retriggerable after CI-only fixes.
