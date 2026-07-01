// Volume.qml
pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // Active default sink
    property var sink: Pipewire.defaultAudioSink

    // ✅ UI-facing state (defined ONCE)
    property int volume: 0
    property bool muted: false

    PwObjectTracker {
        objects: sink ? [sink] : []
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

    // Initial
    Component.onCompleted: refresh()

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
    }

    // Sink lifecycle
    Connections {
        target: sink

        function onReadyChanged() {
            refresh();
        }
    }

    // Audio updates
    Connections {
        target: sink ? sink.audio : null

        function onVolumeChanged() {
            refresh();
        }
        function onMuteChanged() {
            refresh();
        }
    }
}
