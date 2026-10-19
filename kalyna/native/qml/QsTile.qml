import QtQuick
import Kalyna

// A quick-settings tile: tap toggles; the chevron (if any) opens more.
Rectangle {
    id: t
    property string glyph
    property string label
    property string sub
    property bool on: false
    property bool more: false
    signal toggled()
    signal opened()
    height: Theme.px(64)
    radius: Theme.px(18)
    color: on ? Theme.accent : (ma.pressed ? Theme.controlStrong : Theme.control)
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.px(14)
        spacing: Theme.px(10)
        width: parent.width - x - (t.more ? Theme.px(40) : Theme.px(10))
        Glyph { name: t.glyph; size: Theme.px(22); anchors.verticalCenter: parent.verticalCenter }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.px(32)
            Text { text: t.label; color: on ? "white" : Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
            Text { text: t.sub; color: on ? "white" : Theme.muted; opacity: 0.9; font.pixelSize: Theme.px(12); elide: Text.ElideRight; width: parent.width; visible: text !== "" }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: t.toggled() }
    Item {
        visible: t.more
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: Theme.px(40)
        Rectangle { anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 1; height: parent.height * 0.5; color: Theme.line }
        Glyph { anchors.centerIn: parent; name: "chev"; size: Theme.px(18) }
        MouseArea { anchors.fill: parent; onClicked: t.opened() }
    }
}
