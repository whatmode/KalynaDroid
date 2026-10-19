import QtQuick
import QtQuick.VirtualKeyboard
import Kalyna

// Automated walk through the shell for testing: runs steps one after another, saving a
// screenshot after each. Started with:  kalyna-shell --nested --demo --test tests/TestDriver.qml
// Screenshots go to $KALYNA_TEST_OUT (default /tmp/kalyna-test).
Item {
    id: drv
    property var shell
    property string out: Qt.application.arguments.indexOf("--test-out") >= 0
        ? Qt.application.arguments[Qt.application.arguments.indexOf("--test-out") + 1] : "/tmp/kalyna-test"
    property int step: 0
    property var steps: [
        [1500, "home", () => {}],
        [700, "quick-settings", () => { shell.qsShown = true }],
        [900, "wifi-list", () => { findTile("Wi-Fi").opened() }],
        [600, "power", () => { shell.qsShown = false; shell.qsShown = true; Qt.callLater(() => findQs().view = "power") }],
        [600, "search", () => { shell.qsShown = false; findSearch().forceActiveFocus(); findSearch().text = "set" }],
        [900, "settings-wifi", () => { Prefs.osk = "auto"; findSearch().text = ""; shell.launch(shell.appById("kalyna.settings")) }],
        [700, "settings-appearance", () => { findSettings().page = "appearance" }],
        [700, "settings-sound", () => { findSettings().page = "sound" }],
        [700, "settings-about", () => { findSettings().page = "about" }],
        [700, "glass-clear", () => { shell.showHome(); Prefs.glass = 1.0 }],
        [700, "glass-frosted", () => { Prefs.glass = 0.0 }],
        [700, "left-handed", () => { Prefs.glass = 0.7; Prefs.leftHanded = true; Prefs.wallpaper = "kalyna" }],
        [3500, "app-window", () => { Prefs.leftHanded = false; Prefs.wallpaper = "dusk"; System.call("apps.run", { cmd: drv.testApp() }) }],
        [1500, "app-keyboard", () => { tapCenterOfApp() }],
        [1200, "app-typed", () => { typeText("Kalyna") }],
        [900, "app-typed-uk", () => { InputContext.inputEngine.virtualKeyClick(Qt.Key_Space, " ", 0); typeText("ok") }],
        [900, "recents", () => { Prefs.osk = "auto"; shell.recentsShown = true }],
        [900, "portrait", () => { shell.recentsShown = false; Prefs.rotation = "cw" }],
        [900, "portrait-home", () => { shell.showHome() }],
        [1200, "close-app", () => { Prefs.rotation = "auto"; shell.closeWindow(shell.windows[0]) }],
        [3500, "launch-from-list", () => { console.log("test: windows after close", shell.windows.length); shell.launch(shell.appById("test-app")) }],
        [900, "lock", () => { console.log("test: launched entry", shell.current ? shell.current.name : "none"); shell.locked = true }],
        [600, "done", () => { shell.locked = false }]
    ]

    function testApp() {
        const i = Qt.application.arguments.indexOf("--test-app")
        return i >= 0 ? Qt.application.arguments[i + 1] : "kalyna-testapp"
    }
    function walk(item, pred) {
        if (!item) return null
        if (pred(item)) return item
        for (let i = 0; i < item.children.length; ++i) {
            const r = walk(item.children[i], pred)
            if (r) return r
        }
        return null
    }
    function root() { return shell }
    function findTile(label) { return walk(root(), it => it.label === label && it.toggled !== undefined) }
    function findQs() { return walk(root(), it => it.view !== undefined && it.maxHeight !== undefined) }
    function findSearch() { return walk(root(), it => it.inputMethodHints !== undefined && it.echoMode === TextInput.Normal && it.font && it.font.pixelSize === Theme.px(17)) }
    function findSettings() { return walk(root(), it => it.pages !== undefined && it.page !== undefined) }
    function tapCenterOfApp() {
        const w = shell.current
        Prefs.osk = "always"
        if (w && w.item) Shell.click(w.item, w.item.width / 2, w.item.height / 2 + 22)
        // a touch on the text field of the test app (center of the window, a bit below)
        console.log("test: app window", w ? w.name : "none", w && w.item ? w.item.width + "x" + w.item.height : "")
    }
    function typeText(s) {
        for (const ch of s) InputContext.inputEngine.virtualKeyClick(ch.toUpperCase().charCodeAt(0), ch, 0)
    }

    Timer {
        id: t
        interval: 300
        running: true
        onTriggered: {
            if (drv.step > 0) {
                const name = drv.steps[drv.step - 1][1]
                const ok = Shell.grab(drv.shell, drv.out + "/" + String(drv.step).padStart(2, "0") + "-" + name + ".png")
                console.log("test: step", drv.step, name, ok ? "saved" : "NOT SAVED",
                            "windows=" + drv.shell.windows.length, "keyboard=" + Qt.inputMethod.visible)
            }
            if (drv.step >= drv.steps.length) { Shell.quit(); return }
            const s = drv.steps[drv.step]
            drv.step++
            try { s[2]() } catch (e) { console.log("test: step error", s[1], e) }
            t.interval = s[0]
            t.start()
        }
    }
}
