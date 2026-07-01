import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: PowerState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            focusable: true
            aboveWindows: true

            color: Qt.rgba(0, 0, 0, 0.78)

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                focus: true
                Keys.onEscapePressed: PowerState.visible = false
            }

            MouseArea {
                anchors.fill: parent
                onClicked: PowerState.visible = false
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "// SYSTEM"
                    color: Theme.accent
                    font.pixelSize: Theme.fontLg
                    font.weight: Theme.fontWeight
                    font.family: Theme.fontMono
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 14
                }

                Repeater {
                    model: [
                        { label: "Shutdown",  icon: "", cmd: ["systemctl", "poweroff"]         },
                        { label: "Reboot",    icon: "", cmd: ["systemctl", "reboot"]           },
                        { label: "Suspend",   icon: "", cmd: ["systemctl", "suspend"]          },
                        { label: "Logout",    icon: "", cmd: ["hyprctl", "dispatch", "exit"]  },
                        { label: "Lock",      icon: "", cmd: ["hyprlock"]                      },
                    ]

                    Rectangle {
                        required property var modelData
                        property var entry: modelData

                        Layout.alignment: Qt.AlignHCenter
                        width: 240
                        height: 46
                        radius: Theme.radiusSm
                        color: hov.hovered
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                               : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.04)
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                                              hov.hovered ? 0.55 : 0.20)
                        border.width: 1

                        Behavior on color       { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        MouseArea { anchors.fill: parent; onClicked: {} }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 14

                            Text {
                                text: entry.icon
                                color: hov.hovered ? Theme.accent : Theme.muted
                                font.pixelSize: Theme.fontMd
                                font.family: Theme.fontMono
                            }

                            Text {
                                text: entry.label
                                color: hov.hovered ? Theme.accent : Theme.fg
                                font.pixelSize: Theme.fontMd
                                font.weight: Theme.fontWeight
                                font.family: Theme.fontUi
                            }
                        }

                        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                PowerState.visible = false
                                cmd.running = true
                            }
                        }

                        Process {
                            id: cmd
                            command: entry.cmd
                        }
                    }
                }

                Text {
                    text: "ESC to cancel"
                    color: Theme.muted
                    font.pixelSize: Theme.fontXs
                    font.family: Theme.fontUi
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                }
            }
        }
    }
}
