import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Themed screenshot menu (replaces the rofi picker). Opened with Print.
// ↑/↓ or 1-8 to choose, Enter to run, Esc/click-outside to close.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: ScreenshotState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            // Exclusive = compositor hands us keyboard focus immediately on open,
            // so arrow/number keys work without clicking first. (focusable:true maps
            // to OnDemand, which Hyprland only focuses on click — the bug.)
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.78)

            onVisibleChanged: if (visible) { list.currentIndex = 0; keys.forceActiveFocus() }

            MouseArea { anchors.fill: parent; onClicked: ScreenshotState.close() }

            Rectangle {
                anchors.centerIn: parent
                width: 360
                implicitHeight: col.implicitHeight + 28
                radius: Theme.radiusSm
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                MouseArea { anchors.fill: parent }   // swallow clicks inside

                FocusScope {
                    id: keys
                    anchors.fill: parent
                    focus: true

                    function runCurrent() {
                        const a = ScreenshotState.actions[list.currentIndex]
                        if (a) ScreenshotState.run(a.mode)
                    }

                    Keys.onEscapePressed: ScreenshotState.close()
                    Keys.onUpPressed:   list.decrementCurrentIndex()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onReturnPressed: runCurrent()
                    Keys.onEnterPressed:  runCurrent()
                    Keys.onPressed: (e) => {
                        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                            const i = e.key - Qt.Key_1
                            if (i < ScreenshotState.actions.length) { list.currentIndex = i; runCurrent() }
                            e.accepted = true
                        }
                    }

                    ColumnLayout {
                        id: col
                        anchors { fill: parent; margins: 14 }
                        spacing: 8

                        Text {
                            text: "// SCREENSHOT"
                            color: Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }

                        ListView {
                            id: list
                            Layout.fillWidth: true
                            implicitHeight: contentHeight
                            interactive: false
                            model: ScreenshotState.actions
                            currentIndex: 0

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 34
                                radius: Theme.radiusSm
                                color: index === list.currentIndex
                                       ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                       : (hov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
                                                      : "transparent")

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                    spacing: 10

                                    Text {
                                        text: (index + 1).toString()
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontXs
                                        font.family: Theme.fontMono
                                    }
                                    Text {
                                        text: modelData.label
                                        color: Theme.fg
                                        font.pixelSize: Theme.fontSm
                                        font.family: Theme.fontUi
                                        Layout.fillWidth: true
                                    }
                                }

                                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { list.currentIndex = index; ScreenshotState.run(modelData.mode) }
                                }
                            }
                        }

                        Text {
                            text: "↑↓ / 1-8 · Enter · Esc"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                        }
                    }
                }
            }
        }
    }
}
