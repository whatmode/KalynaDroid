# Kalyna OS 2 — native edition

Kalyna's shell rewritten as a native program: **C++ and Qt 6 (Qt Quick)** for everything you see,
**Python** for the system services. It is a real Wayland compositor, so it *is* the desktop: it draws
straight to the screen (KMS, no X11, no browser) and Linux and Android apps open as real windows inside it.

```
kalyna-shell (C++ / QML)                    kalyna-system (Python)
  Wayland compositor (QtWaylandCompositor)    Wi-Fi (NetworkManager), Bluetooth
  lock screen, home, app list + search  <-->  volume (PipeWire), brightness, battery
  dock, status bar, quick settings     JSON   power, apps (.desktop), Android (Waydroid)
  recent apps, Settings, keyboard      lines  sounds
  liquid glass (GPU shader)            over a Unix socket
```

## Layout
* `src/` — C++: start-up, the connection to the system service, helpers
* `qml/` — the shell: `Main.qml` (compositor), `ShellUI.qml` (screen, rotation, windows), home,
  quick settings, settings, recents, lock screen, controls
* `shaders/glass.frag` — liquid glass: lens refraction at the rim, blur, colour split, rim light
* `system/kalyna-system.py` — the system service (demo data when a tool is missing, or `--demo`)
* `assets/` — fonts (Inter, JetBrains Mono), icons, logo, wallpapers, sounds, made from the web
  edition by `tools/make-assets.py` so both editions look and sound the same
* `tests/` — `TestDriver.qml` walks through the shell taking screenshots; `testapp/` is a tiny
  Wayland app used to test windows and the keyboard

## Build
Needs Qt 6.5+ with: Quick, WaylandCompositor, ShaderTools, Svg, VirtualKeyboard.
```
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```
On Arch / CachyOS: `pacman -S cmake ninja qt6-base qt6-declarative qt6-wayland qt6-shadertools qt6-svg qt6-virtualkeyboard`.

## Run
* As the session (Steam Deck, PC): from a text console, `kalyna-shell` (KMS/eglfs, libinput).
* For development, in a window on another desktop: `kalyna-shell --nested --demo --size 1280x800`.
  Apps started from it (or with `WAYLAND_DISPLAY=wayland-kalyna-test`) open inside.

Options: `--rotate none|cw|ccw|180`, `--screenshot FILE`, `--test tests/TestDriver.qml --test-out DIR`.

## Keys and gestures
* Swipe up from the bottom edge: home; swipe up and hold: recent apps. Tap the Kalyna logo: home.
* Status icons (top right, or left in left-handed mode): quick settings.
* Super: home · Super+Q: close app · Alt+Tab: recent apps · Alt+Shift: keyboard layout.
