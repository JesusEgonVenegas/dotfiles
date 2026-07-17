import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: trayWindow
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            color: Theme.barBg
            implicitHeight: Theme.barHeight

            RowLayout {
                anchors.fill: parent
                spacing: 6

                Workspaces {
                    Layout.leftMargin: 6
                    Layout.alignment: Qt.AlignVCenter
                }

                ActiveWindowWidget {
                    Layout.leftMargin: 6
                    Layout.fillWidth: true
                }

                // Screen recording — only takes space while recording
                RecordWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                }

                // MPRIS — only takes space when media is playing
                MprisWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                }

                // Claude Code — live session count (click → cc launcher)
                ClaudeSessionsWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                }

                // Claude Code — only takes space when a session needs input
                ClaudeWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                }

                TrayWidget {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 4
                    window: trayWindow
                }

                // ── Right chip ──────────────────────────────────────────
                Rectangle {
                    id: rightChip
                    color: Theme.chipRightBg
                    implicitHeight: Theme.barHeight - 8
                    implicitWidth: statsRow.implicitWidth + Theme.chipPadding * 2
                    radius: 6
                    Layout.rightMargin: 6
                    Layout.alignment: Qt.AlignVCenter
                    border.color: Theme.chipBorder
                    border.width: 1

                    Row {
                        id: statsRow
                        anchors.centerIn: parent
                        spacing: 12

                        NetworkWidget {}
                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.15); anchors.verticalCenter: parent.verticalCenter }
                        VolumeWidget {}
                        MicWidget {}
                        EqWidget {}
                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.15); anchors.verticalCenter: parent.verticalCenter }
                        MemoryWidget {}
                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.15); anchors.verticalCenter: parent.verticalCenter }
                        CpuWidget {}
                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.15); anchors.verticalCenter: parent.verticalCenter }
                        ClockWidget {}
                        Rectangle { width: 1; height: 16; color: Qt.rgba(1,1,1,0.15); anchors.verticalCenter: parent.verticalCenter }

                        // Power button — fa-power-off 
                        Item {
                            width: 22
                            height: Theme.barHeight

                            Text {
                                anchors.centerIn: parent
                                text: ""
                                color: pHov.hovered ? Theme.danger : Theme.muted
                                font.pixelSize: Theme.fontMd
                                font.family: Theme.fontMono

                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: PowerState.visible = true
                            }
                        }
                    }
                }
            }
        }
    }
}
