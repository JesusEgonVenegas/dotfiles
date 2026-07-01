pragma Singleton
import Quickshell
import QtQuick

// Screenshot action picker. Opened via the GlobalShortcut in shell.qml (Print).
// Picking an action hides the popup, waits for the compositor to un-paint it,
// THEN runs the capture — so the menu never lands in a fullscreen shot.
Singleton {
    id: root

    property bool visible: false
    property string pendingMode: ""

    readonly property var actions: [
        { label: "Region (annotate)",      mode: "region" },
        { label: "Region (quick)",         mode: "region-quick" },
        { label: "Region → clipboard",     mode: "region-copy" },
        { label: "Window",                 mode: "window" },
        { label: "Fullscreen",             mode: "output" },
        { label: "Fullscreen (annotate)",  mode: "output-annotate" },
        { label: "Fullscreen → clipboard", mode: "output-copy" },
        { label: "Fullscreen (3s delay)",  mode: "output-delay" },
        { label: "Extract Text (OCR)",     mode: "ocr" },
        { label: "Pick Color",             mode: "color" }
    ]

    function open()   { visible = true }
    function close()  { visible = false }
    function toggle() { visible = !visible }

    function run(mode) {
        pendingMode = mode
        visible = false
        settle.restart()   // let the popup surface disappear before capturing
    }

    Timer {
        id: settle
        interval: 320
        onTriggered: Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/screenshot.sh", root.pendingMode])
    }
}
