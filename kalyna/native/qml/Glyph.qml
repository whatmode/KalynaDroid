import QtQuick
import Kalyna

// One of Kalyna's stroke icons (assets/glyphs) in any colour.
Image {
    id: g
    property string name
    property color color: Theme.fg
    property int size: Theme.px(22)
    width: size
    height: size
    source: name ? Shell.glyph(name, color.toString()) : ""
    sourceSize: Qt.size(size * 2, size * 2)
    smooth: true
    mipmap: true
}
