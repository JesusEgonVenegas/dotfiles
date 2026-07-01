pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root
    property var active: []

    function add(n) {
        active = [...active, n]
    }

    function dismiss(n) {
        n.dismiss()   // tells the app the user closed it
        active = active.filter(x => x !== n)
    }

    function expire(n) {
        n.expire()    // tells the app it timed out
        active = active.filter(x => x !== n)
    }
}
