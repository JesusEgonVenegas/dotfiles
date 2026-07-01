import QtQuick
import Quickshell.Services.Mpris

Item {
    id: root
    height: Theme.barHeight

    property var player: MprisState.currentPlayer
    property bool active: player !== null && (player.trackTitle ?? "") !== ""

    visible: active
    implicitWidth: active ? pill.implicitWidth : 0

    Behavior on implicitWidth { SmoothedAnimation { velocity: 300 } }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                MprisState.triggerX   = root.mapToGlobal(root.width / 2, 0).x
                MprisState.widgetHovered = true
            } else {
                MprisState.widgetHovered = false
            }
        }
    }

    Rectangle {
        id: pill
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: pillRow.implicitWidth + 20
        height: Theme.barHeight - 10
        radius: Theme.radiusSm
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b,
                       MprisState.popupOpen ? 0.14 : 0.08)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            // State icon
            Text {
                text: root.player?.playbackState === MprisPlaybackState.Playing
                      ? ""   // fa-music  (playing)
                      : ""   // fa-pause  (paused)
                color: Theme.accent
                font.pixelSize: Theme.fontSm
                font.family: Theme.fontMono
                anchors.verticalCenter: parent.verticalCenter
            }

            // Artist · Title
            Text {
                property string artist: root.player?.trackArtist ?? ""
                property string title:  root.player?.trackTitle  ?? ""
                text: artist !== "" ? (artist + " · " + title) : title
                color: Theme.fg
                font.pixelSize: Theme.fontSm
                font.weight: Theme.fontWeight
                font.family: Theme.fontUi
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // Scroll to skip
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheelEvent => {
            if (!root.player) return
            if (wheelEvent.angleDelta.y > 0) root.player.next()
            else root.player.previous()
        }
    }
}
