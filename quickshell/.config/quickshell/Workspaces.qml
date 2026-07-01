import QtQuick
import Quickshell
import Quickshell.Hyprland
import "./utils" as Utils

Rectangle {
    id: root

    property int cellWidth: 32

    // The secondary monitor (HDMI-A-1) owns workspaces 6-10. When it's powered
    // off it gets disabled in Hyprland (see hypr/scripts/toggle-secondary.sh)
    // and drops out of Hyprland.monitors. In that case cap the bar to the
    // primary's workspaces so the phantom 6th+ cell isn't drawn.
    property string secondaryMonitor: "HDMI-A-1"
    property int primaryWsCount: 5
    property bool secondaryConnected: Hyprland.monitors.values.some(m => m.name === secondaryMonitor)

    property int wsCount: secondaryConnected ? (Utils.HyprlandUtils.maxWorkspace || 1) : primaryWsCount
    property int activeId: Hyprland.focusedWorkspace?.id || 1

    implicitWidth: wsCount * cellWidth
    implicitHeight: Theme.barHeight - 8
    radius: 6
    color: Theme.chipLeftBg
    border.color: Theme.chipBorder
    border.width: 1

    // Sliding highlight pill
    Rectangle {
        id: pill
        x: (root.activeId - 1) * root.cellWidth
        y: 3
        width: root.cellWidth
        height: root.implicitHeight - 6
        radius: 4
        color: Theme.accent
        opacity: 0.20

        Behavior on x {
            SmoothedAnimation { velocity: 400 }
        }
    }

    Row {
        anchors.fill: parent

        Repeater {
            model: root.wsCount

            Item {
                required property int index

                property bool isActive: root.activeId === (index + 1)
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                // A Claude Code session on this workspace is waiting for input.
                property bool claudeWaiting: ClaudeState.workspaceWaiting(index + 1)

                width: root.cellWidth
                height: root.implicitHeight

                // Pulsing amber glow when Claude needs you here.
                Rectangle {
                    anchors.centerIn: parent
                    width: root.cellWidth - 6
                    height: parent.height - 6
                    radius: 4
                    color: "transparent"
                    border.color: Theme.accentAlt
                    border.width: 1
                    visible: claudeWaiting && !isActive
                    opacity: 0

                    SequentialAnimation on opacity {
                        running: claudeWaiting && !isActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.85; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.15; duration: 700; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: (index + 1).toString()
                    font.pixelSize: Theme.fontMd
                    font.weight: Theme.fontWeight
                    font.family: Theme.fontUi
                    color: claudeWaiting ? Theme.accentAlt
                         : isActive      ? Theme.accent
                         : ws            ? Theme.fg
                                         : Theme.muted

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + (index + 1))
                }
            }
        }
    }
}
