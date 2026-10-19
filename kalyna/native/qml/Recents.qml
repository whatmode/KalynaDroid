import QtQuick
import QtWayland.Compositor
import Kalyna

// Recent apps: live previews of every open window. Tap to switch, swipe a card up (or tap ✕) to close.
Rectangle {
    id: rc
    property var shellRef
    color: Theme.light ? Qt.rgba(246 / 255, 241 / 255, 244 / 255, 0.94) : Qt.rgba(0.04, 0.03, 0.05, 0.86)
    readonly property bool portrait: height > width

    MouseArea { anchors.fill: parent; onClicked: rc.shellRef.recentsShown = false }

    Text {
        visible: rc.shellRef.windows.length === 0
        anchors.centerIn: parent
        text: qsTr("No open apps")
        color: Theme.muted; font.pixelSize: Theme.px(18)
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: Theme.px(24)
        anchors.bottomMargin: Theme.px(40)
        orientation: ListView.Horizontal
        spacing: Theme.px(22)
        leftMargin: Math.max(Theme.px(30), (width - contentWidth) / 2)
        rightMargin: Theme.px(30)
        model: rc.shellRef.windows
        clip: false
        delegate: Item {
            id: card
            required property var modelData
            readonly property real ratio: rc.width / Math.max(1, rc.height)
            height: list.height
            width: (height - Theme.px(48)) * ratio * 0.82
            property real lift: 0

            Column {
                y: -card.lift
                opacity: 1 - Math.min(1, card.lift / (card.height * 0.6))
                spacing: Theme.px(10)
                Row {
                    spacing: Theme.px(10)
                    AppIcon { app: card.modelData.appEntry || { kind: "linux", name: card.modelData.name }; size: Theme.px(30) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.modelData.name; color: Theme.fg
                        font.pixelSize: Theme.px(15); font.weight: Font.DemiBold
                        width: card.width - Theme.px(90); elide: Text.ElideRight
                    }
                    Rectangle {
                        width: Theme.px(32); height: width; radius: width / 2
                        color: Theme.controlStrong
                        Glyph { anchors.centerIn: parent; name: "close"; size: Theme.px(16) }
                        MouseArea { id: xma; anchors.fill: parent; onClicked: rc.shellRef.closeWindow(card.modelData) }
                    }
                }
                Rectangle {
                    width: card.width
                    height: card.height - Theme.px(48)
                    radius: Theme.px(18)
                    color: Theme.win
                    clip: true
                    border.color: Theme.border
                    // a second, live view of the app's surface
                    WaylandQuickItem {
                        surface: card.modelData.surface
                        inputEventsEnabled: false
                        width: rc.width; height: rc.height - Theme.topH
                        transformOrigin: Item.TopLeft
                        scale: parent.width / Math.max(1, rc.width)
                        bufferLocked: false
                    }
                    MouseArea {
                        anchors.fill: parent
                        property real sy: 0
                        preventStealing: true
                        onPressed: m => sy = m.y
                        onPositionChanged: m => card.lift = Math.max(0, sy - m.y)
                        onReleased: {
                            if (card.lift > card.height * 0.25) rc.shellRef.closeWindow(card.modelData)
                            else if (card.lift < Theme.px(10)) rc.shellRef.focusWindow(card.modelData)
                            card.lift = 0
                        }
                    }
                }
            }
            Behavior on lift { enabled: card.lift === 0; NumberAnimation { duration: 160 } }
        }
    }

    KButton {
        visible: rc.shellRef.windows.length > 1
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.px(10)
        text: qsTr("Close all")
        onClicked: { for (const w of rc.shellRef.windows.slice()) rc.shellRef.closeWindow(w) }
    }
}
