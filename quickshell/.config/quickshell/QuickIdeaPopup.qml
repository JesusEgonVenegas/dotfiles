import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Quick-idea capture box. Opened via the GlobalShortcut in shell.qml
// (Super+Shift+I). Type a thought, Enter appends it to the Obsidian ideas note,
// Esc cancels. Native replacement for the old rofi quick-idea script.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: QuickIdeaState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.78)

            MouseArea { anchors.fill: parent; onClicked: QuickIdeaState.close() }
            onVisibleChanged: if (visible) { input.text = ""; input.forceActiveFocus() }

            Rectangle {
                anchors.centerIn: parent
                width: 560
                height: 132
                radius: Theme.radiusSm
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.35)

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "// QUICK IDEA"
                        color: Theme.accentAlt
                        font.pixelSize: Theme.fontMd
                        font.weight: Theme.fontWeight
                        font.family: Theme.fontMono
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 38
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.25)

                        Text {
                            visible: input.text.length === 0
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "Capture a thought → Obsidian…"
                            color: Theme.muted
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                        }

                        TextInput {
                            id: input
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                            clip: true
                            focus: true
                            Keys.onEscapePressed: QuickIdeaState.close()
                            Keys.onReturnPressed: QuickIdeaState.submit(text)
                            Keys.onEnterPressed:  QuickIdeaState.submit(text)
                        }
                    }

                    Text {
                        text: "Enter save · Esc cancel"
                        color: Theme.muted
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontUi
                    }
                }
            }
        }
    }
}
