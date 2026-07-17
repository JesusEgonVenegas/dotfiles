import Quickshell
import Quickshell.Hyprland
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
            visible: VolumeState.popupOpen && Hyprland.focusedMonitor?.name === modelData.name

            // Full-screen transparent overlay so a click anywhere outside the
            // card is caught and dismisses the popup (matches ClipboardPopup).
            anchors { top: true; bottom: true; left: true; right: true }
            exclusiveZone: -1
            color: "transparent"

            // Click-away closer, behind the card.
            MouseArea { anchors.fill: parent; onClicked: VolumeState.popupOpen = false }

            // ── Card ──────────────────────────────────────────────────────
            Rectangle {
                id: card
                width: 290
                implicitHeight: col.implicitHeight + 24
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + 6
                anchors.rightMargin: {
                    const sw = modelData.width
                    const pw = 290
                    const cx = VolumeState.triggerX - modelData.x
                    if (cx <= 0) return 10
                    return Math.max(6, Math.min(sw - pw - 6, sw - cx - pw / 2))
                }
                radius: Theme.radiusLg
                color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.97)
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                border.width: 1

                layer.enabled: true

                // Swallow clicks on the card so they don't reach the closer behind.
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: col
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 12
                    }
                    spacing: 0

                    // ── Derived Pipewire state (re-evaluates as nodes change) ──
                    // The EasyEffects virtual "clean mic" source, present only
                    // while EasyEffects runs its input chain.
                    readonly property var eeSource: !Pipewire.ready ? null
                        : (Pipewire.nodes.values.find(n => n.name === "easyeffects_source") || null)

                    // First real hardware/virtual input that isn't EasyEffects —
                    // where the Studio FX toggle drops back to for "raw".
                    readonly property var rawInput: !Pipewire.ready ? null
                        : (Pipewire.nodes.values.find(n =>
                            n.audio !== null && !n.isStream && !n.isSink
                            && n.name !== "easyeffects_source") || null)

                    readonly property bool studioActive:
                        Pipewire.defaultAudioSource?.name === "easyeffects_source"

                    // Apps currently playing into a sink (per-app volume list).
                    readonly property var appStreams: !Pipewire.ready ? []
                        : Pipewire.nodes.values.filter(n =>
                            n.isStream
                            && n.properties
                            && n.properties["media.class"] === "Stream/Output/Audio")

                    // EasyEffects output sink — present only while EasyEffects is
                    // running its output chain, i.e. headphone EQ is available.
                    readonly property var eeSink: !Pipewire.ready ? null
                        : (Pipewire.nodes.values.find(n => n.name === "easyeffects_sink") || null)

                    // Curated headphone-EQ presets (EasyEffects output presets in
                    // ~/.local/share/easyeffects/output/). "flat" = EQ off.
                    readonly property var eqPresets: [
                        { preset: "flat",          label: "Off" },
                        { preset: "gpro-x",        label: "G Pro X · neutral" },
                        { preset: "gpro-x-smooth", label: "G Pro X · smooth" },
                        { preset: "bose-qc35",     label: "Bose QC35" },
                    ]

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

                        // Mute toggle — see Volume.toggleMute() for why this
                        // goes through pactl instead of a direct property write.
                        Text {
                            text: Volume.muted ? "󰖁" : "󰕾"
                            color: Volume.muted ? Theme.muted : Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.family: Theme.fontMono

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Volume.toggleMute()
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
                                onClicked: mouse => Volume.setVolume(mouse.x / parent.width)
                                onPositionChanged: mouse => { if (pressed) Volume.setVolume(mouse.x / parent.width) }
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
                                const key = n.nickname || n.description || n.name
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
                                    text: modelData.nickname || modelData.description || modelData.name
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

                    // ── Headphone EQ (EasyEffects output preset) ───────────
                    // Switches the EasyEffects output preset (AutoEq per-headphone
                    // curves + an "Off" passthrough). Hidden unless EasyEffects is
                    // running its output chain. See Volume.setOutputPreset().
                    Text {
                        visible: col.eeSink !== null
                        text: "Headphone EQ"
                        color: Theme.muted
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontUi
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                        Layout.topMargin: 14
                        Layout.bottomMargin: 6
                    }

                    Repeater {
                        model: col.eeSink ? col.eqPresets : []

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            implicitHeight: 32
                            radius: Theme.radiusSm

                            property bool active: Volume.outputPreset === modelData.preset

                            color: active
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                   : eqHov.hovered
                                     ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.05)
                                     : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    width: 8; height: 8; radius: 4
                                    color: active ? Theme.accent : Theme.muted
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.label
                                    color: active ? Theme.accent : Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            HoverHandler { id: eqHov; cursorShape: Qt.PointingHandCursor }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: Volume.setOutputPreset(modelData.preset)
                            }
                        }
                    }

                    // ── Divider ────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                        Layout.topMargin: 14
                        Layout.bottomMargin: 10
                    }

                    // ── Microphone header row ──────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10

                        Text {
                            text: "Microphone"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 1
                        }

                        Item { Layout.fillWidth: true }

                        // Mic mute toggle — pactl-routed, see Volume.toggleMicMute().
                        Text {
                            text: Volume.micMuted ? "󰍭" : "󰍬"
                            color: Volume.micMuted ? Theme.danger : Theme.accent
                            font.pixelSize: Theme.fontMd
                            font.family: Theme.fontMono

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Volume.toggleMicMute()
                            }
                        }
                    }

                    // ── Mic volume slider ──────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 8
                        spacing: 10

                        Text {
                            text: Volume.micMuted ? "󰍭" : "󰍬"
                            color: Volume.micMuted ? Theme.muted : Theme.accent
                            font.pixelSize: Theme.fontLg
                            font.family: Theme.fontMono
                        }

                        Item {
                            id: micTrack
                            Layout.fillWidth: true
                            height: 20

                            property real fraction: Volume.micVolume / 100

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)

                                Rectangle {
                                    width: parent.width * micTrack.fraction
                                    height: parent.height
                                    radius: parent.radius
                                    color: Theme.accent
                                    Behavior on width { SmoothedAnimation { velocity: 200 } }
                                }
                            }

                            Rectangle {
                                width: 14; height: 14; radius: 7
                                color: Theme.accent
                                y: (parent.height - height) / 2
                                x: micTrack.fraction * (parent.width - width)
                                Behavior on x { SmoothedAnimation { velocity: 200 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.SizeHorCursor
                                onClicked: mouse => Volume.setMicVolume(mouse.x / parent.width)
                                onPositionChanged: mouse => { if (pressed) Volume.setMicVolume(mouse.x / parent.width) }
                            }
                        }

                        Text {
                            text: Volume.micVolume + "%"
                            color: Theme.fg
                            font.pixelSize: Theme.fontSm
                            font.family: Theme.fontMono
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── Live input level meter ─────────────────────────────
                    // Peak from MicLevel (parec + mic-level.py) while the popup
                    // is open — set the MixPre gain knob so speech peaks land in
                    // the green/amber and hard peaks (red) stay rare.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 14
                        spacing: 10

                        Text {
                            text: "level"
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontUi
                            Layout.preferredWidth: 24
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 6
                            radius: 3
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)

                            Rectangle {
                                width: parent.width * Math.min(1, MicLevel.level / 100)
                                height: parent.height
                                radius: parent.radius
                                color: MicLevel.level > 88 ? Theme.danger
                                     : MicLevel.level > 62 ? Theme.busy
                                     : Theme.accent
                                Behavior on width { SmoothedAnimation { velocity: 400 } }
                            }
                        }

                        Text {
                            text: Math.round(MicLevel.level)
                            color: Theme.muted
                            font.pixelSize: Theme.fontXs
                            font.family: Theme.fontMono
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                        }
                    }

                    // ── Studio FX toggle ───────────────────────────────────
                    // Flips the default source between the raw hardware mic and
                    // the EasyEffects "clean mic" (gate/RNNoise/EQ/comp). Only
                    // shown when EasyEffects is actually running its input chain.
                    Rectangle {
                        visible: col.eeSource !== null
                        Layout.fillWidth: true
                        Layout.bottomMargin: 12
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: col.studioActive
                               ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                               : fxHov.hovered
                                 ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.05)
                                 : "transparent"
                        border.width: 1
                        border.color: col.studioActive
                                      ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.30)
                                      : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: col.studioActive ? Theme.accent : Theme.muted
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: "Studio FX  ·  EasyEffects"
                                color: col.studioActive ? Theme.accent : Theme.fg
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontUi
                                Layout.fillWidth: true
                            }

                            Text {
                                text: col.studioActive ? "ON" : "OFF"
                                color: col.studioActive ? Theme.accent : Theme.muted
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontMono
                            }
                        }

                        HoverHandler { id: fxHov; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (col.studioActive) {
                                    if (col.rawInput) Volume.setSource(col.rawInput.name)
                                } else {
                                    Volume.setSource("easyeffects_source")
                                }
                            }
                        }
                    }

                    // ── Input devices header ───────────────────────────────
                    Text {
                        text: "Input Devices"
                        color: Theme.muted
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontUi
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                        Layout.bottomMargin: 6
                    }

                    // ── Source list ────────────────────────────────────────
                    Repeater {
                        model: {
                            if (!Pipewire.ready) return []
                            // A "source" is an audio node that is neither a
                            // playback stream nor a sink — this naturally
                            // includes virtual sources like easyeffects_source
                            // while excluding sink monitors.
                            const seen = new Set()
                            return Pipewire.nodes.values.filter(n => {
                                if (n.audio === null || n.isStream || n.isSink) return false
                                const key = n.nickname || n.description || n.name
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

                            property bool isDefault: modelData.id === Pipewire.defaultAudioSource?.id

                            color: isDefault
                                   ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                   : srcHov.hovered
                                     ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.05)
                                     : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: "󰍬"
                                    color: isDefault ? Theme.accent : Theme.muted
                                    font.pixelSize: Theme.fontMd
                                    font.family: Theme.fontMono
                                }

                                Text {
                                    text: modelData.nickname || modelData.description || modelData.name
                                    color: isDefault ? Theme.accent : Theme.fg
                                    font.pixelSize: Theme.fontSm
                                    font.family: Theme.fontUi
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            HoverHandler { id: srcHov; cursorShape: Qt.PointingHandCursor }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    // Optimistic: point Volume at the new source
                                    // so the mic slider tracks it without waiting
                                    // for PipeWire to propagate the default.
                                    Volume.source = modelData
                                    Volume.refreshMic()
                                    Volume.setSource(modelData.name)
                                }
                            }
                        }
                    }

                    // ── Applications (per-app playback) ────────────────────
                    // Tracked so each stream's audio iface binds (non-null),
                    // letting the sliders read/write volume directly.
                    PwObjectTracker { objects: col.appStreams }

                    Rectangle {
                        visible: col.appStreams.length > 0
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                        Layout.topMargin: 12
                        Layout.bottomMargin: 10
                    }

                    Text {
                        visible: col.appStreams.length > 0
                        text: "Applications"
                        color: Theme.muted
                        font.pixelSize: Theme.fontXs
                        font.family: Theme.fontUi
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1
                        Layout.bottomMargin: 6
                    }

                    Repeater {
                        model: col.appStreams

                        delegate: RowLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            spacing: 8

                            readonly property var au: modelData.audio
                            readonly property bool appMuted: au ? au.muted : false
                            readonly property real appFrac: au ? au.volume : 0

                            // Prefer the human app name from stream properties,
                            // fall back to node description/name.
                            readonly property string appName: {
                                const p = modelData.properties
                                return (p && (p["application.name"] || p["media.name"]))
                                       || modelData.description || modelData.name
                            }

                            Text {
                                text: parent.appMuted ? "󰝟" : "󰕾"
                                color: parent.appMuted ? Theme.muted : Theme.busy
                                font.pixelSize: Theme.fontSm
                                font.family: Theme.fontMono
                                Layout.preferredWidth: 18

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (parent.parent.au) parent.parent.au.muted = !parent.parent.au.muted
                                }
                            }

                            Text {
                                text: parent.appName
                                color: Theme.fg
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontUi
                                elide: Text.ElideRight
                                Layout.preferredWidth: 90
                            }

                            Item {
                                id: appTrack
                                Layout.fillWidth: true
                                height: 16

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.10)

                                    Rectangle {
                                        width: parent.width * Math.min(1, appTrack.parent.appFrac)
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.busy
                                        Behavior on width { SmoothedAnimation { velocity: 300 } }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.SizeHorCursor
                                    onPressed: mouse => { if (appTrack.parent.au) appTrack.parent.au.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                    onPositionChanged: mouse => { if (pressed && appTrack.parent.au) appTrack.parent.au.volume = Math.max(0, Math.min(1, mouse.x / width)) }
                                }
                            }

                            Text {
                                text: Math.round(parent.appFrac * 100) + "%"
                                color: Theme.muted
                                font.pixelSize: Theme.fontXs
                                font.family: Theme.fontMono
                                Layout.preferredWidth: 34
                                horizontalAlignment: Text.AlignRight
                            }
                        }
                    }
                }
            }

        }
    }
}
