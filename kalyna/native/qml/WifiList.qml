import QtQuick
import Kalyna

// Wi-Fi networks: tap one to connect (asks for the password when needed), long-press a saved
// network to forget it. Used in quick settings and in Settings.
Column {
    id: wl
    property bool compact: false
    property string asking: ""          // network waiting for a password
    property string busy: ""
    property string error: ""
    property string password: ""
    spacing: Theme.px(4)

    function scan() { System.call("wifi.state", { scan: true }) }
    Component.onCompleted: scan()

    function connectTo(n) {
        error = ""
        if (n.secure && !n.known && asking !== n.ssid) { password = ""; asking = n.ssid; return }
        busy = n.ssid
        System.call("wifi.connect", { ssid: n.ssid, password: asking === n.ssid ? password : "" }, (ok, data, err) => {
            busy = ""
            if (ok && data.ok) { asking = ""; System.call("wifi.state") }
            else error = (data && data.error) || err || qsTr("Couldn’t connect")
        })
    }

    Text {
        visible: System.wifi.available !== true
        text: System.wifi.error || qsTr("No wireless interface is visible to Linux. Check the Wi-Fi driver and firmware.")
        color: Theme.muted; font.pixelSize: Theme.px(14); padding: Theme.px(8)
    }
    Text {
        visible: System.wifi.available === true && System.wifi.enabled === false && !System.wifi.error
        text: qsTr("Wi-Fi is off.")
        color: Theme.muted; font.pixelSize: Theme.px(14); padding: Theme.px(8)
    }
    Text {
        visible: System.wifi.available === true && !!System.wifi.error
        text: System.wifi.error || ""
        color: Theme.muted; font.pixelSize: Theme.px(13); wrapMode: Text.WordWrap; width: wl.width; padding: Theme.px(8)
    }
    Repeater {
        model: System.wifi.enabled && !System.wifi.error ? (System.wifi.networks || []) : []
        delegate: Column {
            required property var modelData
            width: wl.width
            spacing: Theme.px(6)
            Rectangle {
                width: parent.width
                height: Theme.px(52)
                radius: Theme.px(14)
                color: modelData.ssid === System.wifi.ssid ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.24)
                                                          : Qt.rgba(1, 1, 1, nma.pressed ? 0.14 : 0.06)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: Theme.px(14)
                    spacing: Theme.px(12)
                    Item {
                        width: Theme.px(22); height: width
                        anchors.verticalCenter: parent.verticalCenter
                        Glyph { anchors.fill: parent; name: "wifi"; size: parent.width; opacity: 0.25 }
                        Glyph {   // signal strength: the icon fills from the bottom
                            anchors.fill: parent; name: "wifi"; size: parent.width
                            layer.enabled: true
                            visible: true
                            opacity: modelData.signal > 66 ? 1 : (modelData.signal > 33 ? 0.75 : 0.5)
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: modelData.ssid; color: Theme.fg; font.pixelSize: Theme.px(15); font.weight: Font.Medium }
                        Text {
                            text: modelData.ssid === System.wifi.ssid ? qsTr("Connected") + (System.wifi.ip ? " · " + System.wifi.ip : "")
                                  : (wl.busy === modelData.ssid ? qsTr("Connecting…") : (modelData.known ? qsTr("Saved") : (modelData.secure ? qsTr("Secured") : qsTr("Open"))))
                            color: Theme.muted; font.pixelSize: Theme.px(12)
                        }
                    }
                }
                Glyph { visible: modelData.secure; anchors { right: parent.right; rightMargin: Theme.px(14); verticalCenter: parent.verticalCenter } name: "secure"; size: Theme.px(16); opacity: 0.6 }
                MouseArea {
                    id: nma
                    anchors.fill: parent
                    onClicked: if (modelData.ssid !== System.wifi.ssid) wl.connectTo(modelData)
                    onPressAndHold: if (modelData.known) System.call("wifi.forget", { ssid: modelData.ssid }, () => System.call("wifi.state"))
                }
            }
            // password, right under the network
            Rectangle {
                visible: wl.asking === modelData.ssid
                width: parent.width; height: Theme.px(50); radius: height / 2
                color: Theme.control; border.color: Theme.accent; border.width: 1
                TextInput {
                    id: pw
                    anchors { left: parent.left; right: joinBtn.left; verticalCenter: parent.verticalCenter; leftMargin: Theme.px(16); rightMargin: Theme.px(8) }
                    color: Theme.fg; font.pixelSize: Theme.px(15)
                    echoMode: TextInput.Password
                    passwordMaskDelay: 600
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    Keys.onReturnPressed: wl.connectTo(modelData)
                    onTextChanged: wl.password = text
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                    Text { visible: pw.text === ""; text: qsTr("Password for %1").arg(modelData.ssid); color: Theme.muted; font.pixelSize: Theme.px(15) }
                }
                KButton { id: joinBtn; anchors { right: parent.right; rightMargin: Theme.px(4); verticalCenter: parent.verticalCenter } text: qsTr("Join"); primary: true; height: Theme.px(40); onClicked: wl.connectTo(modelData) }
            }
        }
    }
    Text {
        visible: wl.error !== ""
        text: wl.error; color: Theme.bad; font.pixelSize: Theme.px(13); wrapMode: Text.WordWrap; width: wl.width; padding: Theme.px(6)
    }
}
