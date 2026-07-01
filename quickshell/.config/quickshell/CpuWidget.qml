import QtQuick

Item {
    id: root
    implicitWidth: cpuRow.implicitWidth
    height: Theme.barHeight

    property color dynamicColor: Cpu.cpuUsage >= 80 ? Theme.danger
                                : Cpu.cpuUsage >= 50 ? Theme.alert
                                : Theme.ok

    Behavior on dynamicColor { ColorAnimation { duration: 600 } }

    HoverHandler {
        onHoveredChanged: hovered
            ? TooltipState.show("CPU", Cpu.cpuUsage + "% — 2 s avg",
                                root.mapToGlobal(root.width / 2, 0).x)
            : TooltipState.hide()
    }

    Row {
        id: cpuRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: "󰻠"
            color: root.dynamicColor
            font.pixelSize: Theme.fontLg
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Cpu.cpuUsage + "%"
            color: root.dynamicColor
            font.pixelSize: Theme.fontMd
            font.weight: Theme.fontWeight
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
