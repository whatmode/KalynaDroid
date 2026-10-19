import QtQuick
import Kalyna

// An app tile: Kalyna's own apps get the gradient square with a glyph (as in the web edition);
// Linux and Android apps show their own icon on a soft plate.
Item {
    id: ic
    property var app          // {id, name, kind, icon, glyph, colors}
    property int size: Theme.px(52)
    implicitWidth: size
    implicitHeight: size

    readonly property bool own: app && app.kind === "kalyna"
    readonly property var cols: own && app.colors ? app.colors : Theme.appColors.linux

    Rectangle {
        anchors.fill: parent
        radius: ic.size * 0.26
        visible: ic.own || !img.visible
        gradient: Gradient {
            GradientStop { position: 0; color: ic.cols[0] }
            GradientStop { position: 1; color: ic.cols[1] }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        Glyph {
            anchors.centerIn: parent
            size: ic.size * 0.54
            name: ic.own ? ic.app.glyph : (ic.app && ic.app.kind === "android" ? "android" : "desktop")
            visible: ic.own || !img.visible
        }
        // a letter when a Linux app has no icon at all
        Text {
            visible: !ic.own && !img.visible && false
            anchors.centerIn: parent
            text: ic.app ? ic.app.name.charAt(0) : ""
            color: "white"
            font.pixelSize: ic.size * 0.45
            font.weight: Font.DemiBold
        }
    }
    Image {
        id: img
        anchors.fill: parent
        anchors.margins: ic.size * 0.02
        visible: !ic.own && status === Image.Ready
        source: !ic.own && ic.app && ic.app.icon ? Shell.fileUrl(ic.app.icon) : ""
        sourceSize: Qt.size(ic.size * 2, ic.size * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }
}
