pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Data layer for the calendar panel (CalendarPopup). Two sources:
//   • Events — `khal list` over local .ics that scripts/gcal-sync.py mirrors
//     from Google Calendar (Google blocks CalDAV for OAuth clients, so we use
//     the REST API). ISO date + tab-delimited format (set in ~/.config/khal/
//     config) so parsing is deterministic.
//   • Todos  — "- [ ]" / "- [x]" lines in an Obsidian note, same append pattern
//     as QuickIdeaState.
//
// v1 = glance + quick-add: read the month/agenda, check off todos, and quick-add
// an event (khal date syntax, e.g. "tomorrow 14:00 Dentist") or a todo line.
// Editing/deleting existing events still happens in khal/Google for now.
Singleton {
    id: root

    property bool visible: false
    property bool syncing: false

    // [{ date:"YYYY-MM-DD", time:"HH:MM"|"", endTime, title, calendar }]
    property var events: []
    // [{ done:bool, text:string, line:int (1-based) }]
    property var todos: []

    // Month currently shown in the grid (defaults to the real current month).
    property int displayYear:  Time.now.getFullYear()
    property int displayMonth: Time.now.getMonth()      // 0-11
    // "" => agenda shows everything upcoming; else just that day.
    property string selectedDate: ""

    readonly property string todayStr: Qt.formatDate(Time.now, "yyyy-MM-dd")
    readonly property string monthLabel: Qt.formatDate(new Date(displayYear, displayMonth, 1), "MMMM yyyy")

    readonly property string todoNote:
        Quickshell.env("HOME") + "/documents/Notes/Obsidian/Notes/Ipse/01👁‍🗨 areas/todos.md"

    // date -> true, for the grid's event dots.
    readonly property var eventDays: {
        const m = {}
        for (let i = 0; i < events.length; i++) m[events[i].date] = true
        return m
    }

    // A day cutoff (~30d out) for the default "Upcoming" agenda, so it stays a
    // short glanceable list even though `events` spans ~400d for the grid dots.
    // ISO date strings compare lexicographically, so string <= works.
    readonly property string agendaCutoff:
        Qt.formatDate(new Date(Time.now.getTime() + 30 * 86400000), "yyyy-MM-dd")

    // Agenda list: a single selected day (from anywhere in the grid), else the
    // next ~30 days. `events` itself holds the full ~400d for dots / day-picking.
    readonly property var agenda:
        selectedDate.length > 0
            ? events.filter(e => e.date === selectedDate)
            : events.filter(e => e.date <= agendaCutoff)

    // ===== LIFECYCLE =====
    function open() {
        selectedDate = ""
        displayYear = Time.now.getFullYear()
        displayMonth = Time.now.getMonth()
        load()
        triggerSync()      // refresh from Google in the background
        visible = true
    }
    function close()  { visible = false }
    function toggle() { if (visible) close(); else open() }

    function load() { eventsProc.running = true; todosProc.running = true }

    // ===== MONTH NAV =====
    function prevMonth() {
        if (displayMonth === 0) { displayMonth = 11; displayYear-- } else displayMonth--
    }
    function nextMonth() {
        if (displayMonth === 11) { displayMonth = 0; displayYear++ } else displayMonth++
    }
    function resetMonth() {
        displayYear = Time.now.getFullYear(); displayMonth = Time.now.getMonth(); selectedDate = ""
    }
    function selectDay(ds) { selectedDate = (selectedDate === ds ? "" : ds) }

    // 42 cells (6 weeks, Monday-first). Empty cells have day === 0. Computed as a
    // binding so the grid Repeater refreshes on month / event / selection change.
    readonly property var cells: {
        const first = new Date(displayYear, displayMonth, 1)
        const lead = (first.getDay() + 6) % 7          // Mon-first lead blanks
        const dim = new Date(displayYear, displayMonth + 1, 0).getDate()
        const out = []
        for (let i = 0; i < 42; i++) {
            const dayNum = i - lead + 1
            if (dayNum < 1 || dayNum > dim) { out.push({ day: 0 }); continue }
            const mm = ("0" + (displayMonth + 1)).slice(-2)
            const dd = ("0" + dayNum).slice(-2)
            const ds = displayYear + "-" + mm + "-" + dd
            out.push({ day: dayNum, dateStr: ds,
                       hasEvents: eventDays[ds] === true,
                       isToday: ds === todayStr,
                       isSelected: ds === selectedDate })
        }
        return out
    }

    // ===== EVENTS (khal) =====
    function parseEvents(out) {
        const rows = out.split("\n")
        const list = []
        for (let i = 0; i < rows.length; i++) {
            const l = rows[i]
            if (!/^\d{4}-\d{2}-\d{2}\t/.test(l)) continue   // skip blanks / headers
            const p = l.split("\t")
            list.push({ date: p[0], time: p[1] || "", endTime: p[2] || "",
                        title: (p[3] || "(untitled)"), calendar: p[4] || "", uid: p[5] || "" })
        }
        events = list
    }

    // ===== TODOS (Obsidian markdown) =====
    function parseTodos(out) {
        const rows = out.split("\n")
        const list = []
        for (let i = 0; i < rows.length; i++) {
            const m = rows[i].match(/^\s*[-*] \[([ xX])\]\s+(.*\S)\s*$/)
            if (m) list.push({ done: m[1].toLowerCase() === "x", text: m[2], line: i + 1 })
        }
        todos = list
    }

    // ===== QUICK-ADD / MUTATE =====
    function quickAddEvent(text) {
        let t = (text || "").trim()
        if (t.length === 0) return
        // If a day is selected in the grid, pin the event to it by appending a
        // date Google understands ("Jul 5 2026"). Without this, Google's
        // natural-language parser defaults an undated event to today.
        if (selectedDate.length > 0)
            t += " " + Qt.formatDate(new Date(selectedDate), "MMM d yyyy")
        // Google parses the natural language ("dentist 2pm") via the Calendar
        // API quickAdd endpoint; the sync below pulls it into khal.
        addEventProc.command = ["python",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/gcal-add.py", t]
        addEventProc.running = true
    }

    function quickAddTodo(text) {
        const t = (text || "").trim()
        if (t.length === 0) return
        // argv-passed so unicode/spaces in path + text are safe (à la QuickIdea).
        Quickshell.execDetached(["sh", "-c",
            'printf -- "- [ ] %s\\n" "$2" >> "$1"', "--", todoNote, t])
        todosReload.start()
    }

    function deleteEvent(uid) {
        if (!uid || uid.length === 0) return
        delEventProc.command = ["python",
            Quickshell.env("HOME") + "/.config/quickshell/scripts/gcal-del.py", uid]
        delEventProc.running = true
    }

    function toggleTodo(line) {
        toggleProc.command = [Quickshell.env("HOME") + "/.config/quickshell/scripts/cal-toggle-todo.sh",
                              todoNote, "" + line]
        toggleProc.running = true
    }

    function triggerSync() {
        root.syncing = true
        syncProc.running = true
    }

    // ===== REMINDERS =====
    // Ping the desktop (notify-send → the Quickshell notif daemon) a few minutes
    // before a timed event starts. Runs whether or not the panel is open, and
    // refreshes the event cache every ~5 min so it stays current. All-day events
    // are skipped (no useful ping time).
    property int reminderLeadMin: 10   // timed events: ping this many min before
    property int allDayHour: 9         // all-day events: ping at this hour, morning-of
    property var notifiedUids: ({})
    property int reminderRefreshTicks: 0

    // Local ms for a "YYYY-MM-DD" at a given hour (hour 24 → next midnight).
    function dayMs(dateStr, hour) {
        const d = dateStr.split("-")
        return new Date(+d[0], +d[1] - 1, +d[2], hour, 0, 0).getTime()
    }

    function eventStartMs(ev) {
        if (!ev.time || ev.time.length === 0) return 0
        const d = ev.date.split("-"), t = ev.time.split(":")
        return new Date(+d[0], +d[1] - 1, +d[2], +t[0], +t[1], 0).getTime()
    }

    function checkReminders() {
        if (reminderRefreshTicks <= 0) { eventsProc.running = true; reminderRefreshTicks = 5 }
        reminderRefreshTicks--

        const now = Date.now()
        const leadMs = reminderLeadMin * 60000
        for (let i = 0; i < events.length; i++) {
            const ev = events[i]
            if (ev.time && ev.time.length > 0) {
                // Timed event: ping leadMin before it starts.
                const delta = eventStartMs(ev) - now
                if (delta > 0 && delta <= leadMs && !notifiedUids[ev.uid]) {
                    notifiedUids[ev.uid] = true
                    const mins = Math.max(1, Math.round(delta / 60000))
                    Quickshell.execDetached(["notify-send", "-a", "Calendar", "-u", "normal",
                        ev.title, "in " + mins + " min · " + ev.time])
                }
            } else if (ev.date) {
                // All-day event: one ping in the morning-of (catch-up if the
                // session starts later the same day; never fires once the day
                // has passed). Keyed separately so it can't clash with timed.
                const key = "allday:" + ev.uid
                if (now >= dayMs(ev.date, allDayHour) && now < dayMs(ev.date, 24)
                        && !notifiedUids[key]) {
                    notifiedUids[key] = true
                    Quickshell.execDetached(["notify-send", "-a", "Calendar", "-u", "normal",
                        ev.title, "All day today"])
                }
            }
        }
    }

    Timer {
        id: reminderTick
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.checkReminders()
    }

    // Small debounce so an append has landed before we re-read the note.
    Timer { id: todosReload; interval: 120; onTriggered: todosProc.running = true }

    Process {
        id: eventsProc
        command: ["khal", "list", "--day-format", "",
                  "--format", "{start-date}\t{start-time}\t{end-time}\t{title}\t{calendar}\t{uid}",
                  "today", "400d"]
        stdout: StdioCollector { onStreamFinished: root.parseEvents(text) }
    }

    Process {
        id: todosProc
        command: ["cat", root.todoNote]
        stdout: StdioCollector { onStreamFinished: root.parseTodos(text) }
    }

    Process {
        id: addEventProc
        command: ["true"]
        onExited: { root.load(); root.triggerSync() }
    }

    Process {
        id: delEventProc
        command: ["true"]
        onExited: { root.load(); root.triggerSync() }
    }

    Process {
        id: toggleProc
        command: ["true"]
        onExited: todosProc.running = true
    }

    Process {
        id: syncProc
        command: ["systemctl", "--user", "start", "gcal-sync.service"]
        onExited: { root.syncing = false; eventsProc.running = true }
    }
}
