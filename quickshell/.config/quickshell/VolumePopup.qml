import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: VolumeState.popupOpen

            anchors { top: true; right: true }
            margins {
                right: {
                    const sw = modelData.width
                    const pw = 290
                    const cx = VolumeState.triggerX - modelData.x
                    if (cx <= 0) return 10
                    return Math.max(6, Math.min(sw - pw - 6, sw - cx - pw / 2))
                }
            }

            color: "transparent"
            implicitWidth: 290
            implicitHeight: card.implicitHeight

            // ── Card ──────────────────────────────────────────────────────
            Rectangle {
                id: card
                width: parent.width
                implicitHeight: col.implicitHeight + 24
                radius: Theme.radiusLg
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                border.width: 1

                layer.enabled: true

                ColumnLayout {
                    id: col
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 12
                    }
                    spacing: 0

                    // ── Header row ─────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10

                        Text {
                            text: "Volume"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1
                        }

                        Item { Layout.fillWidth: true }

                        // Mute toggle
                        Text {
                            text: Volume.muted ? "󰖁" : "󰕾"
                            color: Volume.muted ? Theme.muted : Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.family: Theme.fontMono

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (Volume.sink && Volume.sink.audio)
                                        Volume.sink.audio.muted = !Volume.sink.audio.muted
                                }
                            }
                        }
                    }

                    // ── Volume slider ──────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 16
                        spacing: 10

                        Text {
                            text: Volume.muted       ? "󰖁"
                                : Volume.volume >= 66 ? "󰕾"
                                : Volume.volume >= 33 ? "󰖀"
                                : "󰕿"
                            color: Volume.muted ? Theme.muted : Theme.busy
                            font.pixelSize: Theme.fontLg
                            font.family: Theme.fontMono
                        }

                        // Custom slider
                        Item {
                            id: sliderTrack
                            Layout.fillWidth: true
                            height: 20

                            property real fraction: Volume.volume / 100

                            // Track background
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)

                                // Filled portion
                                Rectangle {
                                    width: parent.width * sliderTrack.fraction
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent

                                    Behavior on width {
                                        SmoothedAnimation { velocity: 200 }
                                    }
                                }
                            }

                            // Handle
                            Rectangle {
                                id: handle
                                width: 14; height: 14; radius: 7
                                color: Theme.accent
                                y: (parent.height - height) / 2
                                x: sliderTrack.fraction * (parent.width - width)

                                Behavior on x {
                                    SmoothedAnimation { velocity: 200 }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeHorCursor
                                function apply(mx) {
                                    var f = Math.max(0, Math.min(1, mx / parent.width))
                                    if (Volume.sink && Volume.sink.audio)
                                        Volume.sink.audio.volume = f
                                }
                                onClicked: mouse => apply(mouse.x)
                                onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
                            }
                        }

                        Text {
                            text: Volume.volume + "%"
                            color: Theme.fg
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontMono
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── Divider ────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                        Layout.bottomMargin: 10
                    }

                    // ── Output devices header ──────────────────────────────
                    Text {
                        text: "Output Devices"
                        color: Theme.muted
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontUi
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                        Layout.bottomMargin: 6
                    }

                    // ── Sink list ──────────────────────────────────────────
                    Repeater {
                        model: {
                            if (!Pipewire.ready) return []
                            // Only include nodes whose name starts with a known
                            // OUTPUT prefix — this excludes webcam mics, headset
                            // mics, and any other input-only nodes that PipeWire
                            // surfaces as audio nodes.
                            const OUTPUT_PREFIXES = [
                                "alsa_output.", "bluez_output.",
                                "raop_output.", "tunnel-sink."
                            ]
                            const seen = new Set()
                            return Pipewire.nodes.values.filter(n => {
                                if (n.audio === null || n.isStream) return false
                                if (!OUTPUT_PREFIXES.some(p => n.name.startsWith(p))) return false
                                const key = n.description || n.name
                                if (seen.has(key)) return false
                                seen.add(key)
                                return true
                            })
                        }

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.radiusSm

                            property bool isDefault: modelData.id === Pipewire.defaultAudioSink?.id

                            color: isDefault
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                   : hov.hovered
                                     ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.05)
                                     : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: isDefault ? "󰓃" : "󰒃"
                                    color: isDefault ? Theme.accent : Theme.muted
                                    font.pixelSize: Theme.fontMd
                                    font.family: Theme.fontMono
                                }

                                Text {
                                    text: modelData.description || modelData.name
                                    color: isDefault ? Theme.accent : Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    // Optimistic update: point Volume at the new sink
                                    // immediately so the slider reflects its volume
                                    // without waiting for PipeWire to propagate.
                                    Volume.sink = modelData
                                    Volume.refresh()
                                    setDefault.running = true
                                }
                            }

                            Process {
                                id: setDefault
                                // Use node name, not numeric ID — pactl is more
                                // reliable than wpctl for profile switching.
                                command: ["pactl", "set-default-sink", modelData.name]
                                onRunningChanged: if (!running) Volume.refresh()
                            }
                        }
                    }
                }
            }

            // Close when clicking the bar area (outside the popup card)
            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: VolumeState.popupOpen = false
            }
        }
    }
}
