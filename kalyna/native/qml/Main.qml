import QtQuick
import QtQuick.Window
import QtWayland.Compositor
import QtWayland.Compositor.XdgShell
import Kalyna

// Kalyna is the Wayland compositor: apps connect to it and appear inside the shell.
WaylandCompositor {
    id: comp
    socketName: Shell.socketName

    WaylandOutput {
        id: output
        sizeFollowsWindow: true
        window: Window {
            id: win
            readonly property var nestedSize: (Qt.application.arguments.indexOf("--size") >= 0
                ? Qt.application.arguments[Qt.application.arguments.indexOf("--size") + 1] : "1280x800").split("x")
            width: Shell.nested ? Number(nestedSize[0]) : Screen.width
            height: Shell.nested ? Number(nestedSize[1]) : Screen.height
            visible: true
            visibility: Shell.nested ? Window.Windowed : Window.FullScreen
            title: "Kalyna OS"
            color: "black"
            // the shell's window must be the active one so typing (and the on-screen keyboard) works
            Component.onCompleted: requestActivate()

            ShellUI {
                id: ui
                compositor: comp
                anchors.fill: parent
            }
        }
    }

    XdgShell {
        onToplevelCreated: (toplevel, xdgSurface) => ui.addWindow(toplevel, xdgSurface)
    }
    // ask apps to leave out their own title bars: Kalyna shows apps full-screen
    XdgDecorationManagerV1 { preferredMode: XdgToplevel.ServerSideDecoration }
    // typing from Kalyna's on-screen keyboard into apps
    TextInputManager {}
    TextInputManagerV3 {}
    QtTextInputMethodManager {}
    // let video players keep the screen awake
    IdleInhibitManagerV1 {}

    // keyboard layouts for apps: English and Ukrainian, Alt+Shift switches
    Component.onCompleted: {
        defaultSeat.keymap.layout = "us,ua"
        defaultSeat.keymap.options = "grp:alt_shift_toggle"
    }
}
