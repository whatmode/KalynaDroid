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
COPY kalyna-native.pkg.tar.zst /tmp/kalyna-native.pkg.tar.zst
RUN --mount=type=tmpfs,dst=/run pacman -U --noconfirm /tmp/kalyna-native.pkg.tar.zst && rm -f /tmp/kalyna-native.pkg.tar.zst
COPY kalyna-shell.service /etc/systemd/system/kalyna-shell.service
RUN systemctl enable kalyna-shell.service
# Remove downloaded package archives and build logs from the installed OS.
# Keep the pacman database and all installed packages intact.
RUN rm -f /usr/lib/sysimage/log/pacman.log /var/log/pacman.log && rm -rf /usr/lib/sysimage/cache/pacman/pkg/* /var/cache/pacman/pkg/*
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
rm -f "$image"; truncate -s "${KALYNAOS_IMAGE_SIZE:-24G}" "$image"
echo "==> Installing bootc image into raw disk image"
# bootc reports "Installation complete!" but the container can remain alive
# during shutdown/cleanup. Keep it inspectable and bound the wait so CI cannot
# hang indefinitely after the disk image has been written.
container_name="kalyna-bootc-install"
podman rm -f "$container_name" >/dev/null 2>&1 || true
set +e
timeout --foreground --signal=TERM --kill-after=30s 20m \
  podman run --name "$container_name" --privileged --pid=host \
    -v /dev:/dev -v "$out:/out" localhost/kalynaos-handheld:ci \
    bootc install to-disk --via-loopback "/out/$(basename "$image")" \
    --filesystem ext4 --wipe --composefs-backend --bootloader systemd
install_rc=$?
set -e
if (( install_rc == 124 )); then
  echo "WARNING: bootc container did not exit within 20 minutes; collecting state"
  podman inspect "$container_name" || true
  podman logs "$container_name" || true
  podman stop --time 10 "$container_name" >/dev/null 2>&1 || true
  # Accept a shutdown hang only if bootc left a readable GPT with an EFI
  # System Partition. This prevents a timeout from masking an incomplete disk.
  partition_table="$(sfdisk --dump "$image")" || {
    echo "bootc timed out and the image has no readable partition table" >&2
    exit 1
  }
  printf '%s\\n' "$partition_table"
  grep -Eiq 'type=[[:space:]]*c12a7328-f81f-11d2-ba4b-00a0c93ec93b' <<<"$partition_table" || {
    echo "bootc timed out and no EFI System Partition was found" >&2
    exit 1
  }
  echo "==> Disk layout verified; treating post-install container shutdown hang as non-fatal"
elif (( install_rc != 0 )); then
  podman inspect "$container_name" || true
  podman logs "$container_name" || true
  echo "bootc install failed with exit code $install_rc" >&2
  exit "$install_rc"
else
  echo "==> bootc installation command returned successfully"
fi
podman rm -f "$container_name" >/dev/null 2>&1 || true

# Validate the actual disk image before it can be compressed or published.
echo "==> Verifying GPT partition layout"
partition_table="$(sfdisk --dump "$image")"
printf '%s\\n' "$partition_table"
grep -q '^label: gpt$' <<<"$partition_table" || { echo "Expected GPT partition table" >&2; exit 1; }
grep -Eiq 'type=[[:space:]]*c12a7328-f81f-11d2-ba4b-00a0c93ec93b' <<<"$partition_table" || { echo "EFI System Partition missing" >&2; exit 1; }
# x86_64 uses the Discoverable Partitions Specification Linux root GUID.
grep -Eiq 'type=[[:space:]]*4f68bce3-e8cd-4db1-96e7-fbcaf984b709' <<<"$partition_table" || { echo "x86_64 Linux root partition (DPS) missing" >&2; exit 1; }

loopdev=""
mountpoint=""
cleanup_validation() {
  if [[ -n "$mountpoint" ]]; then umount "$mountpoint" >/dev/null 2>&1 || true; rmdir "$mountpoint" >/dev/null 2>&1 || true; fi
  if [[ -n "$loopdev" ]]; then losetup -d "$loopdev" >/dev/null 2>&1 || true; fi
}
trap 'cleanup_validation; rm -rf "$work"' EXIT
loopdev="$(losetup --find --show --partscan --read-only "$image")"
udevadm settle
esp="${loopdev}p2"
root="${loopdev}p3"
for part in "$esp" "$root"; do
  for attempt in $(seq 1 20); do [[ -b "$part" ]] && break; sleep 1; done
  [[ -b "$part" ]] || { echo "Missing expected partition device: $part" >&2; exit 1; }
done
esp_type="$(blkid -o value -s TYPE "$esp")"
root_type="$(blkid -o value -s TYPE "$root")"
[[ "$esp_type" == vfat ]] || { echo "Expected FAT EFI filesystem, found: $esp_type" >&2; exit 1; }
[[ "$root_type" == ext4 ]] || { echo "Expected ext4 root filesystem, found: $root_type" >&2; exit 1; }

echo "==> Checking FAT EFI filesystem (read-only)"
fsck.fat -n "$esp"
echo "==> Checking ext4 root filesystem (read-only)"
e2fsck -fn "$root"

mountpoint="$(mktemp -d)"
mount -o ro "$esp" "$mountpoint"
if ! find "$mountpoint/EFI" -type f -iname '*.efi' -print -quit 2>/dev/null | grep -q .; then
  echo "No EFI executable found in the EFI System Partition" >&2
  exit 1
fi
if [[ ! -d "$mountpoint/loader" && ! -d "$mountpoint/EFI/systemd" ]]; then
  echo "No systemd-boot loader configuration directory found on the ESP" >&2
  exit 1
fi
umount "$mountpoint"
rmdir "$mountpoint"
mountpoint=""
losetup -d "$loopdev"
loopdev=""
echo "==> GPT, FAT32 EFI, ext4 root, filesystem checks, and EFI payload verified"

# Generate a block map before compression. bmaptool decompresses .xz while flashing.
# truncate leaves unused sectors as holes; fallocate would allocate all 24 GiB.
echo "==> Creating BMAP (scanning raw disk image)"
time bmaptool create -o "$image.bmap" "$image"
echo "==> BMAP creation finished"

echo "==> Compressing raw disk image with xz -T0 -6 (this can take several minutes)"
time xz --verbose -T0 -6 -z -f "$image"
echo "==> Compression finished"

echo "==> Calculating SHA-256 checksum"
sha256sum "$image.xz" > "$image.xz.sha256"
echo "==> Final artifact sizes"
ls -lh "$image.xz" "$image.bmap" "$image.xz.sha256"
du -h "$image.xz" "$image.bmap"

# Keep this path-filtered image workflow retriggerable after CI-only fixes.
