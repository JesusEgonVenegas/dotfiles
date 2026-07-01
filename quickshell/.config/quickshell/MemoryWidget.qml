import QtQuick

Item {
    id: root
    implicitWidth: memRow.implicitWidth
    height: Theme.barHeight

    property color dynamicColor: Memory.memUsage >= 85 ? Theme.danger
                                : Memory.memUsage >= 60 ? Theme.alert
                                : Theme.ok

    Behavior on dynamicColor { ColorAnimation { duration: 600 } }

    HoverHandler {
        onHoveredChanged: hovered
            ? TooltipState.show("Memory", Memory.memUsedStr + " / " + Memory.memTotalStr,
                                root.mapToGlobal(root.width / 2, 0).x)
            : TooltipState.hide()
    }

    Row {
        id: memRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: "󰍛"
            color: root.dynamicColor
            font.pixelSize: Theme.fontLg
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Memory.memUsage + "%"
            color: root.dynamicColor
            font.pixelSize: Theme.fontMd
            font.weight: Theme.fontWeight
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
