#!/bin/bash
# Runs the shell in a virtual X screen (Xvfb, software OpenGL) with the test driver and saves
# screenshots of every step to $OUT. Usage: tests/run-tests.sh [OUT] [extra kalyna-shell args]
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-/tmp/kalyna-test}; shift
mkdir -p "$OUT"; rm -f "$OUT"/*.png
export LD_LIBRARY_PATH=/opt/qt6/lib:/opt/kdeps/lib:${LD_LIBRARY_PATH:-}
export PATH="$HERE/tests/testapp/build:$PATH"
export XDG_RUNTIME_DIR=$(mktemp -d /tmp/kalyna-rt.XXXX)
export HOME=$(mktemp -d /tmp/kalyna-home.XXXX)          # fresh settings every run
# the test app as an installed Linux app, so it shows in the list and can be launched from it
mkdir -p "$HOME/.local/share/applications"
printf '[Desktop Entry]\nType=Application\nName=Test App\nExec=%s\nIcon=utilities-terminal\nStartupWMClass=kalyna-testapp\n' \
  "$HERE/tests/testapp/build/kalyna-testapp" > "$HOME/.local/share/applications/test-app.desktop"
Xvfb :7 -screen 0 1400x1400x24 -nolisten tcp >/dev/null 2>&1 &
XPID=$!
sleep 1
DISPLAY=:7 QT_QPA_PLATFORM=xcb timeout 180 "$HERE/build/kalyna-shell" --nested --demo --size 1280x800 \
    --test "$HERE/tests/TestDriver.qml" --test-out "$OUT" "$@" 2>&1 | grep -v "^qt.qpa.xcb\|propagateSizeHints"
kill $XPID 2>/dev/null
rm -rf "$XDG_RUNTIME_DIR" "$HOME"
ls "$OUT"
