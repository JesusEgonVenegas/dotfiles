import Quickshell
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: TooltipState.visible

            anchors { top: true; right: true }
            margins {
                right: {
                    const sw = modelData.width
                    const pw = implicitWidth || 160
                    const cx = TooltipState.triggerX - modelData.x
                    if (cx <= 0) return 10
                    return Math.max(6, Math.min(sw - pw - 6, sw - cx - pw / 2))
                }
            }

            color: "transparent"
            implicitWidth: col.implicitWidth + 28
            implicitHeight: col.implicitHeight + 22

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusSm
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                border.color: Qt.rgba(TooltipState.accent.r, TooltipState.accent.g, TooltipState.accent.b, 0.30)
                border.width: 1

                ColumnLayout {
                    id: col
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: TooltipState.title
                        color: TooltipState.accent
                        font.pixelSize: Theme.fontMd
                        font.bold: true
                        font.family: Theme.fontMono
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        visible: TooltipState.body !== ""
                        text: TooltipState.body
                        textFormat: TooltipState.rich ? Text.StyledText : Text.PlainText
                        color: Theme.fg
                        font.pixelSize: Theme.fontMd
                        font.family: Theme.fontMono
                        lineHeight: 1.35
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
