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

    // Effective-token consumption (cache reads weighted x0.1), from cc-usage.sh.
    property real winTokens: 0   // current open 5h block — proxy for Max rate-limit pressure
    property real dayTokens: 0   // since local midnight
    property real weekTokens: 0  // last 7 days — the Max weekly cap often binds first
    property real peakTokens: 0  // largest closed 5h block seen — self-calibrates thresholds
    property double resetAt: 0   // epoch the open 5h block resets (0 when idle)

    // Current-block consumption split by model family (Opus burns fastest).
    property real winOpus: 0
    property real winSonnet: 0
    property real winHaiku: 0

    // --- Low-headroom alert -------------------------------------------------
    // Fire one desktop notification per 5h block when consumption crosses ~95%
    // of the calibrated peak, so you get a heads-up before hitting the wall
    // mid-task. Keyed on resetAt (unique per block) so it never repeats within
    // a block. Needs a closed block to calibrate against (peakTokens > 0).
    // Two escalating levels, each fired at most once per block:
    //   warn (~85% of peak) — a normal 5s heads-up
    //   crit (~95% of peak) — a critical, sticky toast to wrap up
    property double lastWarnReset: 0
    property double lastCritReset: 0
    function fmtTokShort(n) {
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
             : n >= 1e3 ? Math.round(n / 1e3) + "k" : ("" + Math.round(n))
    }
    function fmtDurShort(s) {
        s = Math.max(0, Math.round(s))
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m + "m" : (m > 0 ? m + "m" : "<1m")
    }
    function fireAlert(urgency, icon, title, body) {
        Quickshell.execDetached([
            "notify-send", "-a", "Claude Code", "-u", urgency, "-i", icon, title, body
        ])
    }
    function maybeAlert() {
        if (resetAt <= 0 || peakTokens <= 0) return
        const used = fmtTokShort(winTokens)
        const left = fmtDurShort(resetAt - (Date.now() / 1000))
        // Critical first — if we jumped straight past both, skip the warn.
        if (winTokens >= peakTokens * 0.95) {
            if (resetAt === lastCritReset) return
            lastCritReset = resetAt
            lastWarnReset = resetAt
            fireAlert("critical", "dialog-error", "5h rate limit nearly reached",
                      used + " used · resets in " + left + " — consider wrapping up")
            return
        }
        if (winTokens >= peakTokens * 0.85) {
            if (resetAt === lastWarnReset) return
            lastWarnReset = resetAt
            fireAlert("normal", "dialog-warning", "Approaching 5h rate limit",
                      used + " used this block · resets in " + left)
        }
    }

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

    // Rolling-window + daily token totals (heavier transcript scan → slow timer).
    Process {
        id: usageProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/cc-usage.sh"]
        stdout: StdioCollector { onStreamFinished: {
            try {
                const u = JSON.parse(text)
                root.winTokens  = u.win  || 0
                root.dayTokens  = u.day  || 0
                root.weekTokens = u.week || 0
                root.peakTokens = u.peak || 0
                root.resetAt    = u.reset || 0
                root.winOpus    = u.opus   || 0
                root.winSonnet  = u.sonnet || 0
                root.winHaiku   = u.haiku  || 0
                root.maybeAlert()
            } catch (e) {}
        } }
    }
    Timer { interval: 120000; running: true; repeat: true; triggeredOnStart: true; onTriggered: usageProc.running = true }
}
