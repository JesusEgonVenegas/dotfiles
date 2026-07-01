import QtQuick

Item {
    id: root
    implicitWidth: netText.implicitWidth + 2
    height: Theme.barHeight

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                const label = !Network.connected ? "No network"
                            : Network.wired      ? "Ethernet"
                            : Network.ssid !== "" ? Network.ssid
                            : "WiFi"
                const detail = !Network.connected ? ""
                             : Network.wired       ? "Wired connection"
                             : Network.wifiSignal + "% signal"
                TooltipState.show(label, detail, root.mapToGlobal(root.width / 2, 0).x)
            } else {
                TooltipState.hide()
            }
        }
    }

    Text {
        id: netText
        anchors.centerIn: parent
        text: Network.icon
        color: Network.iconColor
        font.pixelSize: Theme.fontLg
        font.family: Theme.fontMono

        Behavior on color { ColorAnimation { duration: 300 } }
    }
}
