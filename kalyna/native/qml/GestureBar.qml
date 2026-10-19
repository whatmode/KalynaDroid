import QtQuick
import Kalyna

// The handle at the bottom while an app is open: swipe up to go home, swipe up and pause (or
// swipe far) for recent apps. A tap also goes home, for the trackpad.
Item {
    id: g
    property var shellRef
    height: Theme.px(22)

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.px(6) + Math.min(Theme.px(40), drag.distance / 3)
        width: Theme.px(132); height: Theme.px(5); radius: height / 2
        color: "white"
        opacity: drag.active ? 0.95 : 0.55
        border.color: Qt.rgba(0, 0, 0, 0.35); border.width: 1
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -Theme.px(8)
        property real startY: 0
        property real distance: 0
        property double t0: 0
        property bool active: pressed
        preventStealing: true
        onPressed: m => { startY = m.y; distance = 0; t0 = Date.now() }
        onPositionChanged: m => distance = Math.max(0, startY - m.y)
        onReleased: {
            const held = Date.now() - t0
            if (distance > Theme.px(220) || (distance > Theme.px(60) && held > 450)) g.shellRef.recentsShown = true
            else g.shellRef.showHome()
            distance = 0
        }
    }
}
