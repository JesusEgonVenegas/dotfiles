pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Bridges the screen recorder (~/.config/hypr/scripts/record.sh) -> the bar.
// record.sh writes ~/.local/state/screen-rec/state.json on start/stop:
//   {"recording":true,"start":<epoch>,"encoder":"NVENC","audio":"system","file":"..."}
// We watch that file and expose recording state + a live elapsed counter.
Singleton {
    id: root

    readonly property string stateDir:  Quickshell.env("HOME") + "/.local/state/screen-rec"
    readonly property string statePath: stateDir + "/state.json"

    property bool   recording: false
    property double startEpoch: 0
    property string encoder: ""
    property string audio: ""

    // Ticking wall clock (seconds), refreshed each second while recording.
    property double nowSec: 0
    Timer {
        interval: 1000
        repeat: true
        running: root.recording
        triggeredOnStart: true
        onTriggered: root.nowSec = Date.now() / 1000
    }

    readonly property int elapsed:
        recording && startEpoch > 0 ? Math.max(0, Math.floor(nowSec - startEpoch)) : 0
    readonly property string elapsedStr: {
        const m = Math.floor(elapsed / 60)
        const s = elapsed % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    function stop() {
        Quickshell.execDetached([
            Quickshell.env("HOME") + "/.config/hypr/scripts/record.sh", "stop"])
    }

    // Make sure the file exists before FileView starts watching it.
    Process {
        id: ensure
        command: ["sh", "-c",
            "d=\"$HOME/.local/state/screen-rec\"; mkdir -p \"$d\"; " +
            "[ -f \"$d/state.json\" ] || echo '{\"recording\":false}' > \"$d/state.json\""]
        Component.onCompleted: running = true
        onExited: view.reload()
    }

    FileView {
        id: view
        path: root.statePath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const o = JSON.parse(text())
                root.recording  = !!o.recording
                root.startEpoch = o.start   || 0
                root.encoder    = o.encoder || ""
                root.audio      = o.audio   || ""
                if (root.recording) root.nowSec = Date.now() / 1000
            } catch (e) {
                root.recording = false
            }
        }
        onLoadFailed: root.recording = false
    }
}
