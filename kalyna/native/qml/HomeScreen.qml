import QtQuick
import Kalyna

// Home: the clock and the list of all apps over the wallpaper. This part is inside the liquid
// glass backdrop; the glass search bar and dock sit on top of it (HomeOverlay).
Item {
    id: home
    property var shellRef
    property string query: ""
    readonly property bool portrait: height > width
    readonly property bool lefty: Prefs.leftHanded

    // ---------------------------------------------------------------- phone: home screen + app drawer
    // On a phone (Kalyna on Android) home shows the clock and the dock; all apps live in a drawer
    // that slides up (swipe up on home, or the apps button in the dock) and slides away again.
    readonly property bool drawerMode: Shell.phone && portrait
    property bool drawerOpen: false
    property real drawerPos: drawerMode ? (drawerOpen ? 1 : 0) : 1
    Behavior on drawerPos { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    onDrawerModeChanged: drawerOpen = false
    onVisibleChanged: if (!visible) drawerOpen = false
    onDrawerOpenChanged: if (drawerOpen) Qt.callLater(scrollToStart)

    // geometry shared with the overlay
    readonly property rect sheetRect: drawerMode
        ? Qt.rect(Theme.px(8), Theme.px(8) + (height - Theme.px(8)) * (1 - drawerPos), width - Theme.px(16), height - Theme.px(16))
        : portrait
        ? Qt.rect(Theme.px(12), clock.y + clock.height + Theme.px(14), width - Theme.px(24),
                  height - (clock.y + clock.height + Theme.px(14)) - Theme.px(96))
        : Qt.rect(lefty ? Theme.px(14) : width * 0.42, Theme.px(14), width * 0.58 - Theme.px(28), height - Theme.px(28))
    readonly property int barH: Theme.px(50)

    // ---------------------------------------------------------------- clock
    // swipe up anywhere on the home screen opens the drawer
    MouseArea {
        anchors.fill: parent
        enabled: home.drawerMode && !home.drawerOpen
        property real startY: 0
        onPressed: m => startY = m.y
        onPositionChanged: m => { if (startY - m.y > Theme.px(40)) home.drawerOpen = true }
    }

    Column {
        id: clock
        opacity: home.drawerMode ? 1 - home.drawerPos : 1
        visible: opacity > 0
        x: home.portrait ? (home.width - width) / 2 : (home.lefty ? home.width * 0.62 + Theme.px(30) : Theme.px(36))
        y: home.portrait ? Theme.px(26) : Theme.px(40)
        spacing: Theme.px(2)
        property date now: new Date()
        Timer { interval: 1000; running: home.visible; repeat: true; onTriggered: clock.now = new Date() }
        Text {
            anchors.horizontalCenter: home.portrait ? parent.horizontalCenter : undefined
            text: Qt.formatTime(clock.now, Prefs.clock24 ? "HH:mm" : "h:mm")
            color: Theme.homeFg
            font.family: Theme.fontDisplay
            font.weight: Font.Bold
            font.pixelSize: Theme.px(home.portrait ? 76 : 92)
            style: Text.Outline; styleColor: Theme.homeShadow
        }
        Text {
            anchors.horizontalCenter: home.portrait ? parent.horizontalCenter : undefined
            text: clock.now.toLocaleDateString(Qt.locale(), "dddd, d MMMM")
            color: Theme.homeFg
            font.pixelSize: Theme.px(20)
            font.weight: Font.Medium
            leftPadding: Theme.px(4)
        }
        Item { width: 1; height: Theme.px(18); visible: !home.portrait }
        // a few facts at a glance (landscape)
        Column {
            visible: !home.portrait
            spacing: Theme.px(8)
            leftPadding: Theme.px(4)
            Row {
                spacing: Theme.px(10)
                Glyph { name: System.wifi.ssid ? "wifi" : "wifi"; size: Theme.px(20); opacity: System.wifi.ssid ? 1 : 0.5 }
                Text {
                    text: System.wifi.ssid ? System.wifi.ssid : (System.wifi.available ? qsTr("Wi-Fi: not connected") : qsTr("No Wi-Fi"))
                    color: Theme.homeFg; font.pixelSize: Theme.px(16); opacity: 0.9
                }
            }
            Row {
                spacing: Theme.px(10)
                Glyph { name: System.battery.charging ? "charge" : "bat"; size: Theme.px(20) }
                Text {
                    text: System.battery.present === false ? qsTr("Plugged in")
                          : qsTr("%1% battery%2").arg(System.battery.percent || 0).arg(System.battery.charging ? qsTr(", charging") : "")
                    color: Theme.homeFg; font.pixelSize: Theme.px(16); opacity: 0.9
                }
            }
        }
    }

    // ---------------------------------------------------------------- all apps
    readonly property var results: {
        const q = query.trim().toLowerCase()
        const apps = shellRef ? shellRef.allApps : []
        if (!q) return apps
        return apps.filter(a => a.name.toLowerCase().indexOf(q) >= 0 || (a.comment || "").toLowerCase().indexOf(q) >= 0
                               || a.id.toLowerCase().indexOf(q) >= 0)
                   .sort((a, b) => (a.name.toLowerCase().startsWith(q) ? 0 : 1) - (b.name.toLowerCase().startsWith(q) ? 0 : 1))
    }
    readonly property var sections: {
        if (query.trim()) return [{ title: "", apps: results }]
        const own = results.filter(a => a.kind === "kalyna"), lin = results.filter(a => a.kind === "linux"),
              and = results.filter(a => a.kind === "android")
        const s = [{ title: qsTr("Kalyna"), apps: own }]
        if (lin.length) s.push({ title: qsTr("Linux apps"), apps: lin })
        if (and.length) s.push({ title: qsTr("Android"), apps: and })
        return s
    }

    Item {
        id: sheet
        x: home.sheetRect.x; y: home.sheetRect.y; width: home.sheetRect.width; height: home.sheetRect.height
        clip: true
        visible: !home.drawerMode || home.drawerPos > 0

        // the drawer's handle: tap or pull down to close it
        Item {
            id: handle
            visible: home.drawerMode
            z: 2
            width: parent.width; height: Theme.px(34)
            Rectangle {
                anchors.centerIn: parent
                width: Theme.px(44); height: Theme.px(5); radius: height / 2
                color: Theme.homeFg; opacity: 0.6
            }
            MouseArea {
                anchors.fill: parent
                property real startY: 0
                onPressed: m => startY = m.y
                onPositionChanged: m => { if (m.y - startY > Theme.px(30)) home.drawerOpen = false }
                onClicked: home.drawerOpen = false
            }
        }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.topMargin: home.drawerMode ? handle.height : 0
            anchors.bottomMargin: home.barH + Theme.px(10)
            contentWidth: width
            contentHeight: Math.max(height + 1, col.height)
            boundsBehavior: Flickable.DragAndOvershootBounds
            flickDeceleration: 2600
            // search results sit just above the search bar
            contentY: 0
            property bool wasMoving: false
            property real speed: 0
            onVerticalVelocityChanged: speed = Math.max(speed * 0.8, Math.abs(verticalVelocity))
            onMovementStarted: speed = 0
            onAtYBeginningChanged: if (atYBeginning && moving) home.edge("top")
            // pulling down past the top of the drawer closes it
            onVerticalOvershootChanged: if (home.drawerMode && verticalOvershoot < -Theme.px(70)) home.drawerOpen = false
            onAtYEndChanged: if (atYEnd && moving) home.edge("bottom")

            Column {
                id: col
                width: flick.width
                y: home.drawerMode ? 0 : Math.max(0, flick.height - height)       // short lists hug the search bar
                spacing: Theme.px(4)
                Repeater {
                    model: home.sections
                    delegate: Column {
                        required property var modelData
                        width: col.width
                        spacing: Theme.px(2)
                        Text {
                            visible: modelData.title !== "" && modelData.apps.length > 0
                            text: modelData.title.toUpperCase()
                            color: Theme.homeFg; opacity: 0.8
                            font.pixelSize: Theme.px(12); font.weight: Font.DemiBold; font.letterSpacing: Theme.px(1)
                            leftPadding: Theme.px(10); topPadding: Theme.px(10); bottomPadding: Theme.px(4)
                            style: Text.Outline; styleColor: Theme.homeShadow
                        }
                        Flow {
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: modelData.apps
                                delegate: AppTile {
                                    required property var modelData
                                    app: modelData
                                    width: Math.floor(col.width / Math.max(3, Math.floor(col.width / Theme.px(104))))
                                    onActivated: home.shellRef.launch(modelData)
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: home.results.length === 0
                    width: col.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("No apps match “%1”.\nPress Enter to run it as a command.").arg(home.query)
                    color: Theme.homeFg; opacity: 0.85; padding: Theme.px(20)
                    font.pixelSize: Theme.px(15)
                }
            }
        }
    }

    // ---------------------------------------------------------------- scroll sounds at the ends of the list
    function edge(which) {
        if (!Prefs.scrollSound || flick.contentHeight <= flick.height + 2) return
        // softer the faster you fling, so quick scrolling is never noisy
        const k = Math.max(0.35, Math.min(1, 1.15 - flick.speed / 5000))
        System.call("sound.play", { name: which === "top" ? "edge-top" : "edge-bottom", volume: Prefs.scrollVolume / 100 * k })
    }
    function scrollToEnd() { if (drawerMode) scrollToStart(); else flick.contentY = Math.max(0, flick.contentHeight - flick.height) }
    function scrollToStart() { flick.contentY = 0 }
    onQueryChanged: Qt.callLater(scrollToEnd)
    Component.onCompleted: Qt.callLater(scrollToEnd)
    property alias flick: flick
}
