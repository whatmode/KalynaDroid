import QtQuick
import Kalyna

// Battery drawn as an icon that fills with the charge level (red when low, a bolt when charging).
Item {
    id: b
    property int percent: System.battery.percent || 0
    property bool charging: System.battery.charging === true
    width: Theme.px(28); height: Theme.px(14)
    Rectangle {
        id: body
        width: parent.width - Theme.px(3); height: parent.height
        radius: Theme.px(3.5)
        color: "transparent"
        border.color: Theme.panelFg; border.width: Theme.px(1.4)
        opacity: 0.9
        Rectangle {
            x: Theme.px(2.5); y: Theme.px(2.5)
            height: parent.height - Theme.px(5)
            width: Math.max(Theme.px(2), (parent.width - Theme.px(5)) * Math.min(100, b.percent) / 100)
            radius: Theme.px(1.5)
            color: b.charging ? Theme.ok : (b.percent <= 15 ? Theme.bad : Theme.panelFg)
        }
    }
    Rectangle {
        anchors.left: body.right; anchors.leftMargin: Theme.px(1)
        anchors.verticalCenter: body.verticalCenter
        width: Theme.px(2); height: Theme.px(5); radius: 1
        color: Theme.panelFg; opacity: 0.9
    }
    Glyph { anchors.centerIn: body; name: "charge"; size: Theme.px(12); color: "#111111"; visible: b.charging }
}
