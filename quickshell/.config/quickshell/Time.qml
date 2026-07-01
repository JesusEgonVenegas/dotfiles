// Time.qml
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // ===== RAW DATE OBJECT =====
    readonly property var now: clock.date

    // ===== ORDINAL DAY =====
    readonly property int day: now.getDate()

    readonly property string dayOrdinal: {
        const n = day;
        const suffix = (n % 100 >= 11 && n % 100 <= 13) ? "th" : (["th", "st", "nd", "rd"][n % 10] || "th");
        return n + suffix;
    }

    // ===== FORMATTED OUTPUTS =====
    readonly property string timeOnly: Qt.formatDateTime(now, "hh:mm AP")

    readonly property string dateOnly: Qt.formatDateTime(now, "ddd MMM ") + dayOrdinal + Qt.formatDateTime(now, " yyyy")

    // ===== FULL COMBINED (IF YOU STILL WANT IT) =====
    readonly property string time: timeOnly + " - " + dateOnly

    // ===== SYSTEM CLOCK =====
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
