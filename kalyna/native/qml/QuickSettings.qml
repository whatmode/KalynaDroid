import QtQuick
import Kalyna

// Quick settings: Wi-Fi, Bluetooth, screen rotation and scroll sounds, brightness and volume,
// battery, and power. Opens from the status icons at the top.
Item {
    id: qs
    property var shellRef
    property bool open: false
    property real maxHeight: 600
    property string view: "main"     // main | wifi
    height: Math.min(maxHeight, content.height + Theme.px(28))
    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.96
    transformOrigin: Prefs.leftHanded ? Item.TopLeft : Item.TopRight
    Behavior on opacity { NumberAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    onOpenChanged: if (!open) view = "main"

    // tapping outside closes it
    MouseArea {
        parent: qs.parent
        anchors.fill: parent
        anchors.topMargin: Theme.topH
        enabled: qs.open
        z: qs.z - 0.5
        onClicked: qs.shellRef.qsShown = false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.px(24)
        color: Theme.light ? "#f1ecef" : Qt.rgba(0.09, 0.07, 0.11, 0.94)
        border.color: Theme.border
    }
    MouseArea { anchors.fill: parent }   // swallow taps on the panel itself

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.px(14)
        contentHeight: content.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            width: parent.width
            spacing: Theme.px(10)

            // ---------------------------------------------------- main view
            Grid {
                visible: qs.view === "main"
                width: parent.width
                columns: 2
                spacing: Theme.px(8)
                readonly property real cw: (width - spacing) / 2
                QsTile {
                    width: parent.cw
                    glyph: "wifi"; label: qsTr("Wi-Fi")
                    on: System.wifi.enabled === true
                    sub: System.wifi.available !== true ? qsTr("Not available") : (System.wifi.ssid || (System.wifi.enabled ? qsTr("Not connected") : qsTr("Off")))
                    more: System.wifi.available === true
                    onToggled: System.call("wifi.enable", { on: !(System.wifi.enabled === true) })
                    onOpened: qs.view = "wifi"
                }
                QsTile {
                    width: parent.cw
                    glyph: "bt"; label: qsTr("Bluetooth")
                    on: System.bt.enabled === true
                    sub: System.bt.available !== true ? qsTr("Not available") : (System.bt.enabled ? qsTr("On") : qsTr("Off"))
                    onToggled: if (System.bt.available) System.call("bt.enable", { on: !(System.bt.enabled === true) })
                }
                QsTile {
                    width: parent.cw
                    glyph: "rotate"; label: qsTr("Rotation")
                    sub: ({ "auto": qsTr("Automatic"), "none": qsTr("Normal"), "cw": qsTr("Turned right"), "ccw": qsTr("Turned left"), "180": qsTr("Upside down") })[Prefs.rotation]
                    onToggled: {
                        const order = ["auto", "none", "cw", "ccw", "180"]
                        Prefs.rotation = order[(order.indexOf(Prefs.rotation) + 1) % order.length]
                    }
                }
                QsTile {
                    width: parent.cw
                    glyph: "note"; label: qsTr("Scroll sounds")
                    on: Prefs.scrollSound
                    sub: Prefs.scrollSound ? qsTr("Clap · ball") : qsTr("Off")
                    onToggled: Prefs.scrollSound = !Prefs.scrollSound
                }
            }

            KSlider {
                visible: qs.view === "main"
                width: parent.width
                glyph: "sun"
                enabledSlider: System.brightness.available === true
                value: (System.brightness.percent || 0) / 100
                onMoved: v => brightnessThrottle.want(Math.round(5 + v * 95))
            }
            KSlider {
                visible: qs.view === "main"
                width: parent.width
                glyph: "vol"
                enabledSlider: System.volume.available === true
                value: System.volume.muted ? 0 : (System.volume.percent || 0) / 100
                onMoved: v => volumeThrottle.want(Math.round(v * 100))
            }

            Row {
                visible: qs.view === "main"
                width: parent.width
                spacing: Theme.px(8)
                Rectangle {
                    width: parent.width - powerRow.width - parent.spacing
                    height: Theme.px(46); radius: height / 2
                    color: Theme.control
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.px(10)
                        BatteryIcon { anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: System.battery.present === false ? qsTr("On power") : (System.battery.percent || 0) + "%" + (System.battery.charging ? " · " + qsTr("charging") : "")
                            color: Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.Medium
                        }
                    }
                }
                Row {
                    id: powerRow
                    spacing: Theme.px(8)
                    KButton { glyph: "lock"; width: Theme.px(46); height: Theme.px(46); onClicked: { qs.shellRef.qsShown = false; qs.shellRef.locked = true } }
                    KButton { glyph: "gear"; width: Theme.px(46); height: Theme.px(46); onClicked: qs.shellRef.launch(qs.shellRef.appById("kalyna.settings")) }
                    KButton { glyph: "power"; width: Theme.px(46); height: Theme.px(46); danger: true; onClicked: qs.view = "power" }
                }
            }

            // ---------------------------------------------------- power view
            Column {
                visible: qs.view === "power"
                width: parent.width
                spacing: Theme.px(8)
                Text { text: qsTr("Power"); color: Theme.fg; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; bottomPadding: Theme.px(4) }
                KButton { width: parent.width; glyph: "moonz"; text: qsTr("Sleep"); onClicked: { qs.shellRef.qsShown = false; System.call("power", { action: "suspend" }) } }
                KButton { width: parent.width; glyph: "restart"; text: qsTr("Restart"); onClicked: System.call("power", { action: "restart" }) }
                KButton { width: parent.width; glyph: "power"; text: qsTr("Power off"); danger: true; onClicked: System.call("power", { action: "off" }) }
                KButton { width: parent.width; text: qsTr("Cancel"); onClicked: qs.view = "main" }
            }

            // ---------------------------------------------------- Wi-Fi view
            Row {
                visible: qs.view === "wifi"
                width: parent.width
                spacing: Theme.px(10)
                KButton { glyph: "back"; width: Theme.px(42); onClicked: qs.view = "main" }
                Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Wi-Fi"); color: Theme.fg; font.pixelSize: Theme.px(17); font.weight: Font.DemiBold; width: parent.width - Theme.px(42) - Theme.px(80) }
                KSwitch { anchors.verticalCenter: parent.verticalCenter; checked: System.wifi.enabled === true; onToggled: on => System.call("wifi.enable", { on: on }) }
            }
            Loader {
                active: qs.view === "wifi"
                visible: active
                width: parent.width
                sourceComponent: WifiList { width: content.width; compact: true }
            }
        }
    }

    // apply slider changes at most ~12 times a second
    QtObject {
        id: brightnessThrottle
        property int pending: -1
        function want(v) { pending = v; if (!bt.running) bt.start() }
        property Timer bt: Timer { interval: 80; onTriggered: { System.call("brightness.set", { percent: brightnessThrottle.pending }) } }
    }
    QtObject {
        id: volumeThrottle
        property int pending: -1
        function want(v) { pending = v; if (!vt.running) vt.start() }
        property Timer vt: Timer { interval: 80; onTriggered: { System.call("volume.set", { percent: volumeThrottle.pending }) } }
    }
}
