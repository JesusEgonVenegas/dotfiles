import QtQuick
import Quickshell
import Quickshell.Hyprland

// Dedicated Claude Code indicator. Hidden while no session needs you; when one
// or more sessions are waiting it expands into a pulsing coral chip showing the
// count. Click to jump to the workspace of the first waiting session.
Item {
    id: root
    height: Theme.barHeight

    property bool active: ClaudeState.anyWaiting

    visible: active
    implicitWidth: active ? pill.implicitWidth : 0
    Behavior on implicitWidth { SmoothedAnimation { velocity: 300 } }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: pillRow.implicitWidth + 20
        height: Theme.barHeight - 10
        radius: Theme.radiusSm
        color: Qt.rgba(Theme.claude.r, Theme.claude.g, Theme.claude.b, 0.10)
        border.color: Theme.claude
        border.width: 1

        // Pulse the border/background to draw the eye.
        SequentialAnimation on opacity {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { to: 1.0; duration: 750; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.55; duration: 750; easing.type: Easing.InOutSine }
        }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            // nf-md-robot — "Claude is waiting"
            Text {
                text: "󰚩"
                color: Theme.claude
                font.pixelSize: Theme.fontMd
                font.family: Theme.fontMono
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: ClaudeState.waitingCount.toString()
                color: Theme.claude
                font.pixelSize: Theme.fontSm
                font.weight: Theme.fontWeight
                font.family: Theme.fontUi
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        // Jump to the waiting session's workspace AND acknowledge it, so the
        // indicator clears even if you don't type anything there.
        onClicked: {
            const list = ClaudeState.waiting
            if (list.length === 0) return
            const w = list.find(s => s.ws != null) || list[0]
            if (w.ws != null) Hyprland.dispatch("workspace " + w.ws)
            Quickshell.execDetached([
                Quickshell.env("HOME") + "/.config/quickshell/scripts/cc-bar-hook.sh",
                "ack", w.session_id
            ])
        }
    }
}
