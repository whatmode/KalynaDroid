import QtQuick
import Kalyna

// Liquid glass panel. Put it as a sibling *above* `backdrop` (same parent coordinates), give it a
// size and a radius; whatever is under it in `backdrop` is refracted through it. The level comes
// from Settings → Appearance (frosted ... clear). Without a GPU it falls back to a frosted panel.
Item {
    id: glass
    property Item backdrop
    property real radius: height / 2
    property real level: Prefs.glass           // 0 frosted .. 1 clear
    property color tint: Theme.glassTint
    property real tintAmount: 0.30 - level * 0.22
    property real originX: x                     // position in backdrop coordinates
    property real originY: y
    property bool live: true
    readonly property int pad: Math.ceil(Theme.px(28))
    readonly property bool gpu: GraphicsInfo.api !== GraphicsInfo.Software

    ShaderEffectSource {
        id: src
        visible: false
        sourceItem: glass.backdrop
        live: glass.live && glass.visible
        recursive: false
        sourceRect: Qt.rect(glass.originX - glass.pad, glass.originY - glass.pad,
                            glass.width + 2 * glass.pad, glass.height + 2 * glass.pad)
    }

    ShaderEffect {
        anchors.fill: parent
        visible: glass.gpu && !!glass.backdrop
        property variant src: src
        property size itemSize: Qt.size(width, height)
        property size srcSize: Qt.size(width + 2 * glass.pad, height + 2 * glass.pad)
        property real pad: glass.pad
        property real radius: glass.radius
        property real refraction: Theme.px(10 + 16 * glass.level)
        property real blur: Theme.px(2 + 14 * (1 - glass.level))
        property real chroma: 0.06 + 0.12 * glass.level
        property real rim: 1.0
        property real tintAmt: Math.max(0, glass.tintAmount)
        property color tint: glass.tint
        fragmentShader: "qrc:/qt/qml/Kalyna/shaders/glass.frag.qsb"
    }

    // software fallback and the hairline that keeps the edge readable on bright wallpapers
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: glass.gpu ? "transparent" : (Theme.light ? Qt.rgba(1, 1, 1, 0.82) : Qt.rgba(0.08, 0.06, 0.1, 0.78))
        border.width: 1
        border.color: Theme.light ? Qt.rgba(0, 0, 0, glass.gpu ? 0.08 : 0.12) : Qt.rgba(1, 1, 1, glass.gpu ? 0.10 : 0.14)
    }
}
