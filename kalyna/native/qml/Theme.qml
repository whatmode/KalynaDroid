pragma Singleton
import QtQuick

// Visual system ported from the Kalyna 1.33.2 web UI: dark/light palettes, five accent colors,
// the same display/UI/mono fonts, and the same app tile colors.
QtObject {
    readonly property bool light: Prefs.mode === "light"
    readonly property var accentOptions: [
        { id: "kalyna", name: qsTr("Kalyna"), color: "#d6453d" },
        { id: "amber", name: qsTr("Amber"), color: "#dd9324" },
        { id: "teal", name: qsTr("Teal"), color: "#1f9e94" },
        { id: "violet", name: qsTr("Violet"), color: "#8a6cf0" },
        { id: "moss", name: qsTr("Moss"), color: "#5f9e48" }
    ]
    readonly property color accent: ({ kalyna: "#d6453d", amber: "#dd9324", teal: "#1f9e94",
                                       violet: "#8a6cf0", moss: "#5f9e48" })[Prefs.accent] || "#d6453d"
    readonly property color ground: light ? "#f6f1f4" : "#120f14"
    readonly property color panel: light ? Qt.rgba(250 / 255, 246 / 255, 249 / 255, 0.92)
                                         : Qt.rgba(18 / 255, 14 / 255, 20 / 255, 0.78)
    readonly property color panelFg: light ? "#1f1a21" : "#efe9f1"
    readonly property color line: light ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(1, 1, 1, 0.08)
    readonly property color win: light ? "#fbf8fa" : "#1c181f"
    readonly property color win2: light ? "#f1ecef" : "#242027"
    readonly property color win3: light ? "#e6dfe4" : "#302a34"
    readonly property color border: light ? "#d8cfd5" : "#3b3440"
    readonly property color fg: light ? "#211b23" : "#ece6ef"
    readonly property color muted: light ? "#6c6270" : "#a59cab"
    readonly property color homeFg: light ? "#1a1420" : "#ffffff"
    readonly property color homeShadow: light ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0, 0, 0, 0.35)
    readonly property color control: light ? Qt.rgba(31 / 255, 26 / 255, 33 / 255, 0.08)
                                           : Qt.rgba(1, 1, 1, 0.10)
    readonly property color controlStrong: light ? Qt.rgba(31 / 255, 26 / 255, 33 / 255, 0.14)
                                                 : Qt.rgba(1, 1, 1, 0.16)
    readonly property color glassTint: light ? "#ffffff" : "#1a1420"
    readonly property color ok: "#6cc070"
    readonly property color warn: "#e6b04a"
    readonly property color bad: "#ef6b5f"
    readonly property string fontText: "Kalyna Text"
    readonly property string fontDisplay: "Kalyna Display"
    readonly property string fontMono: "JetBrains Mono"

    // One unit grows with the screen so the shell is readable on a 7" Steam Deck and on a monitor.
    property real s: 1
    function px(v) { return Math.round(v * s) }
    readonly property int r: px(12)
    readonly property int topH: px(36)

    readonly property var appColors: ({
        "files": ["#eab14a", "#c47d1f"], "terminal": ["#40364a", "#19151c"], "settings": ["#9a92a5", "#5a5363"],
        "browser": ["#5aa8ff", "#2a62d6"], "music": ["#ff7a8a", "#d43567"], "android": ["#5fd08a", "#1f8f55"],
        "about": ["#e0574e", "#a52d28"], "calc": ["#f08a57", "#cf5527"], "editor": ["#6b9bf2", "#3d67cf"],
        "monitor": ["#43c193", "#1d8665"], "linux": ["#4a4152", "#2a242e"]
    })
}
