import QtQuick
import Kalyna

// A short message at the top of the screen.
Rectangle {
    id: t
    property string title
    property string body
    function show(ti, bo) { title = ti; body = bo || ""; opacity = 1; hide.restart() }
    width: Math.min(Theme.px(520), Math.max(tt.implicitWidth, tb.implicitWidth) + Theme.px(40))
    height: col.height + Theme.px(24)
    radius: Theme.px(18)
    color: Theme.light ? "#fbf8fa" : Qt.rgba(0.09, 0.07, 0.11, 0.95)
    border.color: Theme.border
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Timer { id: hide; interval: 4200; onTriggered: t.opacity = 0 }
    Column {
        id: col
        anchors.centerIn: parent
        width: t.width - Theme.px(40)
        Text { id: tt; text: t.title; color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.DemiBold; wrapMode: Text.WordWrap; width: parent.width }
        Text { id: tb; text: t.body; color: Theme.muted; font.pixelSize: Theme.px(13); wrapMode: Text.WordWrap; width: parent.width; visible: text !== "" }
    }
    MouseArea { anchors.fill: parent; onClicked: t.opacity = 0 }
}
