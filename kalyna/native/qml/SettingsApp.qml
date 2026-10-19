import QtQuick
import Kalyna

// Settings, a native Kalyna page shown like an app. Also serves as "About" and "Android".
Rectangle {
    id: app
    property var shellRef
    property string page: "wifi"
    readonly property bool narrow: width < Theme.px(720)
    property bool showingPage: !narrow
    color: Theme.win

    readonly property var pages: [
        { id: "wifi", name: qsTr("Wi-Fi"), glyph: "wifi" },
        { id: "bt", name: qsTr("Bluetooth"), glyph: "bt" },
        { id: "display", name: qsTr("Display"), glyph: "display" },
        { id: "appearance", name: qsTr("Appearance"), glyph: "palette" },
        { id: "sound", name: qsTr("Sound"), glyph: "vol" },
        { id: "keyboard", name: qsTr("Keyboard"), glyph: "keyboard" },
        { id: "android", name: qsTr("Android"), glyph: "android" },
        { id: "about", name: qsTr("About Kalyna"), glyph: "info" }
    ]
    onPageChanged: if (narrow) showingPage = true

    // ---------------------------------------------------------------- navigation
    Rectangle {
        id: nav
        visible: !app.narrow || !app.showingPage
        width: app.narrow ? parent.width : Theme.px(260)
        height: parent.height
        color: Theme.win2
        Column {
            anchors.fill: parent
            anchors.margins: Theme.px(12)
            spacing: Theme.px(2)
            Text { text: qsTr("Settings"); color: Theme.fg; font.family: Theme.fontDisplay; font.pixelSize: Theme.px(26); font.weight: Font.Bold; padding: Theme.px(8); bottomPadding: Theme.px(14) }
            Repeater {
                model: app.pages
                delegate: Rectangle {
                    required property var modelData
                    width: parent.width; height: Theme.px(48); radius: Theme.px(12)
                    color: app.page === modelData.id && !app.narrow ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                                                   : (pma.pressed ? Theme.controlStrong : "transparent")
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.px(12); spacing: Theme.px(12)
                        Glyph { name: modelData.glyph; size: Theme.px(20); color: Theme.fg }
                        Text { text: modelData.name; color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                    }
                    MouseArea { id: pma; anchors.fill: parent; onClicked: { app.page = modelData.id; app.showingPage = true } }
                }
            }
        }
    }

    // ---------------------------------------------------------------- pages
    Item {
        id: pageArea
        visible: !app.narrow || app.showingPage
        anchors { left: app.narrow ? parent.left : nav.right; right: parent.right; top: parent.top; bottom: parent.bottom }

        Row {
            id: head
            x: Theme.px(24); y: Theme.px(18)
            spacing: Theme.px(10)
            KButton { visible: app.narrow; glyph: "back"; width: Theme.px(42); onClicked: app.showingPage = false }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (app.pages.find(p => p.id === app.page) || {}).name || ""
                color: Theme.fg; font.family: Theme.fontDisplay; font.pixelSize: Theme.px(24); font.weight: Font.Bold
            }
        }
        Flickable {
            anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Theme.px(12) }
            contentHeight: body.height + Theme.px(40)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: body
                x: Theme.px(24)
                width: Math.min(parent.width - Theme.px(48), Theme.px(720))
                sourceComponent: ({ wifi: wifiPage, bt: btPage, display: displayPage, appearance: appearancePage,
                                    sound: soundPage, keyboard: keyboardPage, android: androidPage, about: aboutPage })[app.page]
            }
        }
    }

    // ---------------------------------------------------------------- building blocks
    component Card: Rectangle {
        default property alias content: inner.data
        width: parent ? parent.width : 0
        height: inner.height + Theme.px(28)
        radius: Theme.px(16)
        color: Theme.win2
        border.color: Theme.line
        Column { id: inner; x: Theme.px(16); y: Theme.px(14); width: parent.width - Theme.px(32); spacing: Theme.px(12) }
    }
    component RowSetting: Item {
        property string label
        property string hint
        default property alias control: ctl.data
        width: parent ? parent.width : 0
        height: Math.max(Theme.px(44), txt.height)
        Column {
            id: txt
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - ctl.width - Theme.px(16)
            Text { text: label; color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium; width: parent.width; wrapMode: Text.WordWrap }
            Text { text: hint; visible: hint !== ""; color: Theme.muted; font.pixelSize: Theme.px(12.5); width: parent.width; wrapMode: Text.WordWrap }
        }
        Item { id: ctl; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }
    component Segmented: Row {
        property var options: []     // [{value, label}]
        property var value
        signal picked(var v)
        spacing: Theme.px(6)
        Repeater {
            model: parent.options
            delegate: Rectangle {
                required property var modelData
                height: Theme.px(38); width: lbl.width + Theme.px(26); radius: height / 2
                color: parent.value === modelData.value ? Theme.accent : Theme.control
                Text { id: lbl; anchors.centerIn: parent; text: modelData.label; color: parent.parent.value === modelData.value ? "white" : Theme.fg; font.pixelSize: Theme.px(13.5); font.weight: Font.Medium }
                MouseArea { anchors.fill: parent; onClicked: parent.parent.picked(modelData.value) }
            }
        }
    }

    Component {
        id: wifiPage
        Column {
            spacing: Theme.px(14)
            Card {
                RowSetting {
                    label: qsTr("Wi-Fi"); hint: System.wifi.ssid ? qsTr("Connected to %1").arg(System.wifi.ssid) : ""
                    KSwitch { checked: System.wifi.enabled === true; onToggled: on => System.call("wifi.enable", { on: on }) }
                }
            }
            Card { WifiList { width: parent.width } }
            Text { text: qsTr("Tip: press and hold a saved network to forget it."); color: Theme.muted; font.pixelSize: Theme.px(13) }
        }
    }
    Component {
        id: btPage
        Column {
            spacing: Theme.px(14)
            Card {
                RowSetting {
                    label: qsTr("Bluetooth")
                    hint: System.bt.available === true ? "" : qsTr("No Bluetooth adapter found.")
                    KSwitch { checked: System.bt.enabled === true; enabled: System.bt.available === true; onToggled: on => System.call("bt.enable", { on: on }) }
                }
            }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Theme.px(13)
                   text: qsTr("Pairing headphones and controllers from Kalyna comes in a later version. For now, pair from the Terminal with bluetoothctl.") }
        }
    }
    Component {
        id: displayPage
        Column {
            spacing: Theme.px(14)
            Card {
                Text { text: qsTr("Brightness"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                KSlider { width: parent.width; glyph: "sun"; enabledSlider: System.brightness.available === true
                          value: (System.brightness.percent || 0) / 100; onMoved: v => System.call("brightness.set", { percent: Math.round(5 + v * 95) }) }
            }
            Card {
                visible: Shell.forcedRotation === ""
                Text { text: qsTr("Screen rotation"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                Segmented {
                    value: Prefs.rotation
                    options: [{ value: "auto", label: qsTr("Automatic") }, { value: "none", label: qsTr("Normal") },
                              { value: "cw", label: qsTr("Right") }, { value: "ccw", label: qsTr("Left") }, { value: "180", label: "180°" }]
                    onPicked: v => Prefs.rotation = v
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Theme.px(12.5)
                       text: qsTr("Automatic turns the Steam Deck's screen to landscape. Apps and touch turn with it.") }
            }
            Card {
                RowSetting { label: qsTr("24-hour clock"); KSwitch { checked: Prefs.clock24; onToggled: on => Prefs.clock24 = on } }
                RowSetting { label: qsTr("Lock screen at start"); hint: qsTr("Swipe up to open; no password yet")
                             KSwitch { checked: Prefs.lockOnStart; onToggled: on => Prefs.lockOnStart = on } }
            }
        }
    }
    Component {
        id: appearancePage
        Column {
            spacing: Theme.px(14)
            Card {
                Text { text: qsTr("Theme"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                Segmented {
                    value: Prefs.mode
                    options: [{ value: "dark", label: qsTr("Dark") }, { value: "light", label: qsTr("Light") }]
                    onPicked: v => Prefs.mode = v
                }
            }
            Card {
                Text { text: qsTr("Accent color"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                Flow {
                    width: parent.width
                    spacing: Theme.px(8)
                    Repeater {
                        model: Theme.accentOptions
                        delegate: Rectangle {
                            required property var modelData
                            width: Theme.px(112); height: Theme.px(42); radius: Theme.px(12)
                            color: Theme.win
                            border.width: Prefs.accent === modelData.id ? Theme.px(2) : Theme.px(1)
                            border.color: Prefs.accent === modelData.id ? modelData.color : Theme.border
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                x: Theme.px(10); spacing: Theme.px(8)
                                Rectangle { width: Theme.px(18); height: width; radius: width / 2; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.name; color: Theme.fg; font.pixelSize: Theme.px(13); anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { anchors.fill: parent; onClicked: Prefs.accent = modelData.id }
                        }
                    }
                }
            }
            Card {
                Text { text: qsTr("Wallpaper"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                Flow {
                    width: parent.width; spacing: Theme.px(10)
                    Repeater {
                        model: ["dusk", "kalyna", "steppe", "aurora", "graphite"]
                        delegate: Rectangle {
                            required property string modelData
                            width: Theme.px(132); height: Theme.px(84); radius: Theme.px(12); clip: true
                            color: "black"
                            border.width: Prefs.wallpaper === modelData ? Theme.px(3) : 1
                            border.color: Prefs.wallpaper === modelData ? Theme.accent : Theme.line
                            Image { anchors.fill: parent; anchors.margins: parent.border.width; source: Shell.asset("wallpapers/" + modelData + "-1280x800.jpg"); fillMode: Image.PreserveAspectCrop; sourceSize.width: 280; asynchronous: true }
                            MouseArea { anchors.fill: parent; onClicked: Prefs.wallpaper = modelData }
                        }
                    }
                }
            }
            Card {
                Text { text: qsTr("Liquid glass"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                KSlider { width: parent.width; glyph: "eye"; value: Prefs.glass; onMoved: v => Prefs.glass = Math.round(v * 100) / 100 }
                Text { text: qsTr("Frosted ← → Clear"); color: Theme.muted; font.pixelSize: Theme.px(12.5) }
            }
            Card {
                RowSetting { label: qsTr("Left-handed layout"); hint: qsTr("Puts the status icons, quick settings and dock on the left")
                             KSwitch { checked: Prefs.leftHanded; onToggled: on => Prefs.leftHanded = on } }
            }
        }
    }
    Component {
        id: soundPage
        Column {
            spacing: Theme.px(14)
            Card {
                Text { text: qsTr("Volume"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                KSlider { width: parent.width; glyph: "vol"; enabledSlider: System.volume.available === true
                          value: System.volume.muted ? 0 : (System.volume.percent || 0) / 100; onMoved: v => System.call("volume.set", { percent: Math.round(v * 100) }) }
            }
            Card {
                RowSetting { label: qsTr("Scroll sounds"); hint: qsTr("A hand clap at the top of the app list, a bouncing ball at the bottom")
                             KSwitch { checked: Prefs.scrollSound; onToggled: on => Prefs.scrollSound = on } }
                Text { text: qsTr("Scroll sound volume"); color: Theme.fg; font.pixelSize: Theme.px(14); visible: Prefs.scrollSound }
                KSlider { width: parent.width; glyph: "note"; visible: Prefs.scrollSound; value: Prefs.scrollVolume / 100; onMoved: v => Prefs.scrollVolume = Math.round(v * 100) }
                Row {
                    spacing: Theme.px(8); visible: Prefs.scrollSound
                    KButton { text: qsTr("Play top"); glyph: "playi"; onClicked: System.call("sound.play", { name: "edge-top", volume: Prefs.scrollVolume / 100 }) }
                    KButton { text: qsTr("Play bottom"); glyph: "playi"; onClicked: System.call("sound.play", { name: "edge-bottom", volume: Prefs.scrollVolume / 100 }) }
                }
            }
        }
    }
    Component {
        id: keyboardPage
        Column {
            spacing: Theme.px(14)
            Card {
                Text { text: qsTr("On-screen keyboard"); color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                Segmented {
                    value: Prefs.osk
                    options: [{ value: "auto", label: qsTr("After touch") }, { value: "always", label: qsTr("Always") }, { value: "off", label: qsTr("Off") }]
                    onPicked: v => Prefs.osk = v
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: Theme.muted; font.pixelSize: Theme.px(12.5)
                       text: qsTr("English and Ukrainian. Switch with the globe key. With a hardware keyboard, Alt+Shift switches layouts.") }
            }
        }
    }
    Component {
        id: androidPage
        Column {
            id: ap
            spacing: Theme.px(14)
            property var st: ({})
            function refresh() { System.call("android.state", {}, (ok, d) => { if (ok) ap.st = d }) }
            Component.onCompleted: refresh()
            Timer { interval: 3000; running: true; repeat: true; onTriggered: ap.refresh() }
            Card {
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: Theme.fg; font.pixelSize: Theme.px(15)
                    text: !ap.st.installed ? qsTr("Android (Waydroid) is not part of this system.")
                          : !ap.st.initialized ? qsTr("Android is installed but not set up yet. Open Terminal and run: sudo kalyna-android-setup")
                          : ap.st.running ? qsTr("Android is running. Your Android apps are in the app list.")
                          : qsTr("Android is ready. Start it to use Android apps (it starts by itself when you open one).")
                }
                Row {
                    spacing: Theme.px(8)
                    visible: ap.st.installed === true && ap.st.initialized === true
                    KButton { text: ap.st.running ? qsTr("Show Android") : qsTr("Start Android"); primary: true
                              onClicked: { if (ap.st.running) System.call("apps.run", { cmd: "waydroid show-full-ui" }); else System.call("android.start") } }
                    KButton { visible: ap.st.running === true; text: qsTr("Stop"); onClicked: System.call("android.stop", {}, () => ap.refresh()) }
                }
            }
        }
    }
    Component {
        id: aboutPage
        Column {
            spacing: Theme.px(14)
            Card {
                Row {
                    spacing: Theme.px(16)
                    Image { source: Shell.asset("logo.svg"); width: Theme.px(64); height: width; sourceSize: Qt.size(128, 128) }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Kalyna OS"; color: Theme.fg; font.family: Theme.fontDisplay; font.pixelSize: Theme.px(28); font.weight: Font.Bold }
                        Text { text: qsTr("Version %1 · native edition").arg(Shell.version); color: Theme.muted; font.pixelSize: Theme.px(14) }
                    }
                }
            }
            Card {
                Repeater {
                    model: [
                        [qsTr("Device"), System.info.model || "—"],
                        [qsTr("Processor"), (System.info.cpu || "—") + (System.info.cores ? " · " + System.info.cores + qsTr(" cores") : "")],
                        [qsTr("Memory"), System.info.memTotalMB ? (System.info.memTotalMB / 1024).toFixed(1) + " GB" : "—"],
                        [qsTr("Linux"), System.info.kernel || "—"],
                        [qsTr("Base system"), System.info.base || "—"],
                        [qsTr("Shell"), "Qt " + "6 · C++ / QML · Wayland"]
                    ]
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        Text { width: Theme.px(150); text: modelData[0]; color: Theme.muted; font.pixelSize: Theme.px(14) }
                        Text { width: parent.width - Theme.px(150); text: modelData[1]; color: Theme.fg; font.pixelSize: Theme.px(14); wrapMode: Text.WordWrap }
                    }
                }
            }
            Text { text: qsTr("Fonts: Kalyna Text, Kalyna Display, and JetBrains Mono (SIL Open Font License)."); color: Theme.muted; font.pixelSize: Theme.px(12) }
        }
    }
}
