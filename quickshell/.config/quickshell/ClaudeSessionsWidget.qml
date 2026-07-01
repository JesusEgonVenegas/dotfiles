import QtQuick
import Quickshell

// Always-on count of live Claude Code sessions (from ClaudeState). Sits next to
// the ClaudeWidget "needs you" chip: this shows how many sessions exist, the
// chip pulses when one wants input. Click to open the launcher in "cc" mode.
//
// The token readout is Max-plan oriented: the headline is consumption in the
// current 5h rate-limit block, colored against your *own* historical peak (so
// it self-calibrates instead of relying on guessed limits), with a countdown to
// when the block resets. Dollar cost is demoted to the tooltip — it's flat-rate
// noise up top.
Item {
    id: root
    height: Theme.barHeight

    readonly property int count: (ClaudeState.sessions || []).length

    // Ticking clock for the reset countdown (30s granularity is plenty).
    property double nowSec: 0
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: root.nowSec = Date.now() / 1000
    }
    readonly property real resetLeft:
        ClaudeState.resetAt > 0 ? ClaudeState.resetAt - nowSec : 0

    // Warn/crit thresholds auto-calibrate to the largest 5h block you've hit.
    // Fall back to rough guesses until at least one block has closed.
    readonly property real winAmber: ClaudeState.peakTokens > 0
        ? ClaudeState.peakTokens * 0.75 : 45000000
    readonly property real winRed: ClaudeState.peakTokens > 0
        ? ClaudeState.peakTokens * 0.95 : 75000000

    function fmtTok(n) {
        return n >= 1e6 ? (n / 1e6).toFixed(1) + "M"
             : n >= 1e3 ? Math.round(n / 1e3) + "k" : ("" + Math.round(n))
    }
    function fmtDur(s) {
        s = Math.max(0, Math.round(s))
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60)
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m + "m"
             : m > 0 ? m + "m" : "<1m"
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

        // Current 5h block consumption — proxy for Max rate-limit pressure,
        // colored against your own historical peak block.
        Text {
            visible: ClaudeState.winTokens > 0
            text: root.fmtTok(ClaudeState.winTokens)
            color: root.usageColor(ClaudeState.winTokens)
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }

        // Time until the current block resets (frees up rate-limit headroom).
        Text {
            visible: root.resetLeft > 0
            text: "⧗" + root.fmtDur(root.resetLeft)
            color: Theme.muted
            font.pixelSize: Theme.fontXs
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: hovered
            ? TooltipState.show("Claude Code",
                root.count + " live"
                + "\n" + root.fmtTok(ClaudeState.winTokens) + " tok this 5h block"
                + (root.resetLeft > 0 ? "  ·  resets in " + root.fmtDur(root.resetLeft) : "")
                + (ClaudeState.peakTokens > 0 ? "\npeak 5h block  " + root.fmtTok(ClaudeState.peakTokens) : "")
                + "\n" + root.fmtTok(ClaudeState.dayTokens) + " today  ·  "
                + root.fmtTok(ClaudeState.weekTokens) + " this week"
                + (ClaudeState.totalCost > 0 ? "\n$" + ClaudeState.totalCost.toFixed(2) + " API-equiv" : ""),
                root.mapToGlobal(root.width / 2, 0).x)
            : TooltipState.hide()
    }
    MouseArea { anchors.fill: parent; onClicked: LauncherState.openClaude() }
}
