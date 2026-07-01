import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Themed recording menu (replaces the rofi record-menu.sh). Opened with Super+R.
// While recording, collapses to a single red "Stop Recording" entry.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: RecordMenuState.visible

            // Shown items depend on whether a recording is currently active.
            property bool rec: RecordState.recording
            property var items: rec
                ? [{ label: "Stop Recording", stop: true }]
                : RecordMenuState.actions
            property color tint: rec ? Theme.danger : Theme.accent

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.78)

            onVisibleChanged: if (visible) { list.currentIndex = 0; keys.forceActiveFocus() }

            MouseArea { anchors.fill: parent; onClicked: RecordMenuState.close() }

            function activate(item) {
                if (!item) return
                if (item.stop) RecordMenuState.stopRec()
                else RecordMenuState.run(item.args)
            }

            Rectangle {
                anchors.centerIn: parent
                width: 360
                implicitHeight: col.implicitHeight + 28
                radius: Theme.radiusSm
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(win.tint.r, win.tint.g, win.tint.b, 0.4)

                MouseArea { anchors.fill: parent }   // swallow

                FocusScope {
                    id: keys
                    anchors.fill: parent
                    focus: true

                    Keys.onEscapePressed: RecordMenuState.close()
                    Keys.onUpPressed:   list.decrementCurrentIndex()
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onReturnPressed: win.activate(win.items[list.currentIndex])
                    Keys.onEnterPressed:  win.activate(win.items[list.currentIndex])
                    Keys.onPressed: (e) => {
                        if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                            const i = e.key - Qt.Key_1
                            if (i < win.items.length) { list.currentIndex = i; win.activate(win.items[i]) }
                            e.accepted = true
                        }
                    }

                    ColumnLayout {
                        id: col
                        anchors { fill: parent; margins: 14 }
                        spacing: 8

                        Text {
                            text: win.rec ? "// RECORDING" : "// RECORD"
                            color: win.tint
                            font.pixelSize: Theme.fontMd
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }

                        ListView {
                            id: list
                            Layout.fillWidth: true
                            implicitHeight: contentHeight
                            interactive: false
                            model: win.items
                            currentIndex: 0

                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: ListView.view.width
                                height: 34
                                radius: Theme.radiusSm
                                color: index === list.currentIndex
                                       ? Qt.rgba(win.tint.r, win.tint.g, win.tint.b, 0.18)
                                       : (hov.hovered ? Qt.rgba(win.tint.r, win.tint.g, win.tint.b, 0.07)
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
                                        color: modelData.stop ? Theme.danger : Theme.fg
                                        font.pixelSize: Theme.fontSm
                                        font.family: Theme.fontUi
                                        Layout.fillWidth: true
                                    }
                                }

                                HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { list.currentIndex = index; win.activate(modelData) }
                                }
                            }
                        }

                        Text {
                            text: "↑↓ · Enter · Esc"
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
