import QtQuick
import Kalyna

// Floating controls over the home screen, made of liquid glass: the search bar at the bottom of
// the app list (apps bend through it as you scroll) and the dock with pinned apps.
Item {
    id: ov
    property var home
    property Item backdrop
    property var shellRef
    readonly property bool portrait: height > width

    // ---------------------------------------------------------------- search bar
    Glass {
        id: bar
        visible: !ov.home.drawerMode || ov.home.drawerPos > 0
        backdrop: ov.backdrop
        x: ov.home.sheetRect.x + Theme.px(4)
        y: ov.home.sheetRect.y + ov.home.sheetRect.height - ov.home.barH - Theme.px(2)
        width: ov.home.sheetRect.width - Theme.px(8)
        height: ov.home.barH
        originX: x
        originY: y + Theme.topH
        tint: Theme.glassTint
        tintAmount: 0.5 - Prefs.glass * 0.3            // light glass with dark text, as in the web edition

        Rectangle {   // the soft highlight of the web edition's bar (top-left)
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.28) }
                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        Rectangle {   // accent ring, like the web search bar
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: Theme.px(1.5)
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, input.activeFocus ? 0.95 : 0.6)
        }
        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.px(18)
            anchors.rightMargin: Theme.px(6)
            spacing: Theme.px(10)
            Glyph { name: "search"; size: Theme.px(20); color: "#1a1420"; anchors.verticalCenter: parent.verticalCenter; opacity: 0.8 }
            Item {
                width: parent.width - Theme.px(80)
                height: parent.height
                TextInput {
                    id: input
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    color: "#1a1420"
                    selectionColor: Theme.accent
                    font.pixelSize: Theme.px(17)
                    clip: true
                    onTextChanged: ov.home.query = text
                    inputMethodHints: Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: ov.runFirst()
                    Keys.onEnterPressed: ov.runFirst()
                    Keys.onEscapePressed: { text = ""; focus = false }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: qsTr("Search apps")
                    color: "#1a1420"; opacity: 0.6
                    font.pixelSize: Theme.px(17)
                }
                MouseArea { anchors.fill: parent; enabled: !input.activeFocus; onClicked: input.forceActiveFocus() }
            }
            Item {
                width: Theme.px(40); height: Theme.px(40)
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text !== ""
                Glyph { anchors.centerIn: parent; name: "close"; size: Theme.px(18); color: "#1a1420" }
                MouseArea { anchors.fill: parent; onClicked: { input.text = ""; input.forceActiveFocus() } }
            }
        }
    }
    function runFirst() {
        const r = ov.home.results
        if (r.length) { ov.shellRef.launch(r[0]); input.text = ""; input.focus = false }
        else if (input.text.trim()) { System.call("apps.run", { cmd: input.text.trim() }); input.text = ""; input.focus = false }
    }
    onVisibleChanged: if (!visible) { input.text = ""; input.focus = false }
    Connections {   // leaving home clears the search
        target: ov.shellRef
        function onHomeShownChanged() { if (!ov.shellRef.homeShown) { input.text = ""; input.focus = false } }
    }

    // ---------------------------------------------------------------- dock
    readonly property var pinned: {
        let ids = []
        try { ids = JSON.parse(Prefs.pinned) } catch (e) { ids = [] }
        return ids.map(id => ov.shellRef.appById(id)).filter(a => a)
    }
    Glass {
        id: dock
        backdrop: ov.backdrop
        readonly property int cell: Theme.px(64)
        width: dockRow.width + Theme.px(20)
        height: Theme.px(78)
        x: ov.portrait ? (ov.width - width) / 2
                       : (Prefs.leftHanded ? ov.width - width - Theme.px(36) : Theme.px(36))
        y: ov.height - height - Theme.px(14)
        originX: x
        originY: y + Theme.topH
        radius: Theme.px(26)
        opacity: ov.home.drawerMode ? 1 - ov.home.drawerPos : 1
        visible: opacity > 0 && (ov.portrait || ov.home.sheetRect.x > width || Prefs.leftHanded)

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: Theme.px(6)
            Repeater {
                model: ov.pinned
                delegate: Item {
                    required property var modelData
                    width: dock.cell; height: dock.cell
                    AppIcon { anchors.centerIn: parent; app: modelData; size: Theme.px(54); scale: dma.pressed ? 0.9 : 1 }
                    MouseArea { id: dma; anchors.fill: parent; onClicked: ov.shellRef.launch(modelData) }
                    // dot under apps that are open
                    Rectangle {
                        width: Theme.px(5); height: width; radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: -Theme.px(3)
                        color: Theme.accent
                        visible: ov.shellRef.windows.some(w => w.appEntry && (w.appEntry.id === (modelData.real || modelData.id)))
                    }
                }
            }
            Rectangle { width: 1; height: dock.cell * 0.6; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.25); visible: ov.shellRef.windows.length > 0 }
            Item {   // phone: all apps (opens the drawer)
                width: dock.cell; height: dock.cell
                visible: ov.home.drawerMode
                Rectangle {
                    anchors.centerIn: parent; width: Theme.px(54); height: width; radius: width * 0.26
                    color: Qt.rgba(1, 1, 1, 0.16); border.color: Qt.rgba(1, 1, 1, 0.2)
                    scale: ama.pressed ? 0.9 : 1
                    Glyph { anchors.centerIn: parent; name: "grid"; size: Theme.px(26) }
                }
                MouseArea { id: ama; anchors.fill: parent; onClicked: ov.home.drawerOpen = true }
            }
            Item {   // recent apps
                width: dock.cell; height: dock.cell
                visible: ov.shellRef.windows.length > 0
                Rectangle {
                    anchors.centerIn: parent; width: Theme.px(54); height: width; radius: width * 0.26
                    color: Qt.rgba(1, 1, 1, 0.16); border.color: Qt.rgba(1, 1, 1, 0.2)
                    Glyph { anchors.centerIn: parent; name: "recent"; size: Theme.px(26) }
                    Text {
                        anchors { right: parent.right; top: parent.top; margins: Theme.px(3) }
                        text: ov.shellRef.windows.length; color: Theme.panelFg; font.pixelSize: Theme.px(11); font.weight: Font.Bold
                    }
                }
                MouseArea { anchors.fill: parent; onClicked: ov.shellRef.recentsShown = true }
            }
        }
    }
}
