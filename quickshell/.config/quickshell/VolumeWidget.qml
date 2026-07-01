import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: root
    implicitWidth: volRow.implicitWidth
    height: Theme.barHeight

    property string volIcon: Volume.muted       ? "󰖁"
                           : Volume.volume >= 66 ? "󰕾"
                           : Volume.volume >= 33 ? "󰖀"
                           : "󰕿"

    property color volColor: Volume.muted ? Theme.muted : Theme.busy

    Behavior on volColor { ColorAnimation { duration: 300 } }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            VolumeState.triggerX = root.mapToGlobal(root.width / 2, 0).x
            VolumeState.popupOpen = !VolumeState.popupOpen
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: wheelEvent => {
            if (!Volume.sink) return
            const step = 0.05
            if (wheelEvent.angleDelta.y > 0)
                Volume.sink.audio.volume = Math.min(1.0, Volume.sink.audio.volume + step)
            else
                Volume.sink.audio.volume = Math.max(0.0, Volume.sink.audio.volume - step)
        }
    }

    Row {
        id: volRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.volIcon
            color: root.volColor
            font.pixelSize: Theme.fontLg
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Volume.muted ? "mute" : Volume.volume + "%"
            color: root.volColor
            font.pixelSize: Theme.fontMd
            font.weight: Theme.fontWeight
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
