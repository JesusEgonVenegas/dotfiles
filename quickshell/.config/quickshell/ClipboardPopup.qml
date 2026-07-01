import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Clipboard history picker. Opened via the GlobalShortcut in shell.qml
// (Super+Shift+V). Type to filter, Up/Down to move, Enter to copy, Esc to close.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: ClipboardState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive  // focus on open, no click needed
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.78)

            // Click outside the panel closes.
            MouseArea { anchors.fill: parent; onClicked: ClipboardState.close() }

            // Focus the search box and reset selection whenever it opens.
            onVisibleChanged: if (visible) { search.text = ""; list.currentIndex = 0; search.forceActiveFocus() }

            Rectangle {
                id: panel
                anchors.centerIn: parent
                width: 640
                height: Math.min(parent.height * 0.7, 560)
                radius: Theme.radiusSm
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                // Swallow clicks inside the panel so they don't hit the closer.
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "// CLIPBOARD"
                            color: Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: ClipboardState.filtered.length + " items"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                        }
                    }

                    // Search field (TextInput — no QtQuick.Controls dependency)
                    Rectangle {
                        Layout.fillWidth: true
                        height: 34
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)

                        Text {
                            visible: search.text.length === 0
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: "Search clipboard…"
                            color: Theme.muted
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                        }

                        TextInput {
                            id: search
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.fg
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                            clip: true
                            focus: true
                            onTextChanged: { ClipboardState.query = text; list.currentIndex = 0 }

                            Keys.onEscapePressed: ClipboardState.close()
                            Keys.onUpPressed:   list.decrementCurrentIndex()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            function activate() {
                                const it = ClipboardState.filtered[list.currentIndex]
                                if (it) ClipboardState.copy(it.id)
                            }
                            Keys.onReturnPressed: activate()
                            Keys.onEnterPressed:  activate()
                        }
                    }

                    // History list
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ClipboardState.filtered
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            radius: Theme.radiusSm
                            color: index === list.currentIndex
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                   : (hov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
                                                  : "transparent")

                            Text {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: Text.AlignVCenter
                                text: modelData.preview
                                color: Theme.fg
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontUi
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { list.currentIndex = index; ClipboardState.copy(modelData.id) }
                            }
                        }

                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            visible: ClipboardState.filtered.length === 0
                            text: ClipboardState.entries.length === 0 ? "Clipboard history is empty" : "No matches"
                            color: Theme.muted
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                        }
                    }

                    // Footer hint
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "↑↓ move · Enter copy · Esc close"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "Clear all"
                            color: Theme.danger
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                            HoverHandler { id: clrHov; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: ClipboardState.wipe() }
                        }
                    }
                }
            }
        }
    }
}
