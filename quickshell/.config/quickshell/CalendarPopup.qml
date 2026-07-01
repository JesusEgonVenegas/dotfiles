import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// Calendar panel — opened by clicking the ClockWidget or via the GlobalShortcut
// in shell.qml. Left: month grid (event dots, click a day to filter). Right:
// agenda from khal/Google + checkable Obsidian todos + a quick-add line that
// routes to `khal new` or the todo note. Data lives in CalendarState.
Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: CalendarState.visible

            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            aboveWindows: true
            color: Qt.rgba(0, 0, 0, 0.45)

            // Click-out closes.
            MouseArea { anchors.fill: parent; onClicked: CalendarState.close() }

            // Esc closes from anywhere in the panel.
            Item {
                anchors.fill: parent
                focus: CalendarState.visible
                Keys.onEscapePressed: CalendarState.close()
            }

            onVisibleChanged: if (visible) quickInput.forceActiveFocus()

            // ── Panel, anchored top-right under the bar ─────────────────────
            Rectangle {
                id: panel
                anchors { top: parent.top; right: parent.right
                          topMargin: Theme.barHeight + 6; rightMargin: 8 }
                width: 660
                height: 470
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)

                // Swallow clicks so they don't fall through to the close overlay.
                MouseArea { anchors.fill: parent }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // ══════════ LEFT: month grid ══════════
                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 10

                        // Month nav
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: CalendarState.monthLabel
                                color: Theme.fg
                                font.pixelSize: Theme.fontMd
                                font.weight: Theme.fontWeight
                                font.family: Theme.fontUi
                                Layout.fillWidth: true
                            }
                            NavBtn { glyph: "‹"; onClicked: CalendarState.prevMonth() }   // prev month
                            NavBtn { glyph: "•"; onClicked: CalendarState.resetMonth() }  // jump to today
                            NavBtn { glyph: "›"; onClicked: CalendarState.nextMonth() }   // next month
                        }

                        // Weekday headers (Mon-first)
                        Grid {
                            Layout.fillWidth: true
                            columns: 7
                            Repeater {
                                model: ["M", "T", "W", "T", "F", "S", "S"]
                                Item {
                                    width: 300 / 7; height: 20
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontXs
                                        font.family: Theme.fontMono
                                    }
                                }
                            }
                        }

                        // Day cells
                        Grid {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 2
                            columnSpacing: 2
                            Repeater {
                                model: CalendarState.cells
                                Item {
                                    width: 300 / 7; height: 36
                                    visible: true

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 32; height: 30
                                        radius: Theme.radiusSm
                                        visible: modelData.day > 0
                                        color: modelData.isToday
                                            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                                            : cellHov.hovered
                                                ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                                        border.width: modelData.isSelected ? 1 : 0
                                        border.color: Theme.accentAlt

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.day > 0 ? modelData.day : ""
                                            color: modelData.isToday ? Theme.accent : Theme.fg
                                            font.pixelSize: Theme.fontSm
                                            font.family: Theme.fontMono
                                            font.weight: modelData.isToday ? Theme.fontWeight : Font.Normal
                                        }

                                        // Event dot
                                        Rectangle {
                                            visible: modelData.hasEvents === true
                                            width: 4; height: 4; radius: 2
                                            color: Theme.accentAlt
                                            anchors { bottom: parent.bottom; bottomMargin: 3
                                                      horizontalCenter: parent.horizontalCenter }
                                        }

                                        HoverHandler { id: cellHov; enabled: modelData.day > 0
                                                       cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: modelData.day > 0
                                            onClicked: CalendarState.selectDay(modelData.dateStr)
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }   // push grid to top
                    }

                    // Divider
                    Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1
                                color: Qt.rgba(1, 1, 1, 0.10) }

                    // ══════════ RIGHT: agenda + todos + quick-add ══════════
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8

                        // Agenda header
                        Text {
                            text: CalendarState.selectedDate.length > 0
                                ? Qt.formatDate(new Date(CalendarState.selectedDate), "ddd d MMM")
                                : "Upcoming"
                            color: Theme.accent
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }

                        // Agenda list
                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            clip: true
                            spacing: 4
                            model: CalendarState.agenda

                            delegate: RowLayout {
                                width: ListView.view.width
                                spacing: 8
                                HoverHandler { id: agHov }
                                Text {
                                    text: modelData.time.length > 0 ? modelData.time : "all-day"
                                    color: Theme.accentAlt
                                    font.pixelSize: Theme.fontXs
                                    font.family: Theme.fontMono
                                    Layout.preferredWidth: 56
                                }
                                Text {
                                    text: (CalendarState.selectedDate.length === 0
                                            ? Qt.formatDate(new Date(modelData.date), "d MMM ") : "")
                                          + modelData.title
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                // Delete (×) — appears on row hover. Read-only
                                // calendars (holidays) are refused server-side.
                                Text {
                                    text: "×"
                                    visible: agHov.hovered
                                    color: delHov.hovered ? Theme.danger : Theme.muted
                                    font.pixelSize: Theme.fontMd
                                    font.family: Theme.fontUi
                                    Layout.preferredWidth: 16
                                    horizontalAlignment: Text.AlignHCenter
                                    HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: CalendarState.deleteEvent(modelData.uid)
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: CalendarState.agenda.length === 0
                                text: "nothing scheduled"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontUi
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.10) }

                        // Todos header
                        Text {
                            text: "Todos"
                            color: Theme.accent
                            font.pixelSize: Theme.fontSm
                            font.weight: Theme.fontWeight
                            font.family: Theme.fontMono
                        }

                        // Todos list
                        ListView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: CalendarState.todos

                            delegate: RowLayout {
                                width: ListView.view.width
                                spacing: 8

                                // Checkbox
                                Rectangle {
                                    width: 16; height: 16; radius: 4
                                    color: modelData.done
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.85)
                                        : "transparent"
                                    border.width: 1
                                    border.color: modelData.done ? Theme.accent : Theme.muted
                                    Text {
                                        anchors.centerIn: parent
                                        visible: modelData.done
                                        text: "✓"
                                        color: Theme.bg
                                        font.pixelSize: Theme.fontXs
                                        font.family: Theme.fontMono
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: CalendarState.toggleTodo(modelData.line)
                                    }
                                }

                                Text {
                                    text: modelData.text
                                    color: modelData.done ? Theme.muted : Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    font.strikeout: modelData.done
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: CalendarState.todos.length === 0
                                text: "no todos"
                                color: Theme.muted
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontUi
                            }
                        }

                        // ── Quick-add line ──────────────────────────────────
                        Rectangle {
                            id: quickAdd
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            radius: Theme.radiusSm
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06)
                            border.width: 1
                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)

                            property bool eventMode: true    // true = event, false = todo
                            function submit() {
                                if (eventMode) CalendarState.quickAddEvent(quickInput.text)
                                else           CalendarState.quickAddTodo(quickInput.text)
                                quickInput.text = ""
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 6
                                spacing: 8

                                TextInput {
                                    id: quickInput
                                    Layout.fillWidth: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    clip: true
                                    Keys.onEscapePressed: CalendarState.close()
                                    Keys.onTabPressed: quickAdd.eventMode = !quickAdd.eventMode
                                    Keys.onReturnPressed: quickAdd.submit()
                                    Keys.onEnterPressed:  quickAdd.submit()

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: quickInput.text.length === 0
                                        text: quickAdd.eventMode ? "e.g. tomorrow 14:00 Dentist…" : "new todo…"
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontSm
                                        font.family: Theme.fontUi
                                    }
                                }

                                // Mode pill (click to toggle)
                                Rectangle {
                                    Layout.preferredWidth: modeText.implicitWidth + 16
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: Qt.rgba(Theme.accentAlt.r, Theme.accentAlt.g, Theme.accentAlt.b, 0.18)
                                    Text {
                                        id: modeText
                                        anchors.centerIn: parent
                                        text: quickAdd.eventMode ? "event" : "todo"
                                        color: Theme.accentAlt
                                        font.pixelSize: Theme.fontXs
                                        font.family: Theme.fontMono
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { quickAdd.eventMode = !quickAdd.eventMode
                                                     quickInput.forceActiveFocus() }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Enter add · Tab switch event/todo · Esc close"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                        }
                    }
                }
            }
        }
    }

    // Small square nav button used in the month header.
    component NavBtn: Rectangle {
        property string glyph: ""
        signal clicked()
        implicitWidth: 26; implicitHeight: 26; radius: Theme.radiusSm
        color: nbHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: nbHov.hovered ? Theme.accent : Theme.fg
            font.pixelSize: Theme.fontLg
            font.weight: Theme.fontWeight
            font.family: Theme.fontUi
        }
        HoverHandler { id: nbHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }
}
