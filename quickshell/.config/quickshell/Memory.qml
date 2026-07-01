pragma Singleton
import Quickshell.Io
import QtQuick
import Quickshell

Singleton {
    id: root

    property int memUsage: 0
    property string memUsedStr: ""
    property string memTotalStr: ""

    Process {
        id: memProc
        command: ["sh", "-c", "free | grep Mem"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                const totalKB = parseInt(parts[1]) || 1
                const usedKB  = parseInt(parts[2]) || 0
                root.memUsage    = Math.round((usedKB / totalKB) * 100)
                root.memUsedStr  = (usedKB  / 1048576).toFixed(1) + " GB"
                root.memTotalStr = (totalKB / 1048576).toFixed(1) + " GB"
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: memProc.running = true
    }
}
