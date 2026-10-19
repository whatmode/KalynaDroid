pragma Singleton
import QtQuick
import QtCore

// Kalyna settings, kept in ~/.config/Kalyna/Kalyna.conf
Settings {
    category: "shell"
    property string wallpaper: "dusk"
    property string mode: "dark"             // dark | light, matching the Kalyna 1.33.2 appearance setting
    property string accent: "kalyna"          // kalyna | amber | teal | violet | moss
    property real glass: 0.7             // liquid glass: 0 frosted ... 1 clear
    property bool leftHanded: false      // buttons on the left for one-handed use
    property bool scrollSound: true      // clap at the top of the app list, ball at the bottom
    property int scrollVolume: 60
    property string rotation: "auto"     // auto | none | cw | ccw | 180
    property bool lockOnStart: true
    property bool clock24: true
    property string osk: "auto"          // on-screen keyboard: auto (after touch) | always | off
    property string pinned: '["kalyna.settings","kalyna.terminal","kalyna.browser"]'
    property bool firstRunDone: false
}
