#!/bin/bash
# The Kalyna desktop package: the Qt 6 runtime and apps Kalyna needs beyond the Linux runtime
# (Arch Linux ARM packages, signature-checked, closure from seeds.txt), kalyna-shell built by
# build-shell.sh, and our overlay. Usage: build.sh OUT SHELL_DIR
set -euo pipefail
out=${1:?out dir}
shell=${2:?kalyna-shell install dir}
here=$(cd "$(dirname "$0")" && pwd)
kde=$here/../desktop-kde
mirror=${ALARM_MIRROR:-https://fl.us.mirror.archlinuxarm.org/aarch64}
builder=68B3537F39A313B3E574D06777193F152BDBE6A6
fetch() { curl -fsSL --proto '=https' --proto-redir '=https' --retry 6 --retry-delay 5 --retry-all-errors -o "$1" "$2"; }
work=$(mktemp -d); mkdir -p "$out" "$work/db" "$work/root"
pkgs=${PKG_CACHE:-$work/pkgs}; mkdir -p "$pkgs"
trap 'rm -rf "$work"' EXIT
for repo in core extra alarm; do
  fetch "$work/db/$repo.db" "$mirror/$repo/$repo.db"
  mkdir -p "$work/db/x_$repo" && tar -xzf "$work/db/$repo.db" -C "$work/db/x_$repo"
done
python3 "$kde/closure.py" "$work/db" "$kde/runtime-packages.txt" "$here/seeds.txt" > "$work/pkglist.txt"
echo "kalyna: $(wc -l < "$work/pkglist.txt") packages beyond the runtime's own"
while read -r entry sum; do
  file=${entry#*/}
  [ -s "$pkgs/$file" ] || fetch "$pkgs/$file" "$mirror/$entry"
  fetch "$work/pkg.sig" "$mirror/$entry.sig"
  if ! gpgv --status-fd 1 --keyring "$kde/archlinuxarm-builder.gpg" "$work/pkg.sig" "$pkgs/$file" 2>/dev/null \
      | grep -Eq "^\[GNUPG:\] VALIDSIG .* $builder\$"; then
    echo "$file: no valid Arch Linux ARM Build System signature" >&2; rm -f "$pkgs/$file"; exit 1
  fi
  if [ "$(sha256sum "$pkgs/$file" | cut -d' ' -f1)" != "$sum" ]; then
    echo "$file: sha256 differs from the repository database's" >&2; rm -f "$pkgs/$file"; exit 1
  fi
  tar -xf "$pkgs/$file" -C "$work/root" --no-same-owner --no-same-permissions \
    --exclude=.PKGINFO --exclude=.MTREE --exclude=.INSTALL --exclude=.BUILDINFO --exclude=.CHANGELOG
done < "$work/pkglist.txt"
cp -a "$shell/." "$work/root/"
cp -a "$here/overlay/." "$work/root/"
chmod 755 "$work/root/usr/local/bin/"* 2>/dev/null || true
rm -rf "$work/root/usr/share/doc" "$work/root/usr/share/man" "$work/root/usr/share/info" \
       "$work/root/usr/share/gtk-doc" "$work/root/usr/include" "$work/root/usr/lib/pkgconfig" \
       "$work/root/usr/lib/cmake" "$work/root/usr/share/help"
find "$work/root/usr/share/locale" -mindepth 1 -maxdepth 1 -type d ! -name 'en*' ! -name 'uk*' -exec rm -rf {} + 2>/dev/null || true
find "$work/root/usr/lib" -name '*.a' -delete
chmod -R u+rwX "$work/root"
sed 's#^[a-z]*/##' "$work/pkglist.txt" > "$out/desktop-kalyna.packages.txt"
tar -C "$work/root" --zstd -cf "$out/desktop-kalyna.tar.zst" .
sha256sum "$out/desktop-kalyna.tar.zst" | awk '{print $1}' > "$out/desktop-kalyna.sha256"
stat -c %s "$out/desktop-kalyna.tar.zst" > "$out/desktop-kalyna.size"
ls -l "$out/desktop-kalyna.tar.zst"
