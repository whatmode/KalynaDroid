import QtQuick
import Kalyna

// The phone layout (Kalyna on Android) walked through for screenshots. Run with
//   KALYNA_PHONE=1 KALYNA_SCALE=1.6 KALYNA_ROTATE=none \
//   kalyna-shell --nested --demo --size 720x1602 --test tests/PhoneDriver.qml --test-out DIR
Item {
    id: drv
    property var shell
    property string out: Qt.application.arguments.indexOf("--test-out") >= 0
        ? Qt.application.arguments[Qt.application.arguments.indexOf("--test-out") + 1] : "/tmp/kalyna-phone"
    property int step: 0
    property var steps: [
        [2500, "home", () => {}],
        [900, "drawer", () => { home().drawerOpen = true }],
        [700, "drawer-search", () => { findSearch().text = "se" }],
        [700, "drawer-closed", () => { findSearch().text = ""; home().drawerOpen = false }],
        [700, "quick-settings", () => { shell.qsShown = true }],
        [900, "settings", () => { shell.qsShown = false; shell.launch(shell.appById("kalyna.settings")) }],
        [600, "done", () => { shell.showHome() }]
    ]

    function walk(item, pred) {
        if (!item) return null
        if (pred(item)) return item
        for (let i = 0; i < item.children.length; ++i) {
            const r = walk(item.children[i], pred)
            if (r) return r
        }
        return null
    }
    function home() { return walk(shell, it => it.drawerMode !== undefined && it.drawerOpen !== undefined) }
    function findSearch() { return walk(shell, it => it.inputMethodHints !== undefined && it.echoMode === TextInput.Normal) }

    Timer {
        id: t
        interval: 300
        running: true
        onTriggered: {
            if (drv.step > 0) {
                const name = drv.steps[drv.step - 1][1]
                const ok = Shell.grab(drv.shell, drv.out + "/" + String(drv.step).padStart(2, "0") + "-" + name + ".png")
                console.log("phone test:", drv.step, name, ok ? "saved" : "NOT SAVED", "scale=" + Theme.s)
            }
            if (drv.step >= drv.steps.length) { Shell.quit(); return }
            const s = drv.steps[drv.step]
            drv.step++
            try { s[2]() } catch (e) { console.log("phone test: step error", s[1], e) }
            t.interval = s[0]
            t.start()
        }
    }
}
