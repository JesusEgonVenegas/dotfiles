import QtQuick

Item {
    id: root
    implicitWidth: clockRow.implicitWidth
    height: Theme.barHeight

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: hovered
            ? TooltipState.show(Time.timeOnly, Time.dateOnly,
                                root.mapToGlobal(root.width / 2, 0).x)
            : TooltipState.hide()
    }

    // Click → open the calendar / agenda / todos panel.
    MouseArea {
        anchors.fill: parent
        onClicked: { TooltipState.hide(); CalendarState.toggle() }
    }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 7

        Text {
            text: ""
            color: Theme.accent
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Time.timeOnly
            color: Theme.fg
            font.pixelSize: Theme.fontMd
            font.weight: Theme.fontWeight
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: "·"
            color: Theme.accent
            font.pixelSize: Theme.fontMd
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Qt.formatDateTime(Time.now, "ddd d MMM")
            color: Theme.fg
            font.pixelSize: Theme.fontMd
            font.weight: Theme.fontWeight
            font.family: Theme.fontUi
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
