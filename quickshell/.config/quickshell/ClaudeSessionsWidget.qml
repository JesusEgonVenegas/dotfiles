import QtQuick
import Quickshell

// Always-on count of live Claude Code sessions (from ClaudeState). Sits next to
// the ClaudeWidget "needs you" chip: this shows how many sessions exist, the
// chip pulses when one wants input. Click to open the launcher in "cc" mode.
Item {
    id: root
    height: Theme.barHeight

    readonly property int count: (ClaudeState.sessions || []).length

    // Rolling-window color thresholds (effective tok / 5h). Calibrated to your
    // observed usage — tune once you see where you actually get throttled.
    readonly property real winAmber: 45000000
    readonly property real winRed:   75000000
    function fmtTok(n) {
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
             : n >= 1e3 ? Math.round(n / 1e3) + "k" : ("" + Math.round(n))
    }
    function usageColor(n) {
        return n >= winRed ? Theme.critical : n >= winAmber ? Theme.warning : Theme.muted
    }

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

        // Rolling 5h consumption — proxy for Max rate-limit pressure
        Text {
            visible: ClaudeState.winTokens > 0
            text: root.fmtTok(ClaudeState.winTokens)
            color: root.usageColor(ClaudeState.winTokens)
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }

        // Live spend across active sessions (from the statusLine cost feed)
        Text {
            visible: ClaudeState.totalCost > 0
            text: "$" + ClaudeState.totalCost.toFixed(2)
            color: Theme.accentAlt
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: hovered
            ? TooltipState.show("Claude Code",
                root.count + " live · " + root.fmtTok(ClaudeState.winTokens) + " tok/5h · "
                + root.fmtTok(ClaudeState.dayTokens) + " today"
                + (ClaudeState.totalCost > 0 ? " · $" + ClaudeState.totalCost.toFixed(2) + " (API-equiv)" : ""),
                root.mapToGlobal(root.width / 2, 0).x)
            : TooltipState.hide()
    }
    MouseArea { anchors.fill: parent; onClicked: LauncherState.openClaude() }
}
