import QtQuick
import Quickshell

// Always-on count of live Claude Code sessions (from ClaudeState). Sits next to
// the ClaudeWidget "needs you" chip: this shows how many sessions exist, the
// chip pulses when one wants input. Click to open the launcher in "cc" mode.
Item {
    id: root
    height: Theme.barHeight

    readonly property int count: (ClaudeState.sessions || []).length
    visible: count > 0
    implicitWidth: visible ? row.implicitWidth + 14 : 0
    Behavior on implicitWidth { SmoothedAnimation { velocity: 300 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        // nf-md-robot_outline — quieter than the amber "waiting" robot
        Text {
            text: "󱚟"
            color: Theme.muted
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.count.toString()
            color: Theme.fg
            font.pixelSize: Theme.fontSm
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: LauncherState.openClaude() }
}
