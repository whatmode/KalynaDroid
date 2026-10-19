import QtQuick
import Kalyna

// A thick touch slider with an icon inside, like the web edition's quick settings.
Item {
    id: s
    property real value: 0.5          // 0..1
    property string glyph
    property bool enabledSlider: true
    signal moved(real v)
    height: Theme.px(46)
    opacity: enabledSlider ? 1 : 0.4

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.controlStrong
        clip: true
        Rectangle {
            width: Math.max(track.height, track.width * s.value)
            height: parent.height
            radius: track.radius
            color: Theme.accent
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.px(14)
            name: s.glyph; size: Theme.px(20)
            color: Theme.fg
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: s.enabledSlider
        preventStealing: true
        function set(mx) { const v = Math.max(0, Math.min(1, mx / width)); s.value = v; s.moved(v) }
        onPressed: m => set(m.x)
        onPositionChanged: m => set(m.x)
    }
}
