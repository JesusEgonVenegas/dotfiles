pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property int wifiSignal: -1
    property string ssid: ""
    property bool wired: false
    property bool connected: wifiSignal >= 0 || wired

    property string icon: {
        if (!connected) return "󰤭"
        if (wired)      return "󰈀"
        if (wifiSignal >= 75) return "󰤨"
        if (wifiSignal >= 50) return "󰤥"
        if (wifiSignal >= 25) return "󰤢"
        return "󰤟"
    }

    property color iconColor: !connected       ? Theme.muted
                            : wired            ? Theme.accentAlt
                            : wifiSignal >= 50 ? Theme.ok
                            : wifiSignal >= 25 ? Theme.alert
                            : Theme.danger

    Behavior on iconColor {
        ColorAnimation { duration: 600 }
    }

    Process {
        id: netProc
        // Outputs one of: "wifi:<signal>:<ssid>", "wired", "none"
        command: ["sh", "-c",
            "sig=$(nmcli -t -f active,signal dev wifi 2>/dev/null | awk -F: '/^yes:/{print $2; exit}');" +
            "ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes:/{print $2; exit}');" +
            "if [ -n \"$sig\" ]; then echo wifi:$sig:$ssid;" +
            "elif nmcli -t -f type,state dev 2>/dev/null | grep -q '^ethernet:connected'; then echo wired;" +
            "else echo none; fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim()
                if (line.startsWith("wifi:")) {
                    const rest  = line.slice(5)
                    const colon = rest.indexOf(":")
                    root.wifiSignal = parseInt(rest.slice(0, colon)) || 0
                    root.ssid       = rest.slice(colon + 1) || ""
                    root.wired      = false
                } else if (line === "wired") {
                    root.wired      = true
                    root.wifiSignal = -1
                    root.ssid       = ""
                } else {
                    root.wired      = false
                    root.wifiSignal = -1
                    root.ssid       = ""
                }
            }
        }
        Component.onCompleted: running = true
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: netProc.running = true
    }
}
