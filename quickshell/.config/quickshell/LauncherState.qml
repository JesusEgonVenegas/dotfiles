pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Application launcher backed by Quickshell.DesktopEntries. Opened via the
// GlobalShortcut in shell.qml (Super+D). Type to filter, Up/Down to move,
// Enter to launch, Esc to close. Replaces `rofi -show drun`.
//
// Ranking: with no query, most-launched apps float to the top (usage counts
// persisted to ~/.local/state/quickshell/launcher-usage.json). With a query,
// match quality leads and usage breaks ties.
Singleton {
    id: root

    property bool   visible: false
    property string query: ""
    property var    counts: ({})   // desktop-entry id -> launch count

    readonly property string stateDir:  Quickshell.env("HOME") + "/.local/state/quickshell"
    readonly property string usagePath: stateDir + "/launcher-usage.json"

    // All launchable desktop apps (drop NoDisplay entries).
    readonly property var apps: DesktopEntries.applications.values
        .filter(a => a && !a.noDisplay)
        .slice()

    function usageOf(a) { return (a && counts[a.id]) ? counts[a.id] : 0 }

    // Searchable text for an entry: name + generic name + comment + keywords.
    function haystack(a) {
        var parts = [a.name || "", a.genericName || "", a.comment || ""]
        try { if (a.keywords) parts.push([].join.call(a.keywords, " ")) } catch (e) {}
        return parts.join(" ").toLowerCase()
    }

    function byUsageThenName(a, b) {
        const ua = usageOf(a), ub = usageOf(b)
        if (ua !== ub) return ub - ua
        return (a.name || "").toLowerCase() < (b.name || "").toLowerCase() ? -1 : 1
    }

    // Ranked filter: name-prefix > word-boundary > name-substring > other-fields.
    // Usage count breaks ties within a rank; empty query = pure usage-then-name.
    readonly property var filtered: {
        const q = query.trim().toLowerCase()
        if (q.length === 0) return apps.slice().sort(byUsageThenName)
        const scored = []
        for (var i = 0; i < apps.length; i++) {
            const a = apps[i]
            const name = (a.name || "").toLowerCase()
            const rest = haystack(a)
            var score = -1
            if (name.startsWith(q))                 score = 0
            else if (name.indexOf(" " + q) >= 0)    score = 1
            else if (name.indexOf(q) >= 0)          score = 2
            else if (rest.indexOf(q) >= 0)          score = 3
            if (score >= 0) scored.push({ app: a, score: score })
        }
        scored.sort((x, y) => x.score !== y.score ? x.score - y.score
                    : root.byUsageThenName(x.app, y.app))
        return scored.map(s => s.app)
    }

    function open()   { query = ""; visible = true }
    function close()  { visible = false; query = "" }
    function toggle() { if (visible) close(); else open() }

    function launch(entry) {
        if (!entry) return
        // bump usage count and persist
        var c = counts
        c[entry.id] = (c[entry.id] || 0) + 1
        counts = c
        save()
        entry.execute()   // handles Exec field codes, Terminal=true, etc.
        close()
    }

    // ---- persistence (Process-based, matching the rest of the shell) ----
    function parseCounts(text) {
        try { counts = JSON.parse(text) || ({}) }
        catch (e) { counts = ({}) }
    }

    function save() {
        const b64 = Qt.btoa(JSON.stringify(counts))   // base64 → no shell-escaping hazard
        writeProc.command = ["sh", "-c",
            "mkdir -p '" + stateDir + "' && printf %s '" + b64 + "' | base64 -d > '" + usagePath + "'"]
        writeProc.running = true
    }

    Component.onCompleted: readProc.running = true

    Process {
        id: readProc
        command: ["sh", "-c", "cat '" + root.usagePath + "' 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parseCounts(text) }
    }
    Process { id: writeProc; command: ["true"] }
}
