// MicWidget.qml — bar indicator for the default input (mic).
// Glyph is green while the mic is live, red when muted. Left-click toggles
// mute (quick mute for calls); right-click opens the full audio popup.
import QtQuick

Item {
    id: root
    implicitWidth: micRow.implicitWidth
    height: Theme.barHeight

    property bool muted: Volume.micMuted
    property color micColor: root.muted ? Theme.danger : Theme.accent

    Behavior on micColor { ColorAnimation { duration: 300 } }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                VolumeState.triggerX = root.mapToGlobal(root.width / 2, 0).x
                VolumeState.popupOpen = !VolumeState.popupOpen
            } else {
                Volume.toggleMicMute()
            }
        }
    }

    // Shares the "Audio" tooltip with VolumeWidget — it already renders both
    // Out and In rows straight from Volume/Pipewire, so it stays live on its own.
    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                TooltipState.show("Audio", "", root.mapToGlobal(root.width / 2, 0).x,
                                   undefined, false, true)
            } else {
                TooltipState.hide()
            }
        }
    }

    Row {
        id: micRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.muted ? "󰍭" : "󰍬"
            color: root.micColor
            font.pixelSize: Theme.fontLg
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
