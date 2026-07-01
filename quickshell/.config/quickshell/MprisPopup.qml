import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: popup
            required property var modelData
            screen: modelData
            visible: MprisState.popupOpen

            anchors { top: true; right: true }
            margins {
                right: {
                    const sw = modelData.width
                    const pw = 300
                    const cx = MprisState.triggerX - modelData.x
                    if (cx <= 0) return 10
                    return Math.max(6, Math.min(sw - pw - 6, sw - cx - pw / 2))
                }
            }

            color: "transparent"
            exclusiveZone: 0
            implicitWidth: 300
            implicitHeight: card.implicitHeight

            property var player: MprisState.currentPlayer

            // Live position — polls every second while playing
            property real pos: 0
            Timer {
                interval: 1000
                running: popup.visible &&
                         popup.player?.playbackState === MprisPlaybackState.Playing
                repeat: true
                triggeredOnStart: true
                onTriggered: popup.pos = popup.player?.position ?? 0
            }
            onPlayerChanged: pos = player?.position ?? 0

            function fmt(secs) {
                const s = Math.floor(secs ?? 0)
                return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0")
            }

            Rectangle {
                id: card
                width: parent.width
                implicitHeight: col.implicitHeight + 20
                radius: Theme.radiusSm
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
                border.width: 1

                HoverHandler {
                    onHoveredChanged: MprisState.popupHovered = hovered
                }

                ColumnLayout {
                    id: col
                    anchors { fill: parent; margins: 12 }
                    spacing: 12

                    // ── Art + track info ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Album art (or placeholder)
                        Rectangle {
                            width: 72; height: 72
                            radius: 4
                            clip: true
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)

                            Image {
                                anchors.fill: parent
                                source: popup.player?.trackArtUrl ?? ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                smooth: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: (popup.player?.trackArtUrl ?? "") === ""
                                text: ""   // fa-music
                                color: Theme.accent
                                font.pixelSize: 28
                                font.family: Theme.fontMono
                            }
                        }

                        // Title / artist / album
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            Text {
                                text: popup.player?.trackTitle ?? "—"
                                color: Theme.fg
                                font.pixelSize: Theme.fontMd
                                font.weight: Theme.fontWeight
                                font.family: Theme.fontUi
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: popup.player?.trackArtist ?? ""
                                color: Theme.accent
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontUi
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }

                            Text {
                                text: popup.player?.trackAlbum ?? ""
                                color: Theme.muted
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontUi
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: text !== ""
                            }

                            // Player app name (e.g. "Firefox", "Spotify")
                            Text {
                                text: popup.player?.identity ?? ""
                                color: Theme.muted
                                opacity: 0.6
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontUi
                                Layout.fillWidth: true
                                visible: text !== ""
                            }
                        }
                    }

                    // ── Progress ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Item {
                            Layout.fillWidth: true
                            height: 5

                            property real frac: {
                                const len = popup.player?.length ?? 0
                                return len > 0 ? Math.min(1, popup.pos / len) : 0
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 3
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)

                                Rectangle {
                                    width: parent.width * parent.parent.frac
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent
                                    Behavior on width { SmoothedAnimation { velocity: 80 } }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeHorCursor
                                onClicked: mouse => {
                                    const len = popup.player?.length ?? 0
                                    if (len > 0 && popup.player) {
                                        const target = (mouse.x / width) * len
                                        popup.player.seek(target - popup.pos)
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: popup.fmt(popup.pos)
                                color: Theme.muted
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontMono
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: popup.fmt(popup.player?.length)
                                color: Theme.muted
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontMono
                            }
                        }
                    }

                    // ── Controls ──────────────────────────────────────────
                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 28

                        Text {
                            text: ""   // fa-step-backward
                            color: Theme.fg
                            font.pixelSize: Theme.fontLg
                            font.family: Theme.fontMono
                            anchors.verticalCenter: parent.verticalCenter
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: popup.player?.previous() }
                        }

                        Text {
                            text: popup.player?.playbackState === MprisPlaybackState.Playing
                                  ? ""   // fa-pause
                                  : ""   // fa-play
                            color: Theme.accent
                            font.pixelSize: Theme.fontXl
                            font.family: Theme.fontMono
                            anchors.verticalCenter: parent.verticalCenter
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: popup.player?.togglePlaying() }
                        }

                        Text {
                            text: ""   // fa-step-forward
                            color: Theme.fg
                            font.pixelSize: Theme.fontLg
                            font.family: Theme.fontMono
                            anchors.verticalCenter: parent.verticalCenter
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: popup.player?.next() }
                        }
                    }
                }
            }
        }
    }
}
