import QtQuick
import Kalyna

// A rounded button with an optional glyph.
Rectangle {
    id: b
    property string text
    property string glyph
    property bool primary: false
    property bool danger: false
    signal clicked()
    implicitWidth: row.width + Theme.px(28)
    implicitHeight: Theme.px(42)
    radius: height / 2
    color: primary ? Theme.accent : (danger ? Qt.rgba(239 / 255, 107 / 255, 95 / 255, ma.pressed ? 0.35 : 0.22)
                                            : (ma.pressed ? Theme.controlStrong : Theme.control))
    opacity: enabled ? 1 : 0.45
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.px(8)
        Glyph { visible: b.glyph !== ""; name: b.glyph; color: b.primary || b.danger ? "white" : Theme.fg; size: Theme.px(18); anchors.verticalCenter: parent.verticalCenter }
        Text { text: b.text; color: b.primary || b.danger ? "white" : Theme.fg; font.pixelSize: Theme.px(14); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter; visible: text !== "" }
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: b.clicked() }
}
