// EqWidget.qml — bar indicator/quick-toggle for the headphone EQ (EasyEffects
// output preset). Glyph is accent-colored while an EQ curve is active, dimmed
// when off ("flat"). Left-click toggles EQ on/off; right-click opens the audio
// popup, where the full per-headphone preset list lives.
import QtQuick

Item {
    id: root
    implicitWidth: eqRow.implicitWidth
    height: Theme.barHeight

    readonly property bool eqOn: Volume.outputPreset !== "flat" && Volume.outputPreset !== ""
    property color eqColor: root.eqOn ? Theme.accent : Theme.muted

    Behavior on eqColor { ColorAnimation { duration: 300 } }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                VolumeState.triggerX = root.mapToGlobal(root.width / 2, 0).x
                VolumeState.popupOpen = !VolumeState.popupOpen
            } else {
                Volume.toggleEq()
            }
        }
    }

    // Reuse the shared "Audio" tooltip (same as MicWidget) — it already renders
    // Out/In rows straight from Volume/Pipewire.
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
        id: eqRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            // nf-md-tune (U+F062E) — horizontal EQ sliders
            text: "󰘮"
            color: root.eqColor
            font.pixelSize: Theme.fontLg
            font.family: Theme.fontMono
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
