import QtQuick
import QtQuick.Window
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Settings
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Kalyna

// The whole Kalyna screen. It turns itself to match how the panel is mounted (the Steam Deck's
// panel is portrait, used in landscape), so apps and touch are always the right way up.
Item {
    id: shell
    property WaylandCompositor compositor

    // ---------------------------------------------------------------- rotation
    readonly property string rotationName: Shell.forcedRotation !== "" ? Shell.forcedRotation
        : (Prefs.rotation === "auto" ? Shell.defaultRotation : Prefs.rotation)
    readonly property int angle: ({ "cw": 90, "ccw": 270, "180": 180 })[rotationName] || 0
    readonly property bool sideways: angle === 90 || angle === 270

    // one design unit in pixels: fixed on a phone (pixels per Android dp), else grows with the screen
    function unit() {
        return Shell.uiScale > 0 ? Shell.uiScale : Math.max(0.9, Math.min(screenItem.width, screenItem.height) / 760)
    }

    // ---------------------------------------------------------------- state
    property var windows: []          // open app windows (see AppWindow below)
    property var current: null        // window shown on top, or null for home
    property bool homeShown: current === null
    property bool recentsShown: false
    property bool qsShown: false
    property bool locked: Prefs.lockOnStart && !Shell.nested
    property var internalApp: null    // a Kalyna page shown like an app (Settings)
    property string launching: ""
    property var launchingApp: null

    function showHome() {
        if (homeShown && !internalApp && home.drawerOpen) { home.drawerOpen = false; return }
        current = null; internalApp = null; recentsShown = false; qsShown = false; launching = ""
        screenItem.forceActiveFocus(); Qt.inputMethod.hide()
    }
    function focusWindow(w) {
        recentsShown = false; qsShown = false; internalApp = null
        current = w
        if (w && w.item) w.item.takeFocus()
    }

    // ---------------------------------------------------------------- Kalyna's own apps and real apps
    readonly property var proxies: ({
        "kalyna.terminal": ["foot", "org.codeberg.dnkl.foot", "org.kde.konsole", "org.gnome.Console", "kitty", "Alacritty", "org.gnome.Terminal"],
        "kalyna.browser": ["chromium", "org.chromium.Chromium", "firefox", "org.mozilla.firefox", "google-chrome", "brave-browser"],
        "kalyna.files": ["org.kde.dolphin", "org.gnome.Nautilus", "thunar", "pcmanfm-qt", "pcmanfm", "nemo"]
    })
    function realFor(id) {
        const list = proxies[id] || []
        for (const want of list)
            for (const a of System.apps)
                if (a.id === want || a.id.toLowerCase() === want.toLowerCase()) return a
        return null
    }
    readonly property var kalynaApps: {
        const out = [{ id: "kalyna.settings", name: qsTr("Settings"), kind: "kalyna", glyph: "gear", colors: Theme.appColors.settings }]
        const add = (id, name, glyph, colors) => { const r = realFor(id); if (r) out.push({ id: id, name: name, kind: "kalyna", glyph: glyph, colors: colors, real: r.id }) }
        add("kalyna.terminal", qsTr("Terminal"), "term", Theme.appColors.terminal)
        add("kalyna.browser", qsTr("Browser"), "globe", Theme.appColors.browser)
        add("kalyna.files", qsTr("Files"), "folder", Theme.appColors.files)
        out.push({ id: "kalyna.android", name: qsTr("Android"), kind: "kalyna", glyph: "android", colors: Theme.appColors.android })
        out.push({ id: "kalyna.about", name: qsTr("About Kalyna"), kind: "kalyna", glyph: "info", colors: Theme.appColors.about })
        return out
    }
    readonly property var allApps: {
        const hidden = kalynaApps.filter(a => a.real).map(a => a.real)
        return kalynaApps.concat(System.apps.filter(a => hidden.indexOf(a.id) < 0))
    }
    function appById(id) { return allApps.find(a => a.id === id) || null }

    function launch(app) {
        if (!app) return
        recentsShown = false; qsShown = false
        if (app.id === "kalyna.settings" || app.id === "kalyna.about" || app.id === "kalyna.android") {
            internalApp = app; current = null
            screenItem.forceActiveFocus(); Qt.inputMethod.hide()
            return
        }
        const realId = app.real || app.id
        // already open? bring it to the front
        const open = windows.find(w => w.appEntry && (w.appEntry.id === realId))
        if (open) { focusWindow(open); return }
        launching = realId; launchingApp = app
        launchTimeout.restart()
        System.call("apps.launch", { id: realId }, (ok, data, err) => {
            if (!ok || !data.ok) { launching = ""; toast.show(qsTr("Couldn’t open %1").arg(app.name), (data && data.error) || err) }
        })
    }
    Timer { id: launchTimeout; interval: 12000; onTriggered: shell.launching = "" }

    // ---------------------------------------------------------------- windows from the compositor
    Component {
        id: appWindowComponent
        QtObject {
            property var toplevel
            property var xdgSurface
            property var surface: xdgSurface ? xdgSurface.surface : null
            property var item: null
            property string appId: toplevel ? toplevel.appId : ""
            property string title: toplevel ? toplevel.title : ""
            property bool fullscreen: false
            property var appEntry: null
            readonly property string name: appEntry ? appEntry.name : (title || appId || qsTr("App"))
        }
    }

    function matchApp(appId) {
        if (!appId) return null
        const k = appId.toLowerCase()
        return System.apps.find(a => a.id.toLowerCase() === k || (a.wmclass && a.wmclass.toLowerCase() === k)
                                  || a.id.toLowerCase().endsWith("." + k) || a.name.toLowerCase() === k) || null
    }

    function addWindow(toplevel, xdgSurface) {
        const w = appWindowComponent.createObject(shell, { toplevel: toplevel, xdgSurface: xdgSurface })
        w.appEntry = matchApp(toplevel.appId) || (launching ? System.apps.find(a => a.id === launching) : null)
        toplevel.appIdChanged.connect(() => { const m = matchApp(toplevel.appId); if (m) w.appEntry = m })
        toplevel.setFullscreen.connect(() => { w.fullscreen = true; configure(w) })
        toplevel.unsetFullscreen.connect(() => { w.fullscreen = false; configure(w) })
        toplevel.setMaximized.connect(() => configure(w))
        toplevel.unsetMaximized.connect(() => configure(w))
        w.item = surfaceComponent.createObject(appLayer, { win: w })
        windows = windows.concat([w])
        launching = ""
        configure(w)
        focusWindow(w)
    }

    function removeWindow(w) {
        const i = windows.indexOf(w)
        if (i < 0) return
        const rest = windows.slice(); rest.splice(i, 1); windows = rest
        if (current === w) current = rest.length && !homeShown ? rest[rest.length - 1] : null
        if (w.item) w.item.destroy()
        w.destroy()
    }

    function closeWindow(w) {
        if (!w) return
        w.toplevel.sendClose()
        killTimer.target = w
        killTimer.restart()
    }
    Timer {   // an app that ignores "close" for 4 s is stopped
        id: killTimer
        property var target: null
        interval: 4000
        onTriggered: if (target && shell.windows.indexOf(target) >= 0 && target.surface && target.surface.client) target.surface.client.kill(15)
    }

    function configure(w) {
        if (!w || !w.toplevel) return
        if (w.fullscreen) w.toplevel.sendFullscreen(Qt.size(screenItem.width, appArea.height + Theme.topH))
        else w.toplevel.sendMaximized(Qt.size(appArea.width, appArea.height))
    }
    function configureAll() { for (const w of windows) configure(w) }

    Component {
        id: surfaceComponent
        ShellSurfaceItem {
            id: ssi
            property var win
            shellSurface: win ? win.xdgSurface : null
            autoCreatePopupItems: true
            touchEventsEnabled: true
            focusOnClick: true
            x: 0
            y: win && win.fullscreen ? -Theme.topH : 0
            width: appArea.width
            height: win && win.fullscreen ? appArea.height + Theme.topH : appArea.height
            visible: shell.current === win && !shell.internalApp
            onSurfaceDestroyed: shell.removeWindow(win)
        }
    }

    // ---------------------------------------------------------------- the rotated screen
    Item {
        id: screenItem
        width: shell.sideways ? shell.height : shell.width
        height: shell.sideways ? shell.width : shell.height
        anchors.centerIn: parent
        rotation: shell.angle
        readonly property bool portrait: height > width
        onWidthChanged: { Theme.s = shell.unit(); shell.configureAll() }
        onHeightChanged: { Theme.s = shell.unit(); shell.configureAll() }

        // wallpaper + home live in the backdrop that liquid glass refracts
        Item {
            id: backdrop
            anchors.fill: parent
            Wallpaper { id: wallpaper; anchors.fill: parent; portrait: screenItem.portrait }
            // The 1.33.2 phone launcher used a refractive glass plate behind the app list.
            // Keep it below HomeScreen so the clock, app labels, and touch targets remain crisp.
            Glass {
                z: 1
                visible: !home.drawerMode || home.drawerPos > 0
                x: home.x + home.sheetRect.x; y: home.y + home.sheetRect.y
                width: home.sheetRect.width; height: home.sheetRect.height
                radius: Theme.px(24)
                backdrop: wallpaper
                originX: x; originY: y
                tint: Theme.glassTint
                tintAmount: 0.42 - Prefs.glass * 0.30
            }
            HomeScreen {
                id: home
                z: 2
                anchors.fill: parent
                anchors.topMargin: Theme.topH
                shellRef: shell
                visible: shell.homeShown && !shell.internalApp
            }
        }
        // glass and controls that float over the home screen
        HomeOverlay {
            anchors.fill: parent
            anchors.topMargin: Theme.topH
            home: home
            backdrop: backdrop
            shellRef: shell
            visible: home.visible
        }

        // apps: real windows from the compositor
        Item {
            id: appArea
            anchors.fill: parent
            anchors.topMargin: Theme.topH
            anchors.bottomMargin: keyboard.shown ? keyboard.height : 0
            onHeightChanged: shell.configureAll()
            Rectangle { anchors.fill: parent; color: Theme.ground; visible: shell.current !== null && !shell.internalApp }
            Item { id: appLayer; anchors.fill: parent }
        }

        // Kalyna's own pages (Settings, About, Android) shown like apps
        Loader {
            anchors.fill: parent
            anchors.topMargin: Theme.topH
            anchors.bottomMargin: keyboard.shown ? keyboard.height : 0
            active: shell.internalApp !== null
            sourceComponent: SettingsApp {
                shellRef: shell
                page: shell.internalApp ? ({ "kalyna.about": "about", "kalyna.android": "android" })[shell.internalApp.id] || "wifi" : "wifi"
            }
        }

        // opening an app: its icon grows in the middle until the window arrives
        Item {
            anchors.fill: parent
            visible: shell.launching !== ""
            Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }
            AppIcon {
                id: splashIcon
                anchors.centerIn: parent
                size: Theme.px(88)
                app: shell.launchingApp
                SequentialAnimation on scale {
                    running: shell.launching !== ""
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.92; to: 1.04; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.04; to: 0.92; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        Recents {
            z: 4
            anchors.fill: parent
            anchors.topMargin: Theme.topH
            shellRef: shell
            visible: shell.recentsShown
        }

        StatusBar {
            id: statusBar
            z: 5
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: Theme.topH
            shellRef: shell
        }

        // gesture bar: swipe up from the bottom edge for home (and hold for recent apps)
        GestureBar {
            z: 6
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.bottomMargin: keyboard.shown ? keyboard.height : 0
            visible: (shell.current !== null || shell.internalApp !== null) && !shell.locked
            shellRef: shell
        }

        QuickSettings {
            id: qs
            z: 10
            shellRef: shell
            anchors.top: parent.top
            anchors.topMargin: Theme.topH + Theme.px(6)
            x: Prefs.leftHanded ? Theme.px(8) : parent.width - width - Theme.px(8)
            width: Math.min(parent.width - Theme.px(16), Theme.px(400))
            maxHeight: parent.height - Theme.topH - Theme.px(16) - (keyboard.shown ? keyboard.height : 0)
            open: shell.qsShown
        }

        LockScreen {
            z: 20
            anchors.fill: parent
            visible: shell.locked
            onUnlocked: shell.locked = false
        }

        Toast { id: toast; z: 30; anchors.horizontalCenter: parent.horizontalCenter; y: Theme.topH + Theme.px(12) }

        // the on-screen keyboard: English and Ukrainian, types into Kalyna and into apps
        Rectangle {   // keyboard background across the whole width
            z: 39
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: keyboard.visible ? parent.height - keyboard.y : 0
            color: "#161417"
        }
        InputPanel {
            id: keyboard
            z: 40
            readonly property bool shown: active && Prefs.osk !== "off"
                                          && (Prefs.osk === "always" || Shell.touchLast || !Shell.nested)
            width: screenItem.portrait ? parent.width : Math.min(parent.width, Theme.px(980))
            anchors.horizontalCenter: parent.horizontalCenter
            y: shown ? parent.height - height : parent.height
            visible: y < parent.height
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
    }

    // automated tests: --test FILE.qml loads a driver that walks through the shell
    Loader {
        active: Qt.application.arguments.indexOf("--test") >= 0
        source: active ? "file://" + Qt.application.arguments[Qt.application.arguments.indexOf("--test") + 1] : ""
        onLoaded: item.shell = shell
    }

    Component.onCompleted: {
        VirtualKeyboardSettings.activeLocales = ["en_US", "uk_UA"]
        VirtualKeyboardSettings.locale = "en_US"
        if (Shell.screenshotPath !== "") shotTimer.start()
    }
    // tests: --screenshot FILE saves the screen once the shell has settled, then quits
    Timer {
        id: shotTimer
        interval: Number(Qt.application.arguments.indexOf("--shot-delay") >= 0
                         ? Qt.application.arguments[Qt.application.arguments.indexOf("--shot-delay") + 1] : 2500)
        onTriggered: { Shell.grab(shell, Shell.screenshotPath); Shell.quit() }
    }

    // ---------------------------------------------------------------- keys
    Shortcut { sequence: "Meta+Q"; onActivated: shell.closeWindow(shell.current) }
    // hardware keys (Steam Deck volume rocker, laptop brightness keys)
    function nudgeVolume(d) { System.call("volume.set", { percent: Math.max(0, Math.min(100, (System.volume.percent || 0) + d)) }) }
    function nudgeBrightness(d) { System.call("brightness.set", { percent: Math.max(5, Math.min(100, (System.brightness.percent || 0) + d)) }) }
    Shortcut { sequence: "Volume Up"; context: Qt.ApplicationShortcut; autoRepeat: true; onActivated: shell.nudgeVolume(5) }
    Shortcut { sequence: "Volume Down"; context: Qt.ApplicationShortcut; autoRepeat: true; onActivated: shell.nudgeVolume(-5) }
    Shortcut { sequence: "Volume Mute"; context: Qt.ApplicationShortcut; onActivated: System.call("volume.set", { muted: !System.volume.muted }) }
    Shortcut { sequence: "Monitor Brightness Up"; context: Qt.ApplicationShortcut; autoRepeat: true; onActivated: shell.nudgeBrightness(8) }
    Shortcut { sequence: "Monitor Brightness Down"; context: Qt.ApplicationShortcut; autoRepeat: true; onActivated: shell.nudgeBrightness(-8) }
    Shortcut { sequences: ["Meta+Tab", "Alt+Tab"]; onActivated: shell.recentsShown = !shell.recentsShown }
    Shortcut { sequence: "Ctrl+Alt+Home"; onActivated: shell.showHome() }
    // phone: Back (or Escape) closes the app drawer
    Shortcut { sequences: ["Back", "Escape"]; enabled: shell.homeShown && !shell.internalApp && home.drawerOpen; onActivated: home.drawerOpen = false }
    Shortcut { sequence: "Ctrl+Alt+Backspace"; enabled: Shell.nested; onActivated: Shell.quit() }
    Keys.onReleased: e => { if (e.key === Qt.Key_Meta || e.key === Qt.Key_Super_L) shell.showHome() }
}
