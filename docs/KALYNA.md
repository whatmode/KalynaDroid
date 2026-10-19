# KalynaDroid: Kalyna OS on Android

KalynaDroid is DroidDeck with its own user interface replaced by **Kalyna OS**. The app keeps
DroidDeck's Linux layer: the Arch Linux ARM runtime under proot, the app's Wayland compositor that
draws to the Android screen, audio, input and the GPU drivers. Kalyna's native shell
(`kalyna/native`, C++/Qt 6) runs full-screen on top of it as the desktop.

```
Android app (ua.volodymyr.kalynadroid)
  KalynaActivity ─▶ SessionActivity (desktop mode) ─▶ SessionService
     │                       │                          │ proot: Arch Linux ARM runtime
     │                       │ waylandcomp (wayland-0)  │   kalyna-desktop
     │                       ▼                          │     kalyna-shell --nested  (Qt 6 compositor, wayland-1)
     │                 Android screen                   │       kalyna-system.py  (system service)
     │                                                  │       Linux apps (Firefox, foot, mpv…) on wayland-1
     └── HostBridge ◀── kalyna-request-*.json ──────────┘
                    ──▶ kalyna-host.json (battery, Wi-Fi, volume, brightness, Bluetooth, Android apps)
```

## Pieces

| Piece | Where | What it does |
|---|---|---|
| Kalyna shell | `kalyna/native` | Qt 6 Wayland compositor and the whole UI; `--nested` runs it inside the app's compositor |
| Kalyna package | `tools/desktop-kalyna` | `build-shell.sh` compiles the shell in a signature-checked Arch Linux ARM chroot (arm64 runner); `build.sh` adds the Qt 6 runtime, Python and apps (closure of `seeds.txt`) and `overlay/` |
| Package release | `.github/workflows/build-desktop-kalyna.yml` | builds on every change to `kalyna/` or `tools/desktop-kalyna/` and publishes `desktop-kalyna-rN`; `tools/desktop-kalyna/release.env` pins the one the app installs |
| Session | `tools/desktop-kalyna/overlay/usr/local/bin/kalyna-desktop` | started by DroidDeck's desktop mode (`tools/linuxfs/desktop/droiddeck-desktop` hands over to it) |
| Entry point | `app/src/main/java/ua/volodymyr/kalyna/KalynaActivity.kt` | the launcher icon: opens the session straight away; first start installs the runtime and the Kalyna package |
| Android bridge | `ua/volodymyr/kalyna/HostBridge.kt` + the "Android host" part of `kalyna-system.py` | phone state into Kalyna, Kalyna's requests into Android |
| APK | `.github/workflows/build.yml` | every push to `main` publishes `kalynadroid-rN` with `KalynaOS-rN.apk` |

## Android apps

The phone's own apps appear in Kalyna's app list (kind `android`, with their icons). Opening one
starts it in Android, over Kalyna; Back or Recents returns to Kalyna. Waydroid can't run inside proot
(no binder), so this is how Kalyna runs Android apps on a phone.

## GPU

`KALYNA_GPU=zink` (or `BL_KALYNA_GPU`) makes the shell draw through Zink on the phone's Vulkan
driver: Turnip on Adreno, PanVK (kbase) on Mali via the `mali-gl` work. The default is Mesa's
llvmpipe on the CPU until Zink is verified on each GPU. Games and emulators keep DroidDeck's
`droiddeck-gpu` path (gamescope + Zink).

## Phases

1. **Done** – Kalyna package and session; the app opens straight into Kalyna.
2. **Done** – Android bridge: battery, Wi-Fi, volume, brightness, Bluetooth, Android apps.
3. Remove DroidDeck's own UI and features: Steam/Proton/FEX, stores (Epic, GOG, Amazon, EA),
   XR/VR/glasses/hand tracking, frame generation, the library and settings screens; keep the
   runtime installer, session, compositor, audio, input and GPU drivers.
4. GPU rendering for the shell: Zink on Turnip/PanVK, then on by default where it works.
5. Kalyna settings for the phone: on-screen keyboard, rotation, scaling, storage and logs.
