import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

Item {
    Layout.fillWidth: true
    Layout.preferredHeight: Theme.barHeight

    Rectangle {
        id: sep
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 16
        color: Theme.muted
        opacity: 0.5
    }

    Text {
        id: title
        anchors.left: sep.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        wrapMode: Text.NoWrap
        text: "Desktop"
        color: Theme.fg
        font.pixelSize: Theme.fontMd
        font.weight: Theme.fontWeight
        font.family: Theme.fontUi
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activewindow") return
            const parts = ev.parse(2)
            title.text = parts[1] || parts[0] || "Desktop"
        }
    }
}
