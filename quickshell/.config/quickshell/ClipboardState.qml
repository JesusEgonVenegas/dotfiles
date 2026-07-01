pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Clipboard history backed by cliphist. `cliphist list` yields newest-first
// lines of "<id>\t<preview>"; we copy a chosen entry back with
// `cliphist decode <id> | wl-copy`. Watchers (in hyprland.conf exec-once) keep
// the store populated; wl-clip-persist keeps entries alive after apps close.
Singleton {
    id: root

    property bool   visible: false
    property var    entries: []      // [{ id, preview, line }]
    property string query: ""

    readonly property var filtered: query.length === 0
        ? entries
        : entries.filter(e => e.preview.toLowerCase().indexOf(query.toLowerCase()) >= 0)

    function open()   { query = ""; load(); visible = true }
    function close()  { visible = false; query = "" }
    function toggle() { if (visible) close(); else open() }

    function load() { listProc.running = true }

    function parseList(out) {
        const lines = out.split("\n").filter(l => l.length > 0)
        entries = lines.map(function (l) {
            const tab = l.indexOf("\t")
            const id  = tab >= 0 ? l.slice(0, tab).trim() : l.trim()
            const pv  = tab >= 0 ? l.slice(tab + 1) : l
            return { id: id, preview: pv, line: l }
        })
    }

    function copy(id) {
        copyProc.command = ["sh", "-c", "cliphist decode " + id + " | wl-copy"]
        copyProc.running = true
        close()
    }

    function wipe() {
        wipeProc.running = true
        entries = []
        close()
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector { onStreamFinished: root.parseList(text) }
    }
    Process { id: copyProc; command: ["true"] }
    Process { id: wipeProc; command: ["cliphist", "wipe"] }
}
