#!/usr/bin/env bash
# Build a bootable x86_64 Arch ISO containing the native Kalyna shell.
# Run on Arch Linux/CachyOS: sudo bash tools/steam-deck-image/build.sh PACKAGE.pkg.tar.zst [OUTPUT_DIR]
set -euo pipefail

package=${1:?Usage: build.sh kalyna-native-*-x86_64.pkg.tar.zst [output-dir]}
out=${2:-"$PWD/out/steam-deck-image"}
package=$(realpath "$package")
out=$(mkdir -p "$out" && cd "$out" && pwd)

if [[ $EUID -ne 0 ]]; then
  echo "Run this image builder as root (sudo)." >&2
  exit 1
fi
for command in mkarchiso repo-add pacman; do
  command -v "$command" >/dev/null || {
    echo "Missing $command. Install archiso and pacman-contrib first." >&2
    exit 1
  }
done
[[ -f "$package" ]] || { echo "Package not found: $package" >&2; exit 1; }
pacman -Qip "$package" | grep -Eq 'Architecture[[:space:]]*:[[:space:]]*x86_64' || {
  echo "The supplied package is not an x86_64 pacman package." >&2
  exit 1
}

profile_source=/usr/share/archiso/configs/releng
[[ -d "$profile_source" ]] || { echo "archiso releng profile not found: $profile_source" >&2; exit 1; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
profile="$work/profile"
repo="$work/repo"
mkdir -p "$profile" "$repo"
cp -a "$profile_source/." "$profile/"
cp "$package" "$repo/"
repo-add "$repo/kalyna-local.db.tar.gz" "$repo/"*.pkg.tar.zst

# Make the just-built Kalyna package available to pacstrap during ISO creation.
cat >> "$profile/pacman.conf" <<PACMAN

[kalyna-local]
SigLevel = Optional TrustAll
Server = file://$repo
PACMAN

cat >> "$profile/packages.x86_64" <<'PACKAGES'

# Native Kalyna session and Steam Deck hardware support
kalyna-native
networkmanager
mesa
vulkan-radeon
pipewire
wireplumber
bluez
bluez-utils
brightnessctl
PACKAGES

# Start Kalyna directly on the Deck's display. The native shell detects Jupiter
# (LCD) and Galileo (OLED) and applies the correct panel rotation itself.
mkdir -p "$profile/airootfs/etc/systemd/system/multi-user.target.wants"
cat > "$profile/airootfs/etc/systemd/system/kalyna-shell.service" <<'UNIT'
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
Environment=QT_QPA_EGLFS_HIDECURSOR=0
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
ln -s ../kalyna-shell.service "$profile/airootfs/etc/systemd/system/multi-user.target.wants/kalyna-shell.service"
ln -s /usr/lib/systemd/system/NetworkManager.service "$profile/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# Give the generated ISO a distinct name without changing the upstream profile.
sed -i 's/^iso_name=.*/iso_name="kalyna-steam-deck"/' "$profile/profiledef.sh"
mkarchiso -v -w "$work/build" -o "$out" "$profile"

iso=$(find "$out" -maxdepth 1 -type f -name '*.iso' -print -quit)
[[ -n "$iso" ]] || { echo "mkarchiso completed without producing an ISO." >&2; exit 1; }
if [[ "$iso" != "$out/kalyna-steam-deck-x86_64.iso" ]]; then
  mv "$iso" "$out/kalyna-steam-deck-x86_64.iso"
fi
(
  cd "$out"
  sha256sum kalyna-steam-deck-x86_64.iso > SHA256SUMS
)
ls -lh "$out/kalyna-steam-deck-x86_64.iso" "$out/SHA256SUMS"
