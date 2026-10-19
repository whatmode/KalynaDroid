import QtQuick
import Kalyna

// The painted wallpapers of the web edition (rendered to images when Kalyna is built).
Item {
    id: wp
    property bool portrait: false
    property string key: Prefs.wallpaper
    clip: true

    Rectangle {   // shown until the image is decoded, and if it is missing
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#1b1430" }
            GradientStop { position: 0.45; color: "#5a2a4a" }
            GradientStop { position: 0.72; color: "#c8553d" }
            GradientStop { position: 1; color: "#f0a35e" }
        }
    }
    Image {
        anchors.fill: parent
        source: Shell.asset("wallpapers/" + wp.key + (wp.portrait ? "-800x1280.jpg" : "-1280x800.jpg"))
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
    }
}
