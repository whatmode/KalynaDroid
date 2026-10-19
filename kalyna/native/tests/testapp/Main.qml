import QtQuick
import QtQuick.Window
Window {
    id: w
    width: 640; height: 400; visible: true
    title: "Test App"
    color: "#2a62d6"
    Column {
        anchors.centerIn: parent
        spacing: 16
        Text { text: "Hello from a real Wayland app"; color: "white"; font.pixelSize: 28 }
        Text { text: "window " + w.width + "×" + w.height; color: "white"; font.pixelSize: 18 }
        Rectangle {
            width: 420; height: 48; radius: 24; color: "white"
            TextInput { id: field; objectName: "field"; anchors.fill: parent; anchors.leftMargin: 18; verticalAlignment: TextInput.AlignVCenter; font.pixelSize: 20; focus: true }
        }
        Text { text: "typed: " + field.text; color: "white"; font.pixelSize: 18 }
    }
    Timer { interval: 1500; running: true; repeat: true; onTriggered: console.log("testapp field=" + field.text + " size=" + w.width + "x" + w.height) }
}
