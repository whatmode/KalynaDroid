import QtQuick
import Kalyna

// An app in the home list: icon and name; tap to open.
Item {
    id: t
    property var app
    signal activated()
    height: Theme.px(108)

    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.px(3)
        radius: Theme.px(14)
        color: Qt.rgba(1, 1, 1, ma.pressed ? 0.16 : (ma.containsMouse ? 0.08 : 0))
        Behavior on color { ColorAnimation { duration: 90 } }
    }
    Column {
        anchors.centerIn: parent
        spacing: Theme.px(7)
        scale: ma.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        AppIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            app: t.app
            size: Theme.px(54)
        }
        Text {
            width: t.width - Theme.px(8)
            horizontalAlignment: Text.AlignHCenter
            text: t.app ? t.app.name : ""
            color: Theme.homeFg
            font.pixelSize: Theme.px(13)
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            style: Text.Outline; styleColor: Theme.homeShadow
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: t.activated()
    }
}
