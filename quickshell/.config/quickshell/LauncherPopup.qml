import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Application launcher. Opened via the GlobalShortcut in shell.qml (Super+D).
// Type to filter, Up/Down to move, Enter to launch, Esc to close. Replaces rofi.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: LauncherState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive  // focus on open, no click needed
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.78)

            // Click outside the panel closes.
            MouseArea { anchors.fill: parent; onClicked: LauncherState.close() }

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

                // Calculator mode: a leading "=" evaluates a math expression.
                property bool calcMode: search.text.trim().charAt(0) === "="
                property string calcResult: calcMode ? evalExpr(search.text.trim().slice(1)) : ""
                function evalExpr(e) {
                    const s = (e || "").trim()
                    if (s.length === 0) return ""
                    if (!/^[-0-9.+*/%()\s]*$/.test(s)) return "…"   // digits/operators only — no code exec
                    try {
                        const r = (Function("return (" + s + ")"))()
                        return (r === undefined || r === null || (typeof r === "number" && !isFinite(r)))
                               ? "…" : String(r)
                    } catch (err) { return "…" }
                }

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
                            text: "// RUN"
                            color: Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: panel.calcMode ? "= calc" : LauncherState.filtered.length + " apps"
                            color: panel.calcMode ? Theme.accentAlt : Theme.muted
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
                            text: "Search apps…  ·  = for calculator"
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
                            onTextChanged: { LauncherState.query = text; list.currentIndex = 0 }

                            Keys.onEscapePressed: LauncherState.close()
                            Keys.onUpPressed:   list.decrementCurrentIndex()
                            Keys.onDownPressed: list.incrementCurrentIndex()
                            // Vim-style nav while typing: Ctrl+K / Ctrl+J
                            Keys.onPressed: (e) => {
                                if (e.modifiers & Qt.ControlModifier) {
                                    if (e.key === Qt.Key_K) { list.decrementCurrentIndex(); e.accepted = true }
                                    else if (e.key === Qt.Key_J) { list.incrementCurrentIndex(); e.accepted = true }
                                    else if (e.key === Qt.Key_N) { list.incrementCurrentIndex(); e.accepted = true }
                                    else if (e.key === Qt.Key_P) { list.decrementCurrentIndex(); e.accepted = true }
                                }
                            }
                            function activate() {
                                if (panel.calcMode) {
                                    if (panel.calcResult.length && panel.calcResult !== "…")
                                        Quickshell.execDetached(["sh", "-c",
                                            "printf %s '" + panel.calcResult + "' | wl-copy"])
                                    LauncherState.close()
                                    return
                                }
                                LauncherState.launch(LauncherState.filtered[list.currentIndex])
                            }
                            Keys.onReturnPressed: activate()
                            Keys.onEnterPressed:  activate()
                        }
                    }

                    // App list
                    ListView {
                        id: list
                        visible: !panel.calcMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: LauncherState.filtered
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        highlightMoveDuration: 0
                        // Keep the selected row scrolled into view during keyboard nav.
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 44
                            radius: Theme.radiusSm
                            color: index === list.currentIndex
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                   : (hov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.07)
                                                  : "transparent")

                            RowLayout {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                spacing: 10

                                Image {
                                    source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                                    sourceSize.width: 28
                                    sourceSize.height: 28
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name || ""
                                        color: Theme.fg
                                        font.pixelSize: Theme.fontSm
                                        font.family: Theme.fontUi
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text.length > 0
                                        text: modelData.genericName || modelData.comment || ""
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontXs
                                        font.family: Theme.fontUi
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }

                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: { list.currentIndex = index; LauncherState.launch(modelData) }
                            }
                        }

                        // Empty state
                        Text {
                            anchors.centerIn: parent
                            visible: LauncherState.filtered.length === 0
                            text: "No matches"
                            color: Theme.muted
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontUi
                        }
                    }

                    // Calculator result (shown instead of the list when in "=" mode)
                    Rectangle {
                        visible: panel.calcMode
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.06)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.22)

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 32
                            spacing: 6
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: search.text.trim().slice(1).trim() || "…"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontMono
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "= " + (panel.calcResult || "…")
                                color: Theme.accentAlt
                                font.pixelSize: Theme.fontXl
                                font.weight: Theme.fontWeight
                                font.family: Theme.fontMono
                            }
                        }
                    }

                    // Footer hint
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: panel.calcMode ? "Enter copy result · Esc close"
                                                 : "↑↓ move · Enter launch · Esc close"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
