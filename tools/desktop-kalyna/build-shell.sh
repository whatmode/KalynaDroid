#!/bin/bash
# Builds kalyna-shell (Qt 6) for aarch64 in a disposable Arch Linux ARM chroot with signature-checked
# packages, the same way tools/desktop-kde/build-kwin.sh builds KWin.
set -euo pipefail
out=$(realpath -m "${1:?out dir}")
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
kde=$repo/tools/desktop-kde
[ "$(uname -m)" = aarch64 ] || { echo 'kalyna-shell needs a native aarch64 runner' >&2; exit 1; }
mirror=https://fl.us.mirror.archlinuxarm.org/aarch64
builder=68B3537F39A313B3E574D06777193F152BDBE6A6
work=$(mktemp -d)
trap 'sudo umount "$work/root/proc" 2>/dev/null || true; sudo rm -rf "$work"' EXIT
mkdir -p "$work/db" "$work/root" "$work/pkgs" "$out"
fetch() { curl -fsSL --proto '=https' --proto-redir '=https' --retry 6 --retry-all-errors -o "$1" "$2"; }
for r in core extra alarm; do
    fetch "$work/db/$r.db" "$mirror/$r/$r.db"
    mkdir -p "$work/db/x_$r"
    tar -xzf "$work/db/$r.db" -C "$work/db/x_$r"
done
touch "$work/runtime.txt"
python3 "$kde/closure.py" "$work/db" "$work/runtime.txt" "$here/shell-build-seeds.txt" > "$work/packages.txt"
export work mirror builder kde
download() {
    local entry=$1 sum=$2 file=${1#*/}
    fetch "$work/pkgs/$file" "$mirror/$entry"
    fetch "$work/pkgs/$file.sig" "$mirror/$entry.sig"
    gpgv --status-fd 1 --keyring "$kde/archlinuxarm-builder.gpg" "$work/pkgs/$file.sig" "$work/pkgs/$file" 2>/dev/null \
        | grep -Eq "^\[GNUPG:\] VALIDSIG .* $builder\$"
    echo "$sum  $work/pkgs/$file" | sha256sum -c - >/dev/null
}
export -f fetch download
xargs -P 8 -n 2 bash -c 'set -euo pipefail; download "$@"' _ < "$work/packages.txt"
while read -r entry sum; do
    sudo tar -xf "$work/pkgs/${entry#*/}" -C "$work/root" --no-same-owner \
        --exclude=.PKGINFO --exclude=.MTREE --exclude=.INSTALL --exclude=.BUILDINFO --exclude=.CHANGELOG
done < "$work/packages.txt"
sudo mkdir -p "$work/root/build/shots" "$work/root/tmp/home" "$work/root/proc" "$work/root/dev" "$work/root/tmp"
sudo chmod 1777 "$work/root/tmp"
sudo mknod -m 666 "$work/root/dev/null" c 1 3
sudo mknod -m 666 "$work/root/dev/zero" c 1 5
sudo mknod -m 666 "$work/root/dev/random" c 1 8
sudo mknod -m 666 "$work/root/dev/urandom" c 1 9
sudo mount -t proc proc "$work/root/proc"
sudo cp -a "$repo/kalyna/native" "$work/root/build/src"
run() { sudo chroot "$work/root" /usr/bin/env PATH=/usr/bin:/bin HOME=/root LC_ALL=C.UTF-8 "$@"; }
run /usr/bin/cmake -S /build/src -B /build/out -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
run /usr/bin/cmake --build /build/out --parallel 4
run /usr/bin/env DESTDIR=/build/dest /usr/bin/cmake --install /build/out
sudo cp -a "$work/root/build/dest/." "$out/"
sudo chown -R "$(id -u):$(id -g)" "$out"
strip --strip-unneeded "$out/usr/bin/kalyna-shell"
# Screenshots of the phone layout (Kalyna on Android), drawn in software without a screen. They are
# published with the package so the layout can be checked before anyone installs it.
shots=$(realpath -m "$out/../shots")
mkdir -p "$shots"
run /usr/bin/env XDG_RUNTIME_DIR=/tmp QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    KALYNA_PHONE=1 KALYNA_SCALE=1.6 KALYNA_ROTATE=none KALYNA_DEMO=1 HOME=/tmp/home \
    timeout 90 /build/dest/usr/bin/kalyna-shell --nested --demo --size 720x1602 \
    --test /build/src/tests/PhoneDriver.qml --test-out /build/shots 2>&1 | grep -E "phone test|qml|QML|rror" | head -40 || true
sudo cp -a "$work/root/build/shots/." "$shots/" 2>/dev/null || true
sudo chown -R "$(id -u):$(id -g)" "$shots" 2>/dev/null || true
ls -l "$shots" || true
{
    echo "kalyna-shell $(cat "$repo/kalyna/native/VERSION") from $(git -C "$repo" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "Executable sha256 $(sha256sum "$out/usr/bin/kalyna-shell" | cut -d' ' -f1)"
    echo 'Build packages (Arch Linux ARM signatures verified):'
    cat "$work/packages.txt"
} > "$out/../desktop-kalyna.shell.txt"
