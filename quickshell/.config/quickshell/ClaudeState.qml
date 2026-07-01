pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Bridges Claude Code -> the bar. A hook script (scripts/cc-bar-hook.sh) writes
// an aggregate JSON array to ~/.local/state/cc-bar/state.json, one entry per
// live session: {session_id, state:"waiting"|"busy", ws:<int|null>, cwd, ts}.
// We watch that file and expose which workspaces have a session needing input.
Singleton {
    id: root

    readonly property string stateDir:  Quickshell.env("HOME") + "/.local/state/cc-bar"
    readonly property string statePath: stateDir + "/state.json"

    // Raw session list from disk.
    property var sessions: []

    // Total $ spent across sessions active in the last hour (fed by the
    // statusLine script writing per-session cost files under cost/).
    property real totalCost: 0

    // Sessions needing attention. "action" = must be answered (permission
    // prompt); "done" = finished/idle, informational (auto-clears on visit).
    readonly property var waiting: sessions.filter(
        s => s && (s.state === "action" || s.state === "done"))
    readonly property int waitingCount: waiting.length
    readonly property bool anyWaiting: waitingCount > 0

    // Is a Claude session on this Hyprland workspace id waiting for me?
    function workspaceWaiting(id) {
        return waiting.some(s => s.ws === id)
    }

    readonly property string hookScript:
        Quickshell.env("HOME") + "/.config/quickshell/scripts/cc-bar-hook.sh"

    // Acknowledge "done" (informational) sessions on a workspace once you visit
    // it — you've seen it, nothing to action. "action" sessions stay put.
    function clearDoneOn(wsId) {
        if (!wsId) return
        for (const s of sessions) {
            if (s && s.state === "done" && s.ws === wsId)
                Quickshell.execDetached([hookScript, "ack", s.session_id])
        }
    }

    // Current Hyprland workspace; clearing fires when it changes, or when new
    // session state lands while we're already sitting on that workspace.
    readonly property int focusedWs: Hyprland.focusedWorkspace?.id || 0
    onFocusedWsChanged: clearDoneOn(focusedWs)

    // Make sure the bridge file exists before FileView starts watching it,
    // otherwise the first read fails until the first Claude session runs.
    Process {
        id: ensure
        command: ["sh", "-c",
            "d=\"$HOME/.local/state/cc-bar\"; mkdir -p \"$d\"; " +
            "[ -f \"$d/state.json\" ] || echo '[]' > \"$d/state.json\""]
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
                const parsed = JSON.parse(text())
                root.sessions = Array.isArray(parsed) ? parsed : []
            } catch (e) {
                root.sessions = []
            }
            // If a "done" session appears on the workspace we're already on,
            // clear it immediately rather than waiting for a focus change.
            root.clearDoneOn(root.focusedWs)
            costProc.running = true
        }
        onLoadFailed: root.sessions = []
    }

    // Sum cost across sessions active in the last hour; prune files older than
    // 12h. Refreshed on every state change and on a slow timer.
    Process {
        id: costProc
        command: ["sh", "-c",
            "d=\"${XDG_STATE_HOME:-$HOME/.local/state}/cc-bar/cost\"; " +
            "[ -d \"$d\" ] || { echo 0; exit 0; }; " +
            "find \"$d\" -name '*.json' -mmin +720 -delete 2>/dev/null; " +
            "jq -s 'map(select((now - .ts) < 3600) | .cost) | add // 0' \"$d\"/*.json 2>/dev/null || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.totalCost = parseFloat(text.trim()) || 0 }
    }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: costProc.running = true }
}
