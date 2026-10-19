import QtQuick
import Kalyna

// On/off switch.
Item {
    id: sw
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: Theme.px(50); implicitHeight: Theme.px(30)
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.accent : Theme.controlStrong
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: parent.height - Theme.px(6); height: width; radius: width / 2
            y: Theme.px(3)
            x: sw.checked ? parent.width - width - Theme.px(3) : Theme.px(3)
            color: "white"
            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -Theme.px(6); onClicked: { sw.checked = !sw.checked; sw.toggled(sw.checked) } }
}
