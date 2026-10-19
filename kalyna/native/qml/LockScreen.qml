import QtQuick
import Kalyna

// Lock screen: time and date over the wallpaper; swipe up (or press any key) to open Kalyna.
Item {
    id: lock
    signal unlocked()
    property real drag: 0
    focus: visible

    Wallpaper { anchors.fill: parent; portrait: lock.height > lock.width }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.28) }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 - lock.drag * 0.5
        opacity: 1 - lock.drag / (lock.height * 0.4)
        spacing: Theme.px(6)
        property date now: new Date()
        Timer { interval: 1000; running: lock.visible; repeat: true; onTriggered: parent.now = new Date() }
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: Shell.asset("logo.svg"); width: Theme.px(44); height: width; sourceSize: Qt.size(96, 96)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(parent.now, Prefs.clock24 ? "HH:mm" : "h:mm")
            color: "white"; font.family: Theme.fontDisplay; font.weight: Font.Bold; font.pixelSize: Theme.px(110)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: parent.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: "white"; font.pixelSize: Theme.px(22); font.weight: Font.Medium
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(28) + lock.drag
        spacing: Theme.px(10)
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            name: "back"; rotation: 90; size: Theme.px(26)
            transform: Translate {
                SequentialAnimation on y {
                    running: lock.visible; loops: Animation.Infinite
                    NumberAnimation { from: 0; to: -Theme.px(8); duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -Theme.px(8); to: 0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }
        Text { text: qsTr("Swipe up to open"); color: "white"; font.pixelSize: Theme.px(16); opacity: 0.9 }
    }

    MouseArea {
        anchors.fill: parent
        property real sy: 0
        onPressed: m => sy = m.y
        onPositionChanged: m => lock.drag = Math.max(0, sy - m.y)
        onReleased: { if (lock.drag > lock.height * 0.18) lock.unlocked(); lock.drag = 0 }
        onClicked: if (!Shell.touchLast) lock.unlocked()   // a mouse or trackpad click opens directly
    }
    Keys.onPressed: lock.unlocked()
    Behavior on drag { enabled: lock.drag === 0; NumberAnimation { duration: 200 } }
}
