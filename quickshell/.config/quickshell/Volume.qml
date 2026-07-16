// Volume.qml
pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Active default sink
    property var sink: Pipewire.defaultAudioSink
    // Active default source (mic)
    property var source: Pipewire.defaultAudioSource

    // ✅ UI-facing state (defined ONCE)
    property int volume: 0
    property bool muted: false
    // Mic (input) mirror of the above
    property int micVolume: 0
    property bool micMuted: false

    PwObjectTracker {
        objects: {
            const o = []
            if (sink) o.push(sink)
            if (source) o.push(source)
            return o
        }
    }

    function refresh() {
        if (!Pipewire.ready)
            return;
        if (!sink || !sink.ready)
            return;
        if (!sink.audio)
            return;
        if (sink.audio.volume !== null)
            volume = Math.round(sink.audio.volume * 100);

        muted = sink.audio.muted;
    }

    // Same defensive guards as refresh(). The mic slider/meter and the bar mute
    // indicator all read micVolume/micMuted, so keep them in lock-step with the
    // real default source.
    function refreshMic() {
        if (!Pipewire.ready)
            return;
        if (!source || !source.ready)
            return;
        if (!source.audio)
            return;
        if (source.audio.volume !== null)
            micVolume = Math.round(source.audio.volume * 100);

        micMuted = source.audio.muted;
    }

    // Goes through pactl rather than writing sink.audio.muted directly: the
    // QML PwNodeAudioIface for a sink only becomes non-null if the node was
    // already bound at the moment its wrapper was first constructed (e.g.
    // while just listed in VolumePopup's device Repeater, well before it's
    // ever selected) — so after switching output devices, sink.audio can be
    // permanently null for the rest of the session and a direct write would
    // silently no-op. pactl talks to the real default sink directly instead.
    // muted is set optimistically so callers get an instant icon flip rather
    // than waiting on a refresh() that depends on that same sink.audio.
    function toggleMute() {
        muted = !muted
        muteToggleProc.running = true
    }

    // Same pactl-over-direct-write reasoning as toggleMute() above. fraction
    // is 0-1; volume is set optimistically so a dragged slider tracks the
    // cursor instantly instead of waiting on refresh().
    function setVolume(fraction) {
        volume = Math.round(Math.max(0, Math.min(1, fraction)) * 100)
        volumeSetProc.command = ["pactl", "set-sink-volume", "@DEFAULT_SINK@", volume + "%"]
        volumeSetProc.running = true
    }

    Process {
        id: muteToggleProc
        command: ["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]
        onRunningChanged: if (!running) root.refresh()
    }

    Process {
        id: volumeSetProc
        onRunningChanged: if (!running) root.refresh()
    }

    // Mic mute/volume — same pactl-over-direct-write reasoning as the sink side
    // (see toggleMute()): a source's PwNodeAudioIface can be permanently null
    // after a device switch, so route through @DEFAULT_SOURCE@ and update the
    // UI-facing state optimistically for an instant response.
    function toggleMicMute() {
        micMuted = !micMuted
        micMuteToggleProc.running = true
    }

    function setMicVolume(fraction) {
        micVolume = Math.round(Math.max(0, Math.min(1, fraction)) * 100)
        micVolumeSetProc.command = ["pactl", "set-source-volume", "@DEFAULT_SOURCE@", micVolume + "%"]
        micVolumeSetProc.running = true
    }

    Process {
        id: micMuteToggleProc
        command: ["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"]
        onRunningChanged: if (!running) root.refreshMic()
    }

    Process {
        id: micVolumeSetProc
        onRunningChanged: if (!running) root.refreshMic()
    }

    // Switch the default source (mic). Node name, not numeric id — pactl is
    // more reliable than wpctl for this, matching setDefault in VolumePopup.
    function setSource(name) {
        setSourceProc.command = ["pactl", "set-default-source", name]
        setSourceProc.running = true
    }

    Process {
        id: setSourceProc
        onRunningChanged: if (!running) root.refreshMic()
    }

    // Initial
    Component.onCompleted: { refresh(); refreshMic() }

    // PipeWire lifecycle
    Connections {
        target: Pipewire

        function onReadyChanged() {
            refresh();
        }

        function onDefaultAudioSinkChanged() {
            sink = Pipewire.defaultAudioSink;
            refresh();
        }

        function onDefaultAudioSourceChanged() {
            source = Pipewire.defaultAudioSource;
            refreshMic();
        }
    }

    // Sink lifecycle
    Connections {
        target: sink

        function onReadyChanged() {
            refresh();
        }
    }

    // Audio updates — signal names are volumesChanged/mutedChanged (the
    // PwNodeAudioIface NOTIFYs), so external volume/mute changes reflect live.
    Connections {
        target: sink ? sink.audio : null

        function onVolumesChanged() {
            refresh();
        }
        function onMutedChanged() {
            refresh();
        }
    }

    // Source lifecycle
    Connections {
        target: source

        function onReadyChanged() {
            refreshMic();
        }
    }

    // Mic audio updates
    Connections {
        target: source ? source.audio : null

        function onVolumesChanged() {
            refreshMic();
        }
        function onMutedChanged() {
            refreshMic();
        }
    }
}
