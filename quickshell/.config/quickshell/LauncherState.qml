pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    property var    windows: []    // open windows (populated on open, for "/" mode)

    // Modes, chosen by the first character of the query.
    readonly property bool webMode:    query.trim().charAt(0) === "?"
    readonly property bool windowMode: query.trim().charAt(0) === "/"

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
        // calc/web modes don't drive the list (they show a hint panel instead).
        if (calcMode || webMode) return []
        // window switcher: filter the preloaded open windows.
        if (windowMode) {
            const wq = query.trim().slice(1).trim().toLowerCase()
            if (wq.length === 0) return windows
            return windows.filter(w =>
                (w.name + " " + w.genericName).toLowerCase().indexOf(wq) >= 0)
        }
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

    // ---- calculator mode: leading "=", evaluated by qalc (units/currency/etc) ----
    readonly property bool calcMode: query.trim().charAt(0) === "="
    property string calcResult: ""
    onQueryChanged: { if (calcMode) calcTimer.restart(); else calcResult = "" }

    function open()   { query = ""; calcResult = ""; clientsProc.running = true; visible = true }
    function close()  { visible = false; query = "" }
    function toggle() { if (visible) close(); else open() }

    // Launch an app entry OR focus an open window (window items carry .isWindow).
    function launch(item) {
        if (!item) return
        if (item.isWindow) {
            Hyprland.dispatch("focuswindow address:" + item.address)
            close()
            return
        }
        var c = counts
        c[item.id] = (c[item.id] || 0) + 1   // bump usage count and persist
        counts = c
        save()
        item.execute()   // handles Exec field codes, Terminal=true, etc.
        close()
    }

    // "?" mode: open the default browser on a DuckDuckGo search.
    function webSearch() {
        const q = query.trim().slice(1).trim()
        if (q.length === 0) { close(); return }
        Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(q)])
        close()
    }

    function parseClients(text) {
        try {
            const arr = JSON.parse(text)
            windows = arr
                .filter(c => c && c.mapped && c.title && c.title.length > 0)
                .map(c => ({
                    isWindow: true,
                    address: c.address,
                    name: c.title,
                    genericName: (c.class || "?") + "  ·  ws " + (c.workspace ? c.workspace.id : "?"),
                    icon: (c.class || "").toLowerCase()
                }))
        } catch (e) { windows = [] }
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

    // qalc evaluation, debounced so we don't spawn one per keystroke.
    Timer {
        id: calcTimer
        interval: 90
        onTriggered: {
            var expr = root.query.trim().slice(1).trim()
                           .replace(/([0-9.]+%)\s+of\s+/gi, "$1 * ")  // "20% of 340" -> "20% * 340"
            if (expr.length === 0) { root.calcResult = ""; return }
            calcProc.command = ["qalc", "-t", expr]
            calcProc.running = true
        }
    }
    Process {
        id: calcProc
        command: ["true"]
        stdout: StdioCollector { onStreamFinished: root.calcResult = text.trim() }
    }

    // Open windows for the "/" switcher, refreshed each time the launcher opens.
    Process {
        id: clientsProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { onStreamFinished: root.parseClients(text) }
    }
}
