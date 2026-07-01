import QtQuick
import Quickshell.Services.SystemTray

Row {
    id: root
    property var window: null

    spacing: 2
    height: Theme.barHeight

    Repeater {
        model: SystemTray.items

        Item {
            id: trayItem
            required property SystemTrayItem modelData

            width: 24
            height: Theme.barHeight

            Image {
                anchors.centerIn: parent
                source: modelData.icon
                width: 18
                height: 18
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
                onHoveredChanged: {
                    if (hovered) {
                        const t = modelData.tooltipTitle || modelData.title || modelData.id
                        TooltipState.show(t, modelData.tooltipDescription || "",
                                          trayItem.mapToGlobal(trayItem.width / 2, 0).x)
                    } else {
                        TooltipState.hide()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate()
                    else if (modelData.hasMenu)
                        modelData.display(root.window, mouse.x, mouse.y)
                }
            }
        }
    }
}
