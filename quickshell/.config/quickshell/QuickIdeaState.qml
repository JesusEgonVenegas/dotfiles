pragma Singleton
import Quickshell
import QtQuick

// Quick-capture for fleeting thoughts. Opened via the GlobalShortcut in
// shell.qml (Super+Shift+I). Type an idea, Enter appends it (timestamped) to
// the Obsidian ideas note, Esc cancels. Native replacement for the old
// rofi-based quick-idea script.
Singleton {
    id: root

    property bool visible: false

    // Obsidian vault → ideas note (matches the old quick-idea script's target).
    readonly property string note:
        Quickshell.env("HOME") + "/documents/Notes/Obsidian/Notes/Ipse/01👁‍🗨 areas/ideas.md"

    function open()   { visible = true }
    function close()  { visible = false }
    function toggle() { if (visible) close(); else open() }

    function submit(txt) {
        const t = (txt || "").trim()
        if (t.length > 0) {
            // Append "- <YYYY-MM-DD HH:MM:SS> - <idea>" — args passed via argv so
            // spaces / unicode in the path and text are safe.
            Quickshell.execDetached(["sh", "-c",
                'printf -- "- %s - %s\\n" "$(date "+%Y-%m-%d %H:%M:%S")" "$2" >> "$1"',
                "--", note, t])
        }
        close()
    }
}
