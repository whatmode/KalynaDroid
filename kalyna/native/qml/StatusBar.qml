import QtQuick
import Kalyna

// Top bar: the Kalyna logo (home), the open app's name, the clock, and the status icons that
// open quick settings. Left-handed layout puts the status icons on the left.
Rectangle {
    id: bar
    property var shellRef
    color: shellRef.homeShown && !shellRef.internalApp
           ? (Theme.light ? Qt.rgba(250 / 255, 246 / 255, 249 / 255, 0.58) : Qt.rgba(0.07, 0.05, 0.08, 0.35))
           : Theme.panel
    Behavior on color { ColorAnimation { duration: 160 } }
    readonly property bool flip: Prefs.leftHanded
    property date now: new Date()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.line }

    // ---- logo + app name
    Row {
        id: leftSide
        anchors.verticalCenter: parent.verticalCenter
        x: bar.flip ? parent.width - width - Theme.px(6) : Theme.px(6)
        layoutDirection: bar.flip ? Qt.RightToLeft : Qt.LeftToRight
        spacing: Theme.px(4)
        Rectangle {
            width: Theme.px(40); height: Theme.px(28); radius: height / 2
            color: logoMa.pressed || bar.shellRef.recentsShown ? Theme.controlStrong : "transparent"
            Image { anchors.centerIn: parent; source: Shell.asset("logo.svg"); sourceSize: Qt.size(Theme.px(44), Theme.px(44)); width: Theme.px(22); height: width }
            MouseArea {
                id: logoMa
                anchors.fill: parent
                // tap: home (tap again on home: recent apps)
                onClicked: {
                    if (bar.shellRef.homeShown && !bar.shellRef.internalApp && bar.shellRef.windows.length) bar.shellRef.recentsShown = !bar.shellRef.recentsShown
                    else bar.shellRef.showHome()
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bar.shellRef.internalApp ? bar.shellRef.internalApp.name : (bar.shellRef.current ? bar.shellRef.current.name : "")
            color: Theme.panelFg; opacity: 0.8
            font.pixelSize: Theme.px(14); font.weight: Font.Medium
            elide: Text.ElideRight
            width: Math.min(implicitWidth, bar.width * 0.3)
        }
    }

    // ---- clock
    Text {
        anchors.centerIn: parent
        text: Qt.formatTime(bar.now, Prefs.clock24 ? "HH:mm" : "h:mm AP")
        color: Theme.panelFg
        font.family: Theme.fontDisplay
        font.pixelSize: Theme.px(15); font.weight: Font.DemiBold
        visible: !bar.shellRef.homeShown || bar.shellRef.internalApp !== null
    }

    // ---- status icons -> quick settings
    Rectangle {
        id: status
        anchors.verticalCenter: parent.verticalCenter
        x: bar.flip ? Theme.px(6) : parent.width - width - Theme.px(6)
        width: statusRow.width + Theme.px(20)
        height: Theme.px(28); radius: height / 2
        color: stMa.pressed || bar.shellRef.qsShown ? Theme.controlStrong : "transparent"
        Row {
            id: statusRow
            anchors.centerIn: parent
            spacing: Theme.px(10)
            Glyph {
                name: "wifi"; size: Theme.px(18); anchors.verticalCenter: parent.verticalCenter
                visible: System.wifi.available === true
                opacity: System.wifi.ssid ? 1 : 0.4
            }
            Glyph { name: "bt"; size: Theme.px(17); anchors.verticalCenter: parent.verticalCenter; visible: System.bt.enabled === true }
            Glyph {
                name: "vol"; size: Theme.px(18); anchors.verticalCenter: parent.verticalCenter
                visible: System.volume.available === true
                opacity: System.volume.muted ? 0.4 : 1
            }
            BatteryIcon { anchors.verticalCenter: parent.verticalCenter; visible: System.battery.present === true }
        }
        MouseArea { id: stMa; anchors.fill: parent; onClicked: bar.shellRef.qsShown = !bar.shellRef.qsShown }
    }
}
