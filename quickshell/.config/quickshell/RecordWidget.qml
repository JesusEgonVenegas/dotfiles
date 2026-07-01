import QtQuick
import Quickshell

// Screen-recording indicator. Hidden while idle; during a recording it expands
// into a red chip with a pulsing dot and a live mm:ss timer. Click to stop.
Item {
    id: root
    height: Theme.barHeight

    property bool active: RecordState.recording

    visible: active
    implicitWidth: active ? pill.implicitWidth : 0
    Behavior on implicitWidth { SmoothedAnimation { velocity: 300 } }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: pillRow.implicitWidth + 20
        height: Theme.barHeight - 10
        radius: Theme.radiusSm
        color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.12)
        border.color: Theme.danger
        border.width: 1

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 7

            // Pulsing record dot
            Rectangle {
                width: 9; height: 9; radius: 4.5
                color: Theme.danger
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: root.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.0;  duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: "REC " + RecordState.elapsedStr
                color: Theme.danger
                font.pixelSize: Theme.fontSm
                font.weight: Theme.fontWeight
                font.family: Theme.fontUi
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    MouseArea {
        anchors.fill: parent
        onClicked: RecordState.stop()   // Super+Shift+R also works
    }
}
