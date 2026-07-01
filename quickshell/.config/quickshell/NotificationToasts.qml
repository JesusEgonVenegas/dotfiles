import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors { top: true; right: true }
            margins { right: 10 }

            color: "transparent"
            exclusiveZone: 0
            implicitWidth: 360
            implicitHeight: toastCol.implicitHeight
            visible: NotifState.active.length > 0

            Column {
                id: toastCol
                width: parent.width
                spacing: 6

                Repeater {
                    model: NotifState.active

                    delegate: Rectangle {
                        id: toast
                        required property var modelData
                        required property int index

                        property var notif: modelData

                        // Snapshot all display data immediately so reads never hit
                        // a potentially-stale QObject later.
                        property string snapImage:   ""
                        property string snapSummary: ""
                        property string snapBody:    ""
                        property string snapAppName: ""
                        property var    snapActions: []
                        property int    snapUrgency: NotificationUrgency.Normal

                        function snapshot() {
                            if (!notif) return
                            snapImage   = notif.image   ?? ""
                            snapSummary = notif.summary ?? ""
                            snapBody    = notif.body    ?? ""
                            snapAppName = notif.appName ?? ""
                            snapUrgency = notif.urgency ?? NotificationUrgency.Normal
                            snapActions = notif.actions ?? []
                        }

                        Component.onCompleted: snapshot()
                        onNotifChanged: snapshot()

                        visible: notif !== null && notif !== undefined

                        // If Discord (or any app) closes the notification via D-Bus
                        // while we still hold it tracked, remove it from our list so
                        // the delegate tears down cleanly.
                        Connections {
                            target: toast.notif
                            ignoreUnknownSignals: true
                            function onClosed(reason) {
                                NotifState.active = NotifState.active.filter(x => x !== toast.notif)
                            }
                        }

                        width: 360
                        implicitHeight: visible ? inner.implicitHeight + 16 : 0
                        radius: Theme.radiusSm
                        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                        border.width: 1
                        border.color: toast.snapUrgency === NotificationUrgency.Critical
                                      ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.7)
                                      : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)

                        // Left urgency accent strip
                        Rectangle {
                            visible: toast.visible
                            width: 3
                            height: parent.height
                            radius: parent.radius
                            color: toast.snapUrgency === NotificationUrgency.Critical ? Theme.danger
                                 : toast.snapUrgency === NotificationUrgency.Low      ? Theme.muted
                                 : Theme.accent
                        }

                        NumberAnimation on opacity {
                            from: 0; to: 1
                            duration: 200
                            easing.type: Easing.OutCubic
                        }

                        Timer {
                            // expireTimeout is in milliseconds (despite the docs saying
                            // "seconds"): notify-send --expire-time=4000 arrives as 4000.
                            // -1 = "server decides", 0 = "never expire" (freedesktop spec).
                            interval: {
                                if (!toast.notif) return 5000
                                if (toast.snapUrgency === NotificationUrgency.Critical) return 0
                                const t = toast.notif.expireTimeout
                                if (t < 0) return 5000      // app left it to us → 5s default
                                if (t === 0) return 0       // app explicitly wants it sticky
                                return Math.max(t, 1500)    // honour app's ms timeout, floor 1.5s
                            }
                            running: interval > 0 && toast.visible
                            onTriggered: if (toast.notif) NotifState.expire(toast.notif)
                        }

                        // Compact horizontal layout: small avatar left, text right
                        RowLayout {
                            id: inner
                            anchors {
                                fill: parent
                                leftMargin: 14; rightMargin: 10
                                topMargin: 8;  bottomMargin: 8
                            }
                            spacing: 10

                            // Avatar thumbnail — fixed 44×44, only shown when image present
                            Rectangle {
                                visible: toast.snapImage !== ""
                                width: 44
                                height: 44
                                radius: Theme.radiusSm
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                clip: true
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    source: toast.snapImage
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    mipmap: true
                                }
                            }

                            // Text stack + actions
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                // App name row with dismiss button
                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: toast.snapAppName !== "" ? toast.snapAppName : "Notification"
                                        color: Theme.accent
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Theme.fontWeight
                                        font.family: Theme.fontUi
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "✕"
                                        color: Theme.muted
                                        font.pixelSize: Theme.fontSm
                                        font.family: Theme.fontUi
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: if (toast.notif) NotifState.dismiss(toast.notif)
                                        }
                                    }
                                }

                                Text {
                                    visible: toast.snapSummary !== ""
                                    text: toast.snapSummary
                                    color: toast.snapUrgency === NotificationUrgency.Critical
                                           ? Theme.danger : Theme.fg
                                    font.pixelSize: Theme.fontMd
                                    font.weight: Theme.fontWeight
                                    font.family: Theme.fontUi
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: toast.snapBody !== ""
                                    text: toast.snapBody
                                    color: Theme.fg
                                    opacity: 0.75
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                // Action buttons
                                Row {
                                    spacing: 6
                                    visible: toast.snapActions.length > 0
                                    Layout.topMargin: 2

                                    Repeater {
                                        model: toast.snapActions

                                        Rectangle {
                                            required property var modelData
                                            property var action: modelData

                                            height: 22
                                            width: btnLabel.implicitWidth + 14
                                            radius: 3
                                            color: hov.hovered
                                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                                                   : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                                            border.width: 1

                                            Text {
                                                id: btnLabel
                                                anchors.centerIn: parent
                                                text: action?.text ?? ""
                                                color: Theme.accent
                                                font.pixelSize: Theme.fontXs
                                                font.weight: Theme.fontWeight
                                                font.family: Theme.fontUi
                                            }

                                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: {
                                                    if (action) action.invoke()
                                                    if (toast.notif) NotifState.dismiss(toast.notif)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
