pragma Singleton
import Quickshell
import QtQuick

// Recording action picker (replaces record-menu.sh). Opened with Super+R.
// When a recording is active the popup shows only "Stop" (see RecordMenuPopup,
// which switches on RecordState.recording).
Singleton {
    id: root

    property bool visible: false
    property var pendingArgs: []

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh"

    readonly property var actions: [
        { label: "Region",                 args: ["region"] },
        { label: "Fullscreen",             args: ["output"] },
        { label: "Region + Mic",           args: ["region", "mic"] },
        { label: "Fullscreen + Mic",       args: ["output", "mic"] },
        { label: "Fullscreen + System Audio", args: ["output", "system"] }
    ]

    function open()   { visible = true }
    function close()  { visible = false }
    function toggle() { visible = !visible }

    function run(argList) {
        pendingArgs = argList
        visible = false
        settle.restart()   // let the popup vanish before wf-recorder grabs the screen
    }

    function stopRec() {
        visible = false
        Quickshell.execDetached([script, "stop"])
    }

    Timer {
        id: settle
        interval: 320
        onTriggered: Quickshell.execDetached([root.script].concat(root.pendingArgs))
    }
}
