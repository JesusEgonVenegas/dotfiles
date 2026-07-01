pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Singleton {
    id: root

    property var currentPlayer: {
        const vals = Mpris.players.values
        return vals.find(p => p.playbackState === MprisPlaybackState.Playing)
            ?? vals.find(p => p.playbackState === MprisPlaybackState.Paused)
            ?? (vals.length > 0 ? vals[0] : null)
    }

    property bool widgetHovered: false
    property bool popupHovered:  false
    property bool popupOpen:     false   // actual visibility — driven by the timer below

    property real triggerX: 0

    // Open immediately; close only after a delay so the mouse has
    // time to travel from the bar widget down to the popup card.
    onWidgetHoveredChanged: _update()
    onPopupHoveredChanged:  _update()

    function _update() {
        if (widgetHovered || popupHovered) {
            closeTimer.stop()
            popupOpen = true
        } else {
            closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 350   // ms — enough time to move mouse from bar to popup
        onTriggered: root.popupOpen = false
    }
}
