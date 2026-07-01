pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool    visible: false
    property string  title:   ""
    property string  body:    ""
    property real    triggerX: 0   // screen center-x of the widget that triggered this

    function show(t, b, x) {
        hideTimer.stop()
        title    = t
        body     = (b !== undefined && b !== "") ? b : ""
        triggerX = x || 0
        visible  = true
    }

    function hide() {
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 120
        onTriggered: root.visible = false
    }
}
