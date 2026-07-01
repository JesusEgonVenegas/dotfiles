pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property bool    visible: false
    property string  title:   ""
    property string  body:    ""
    property real    triggerX: 0   // screen center-x of the widget that triggered this
    property color   accent:  Theme.accent  // per-tooltip title/border tint
    property bool    rich:    false          // render body as StyledText (HTML markup)

    // accentColor + rich are optional; callers that omit them get the default
    // green accent and plain-text body, so existing tooltips are unaffected.
    function show(t, b, x, accentColor, richBody) {
        hideTimer.stop()
        title    = t
        body     = (b !== undefined && b !== "") ? b : ""
        triggerX = x || 0
        accent   = accentColor ? accentColor : Theme.accent
        rich     = richBody === true
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
