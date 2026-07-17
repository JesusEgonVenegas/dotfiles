// MicLevel.qml — live peak meter for the current input (mic) device.
// Uses Quickshell's native PwNodePeakMonitor (no external capture), so it never
// holds the mic open on its own.
//
// It always meters the RAW hardware mic, never the virtual easyeffects_source.
// Two reasons: (1) the meter is for setting the MixPre's *analog* gain, which is
// the pre-processing level — EE's gate/compressor would make the post-FX number
// lie; (2) easyeffects_source is suspended by PipeWire whenever nothing is
// recording from it (no consumer => EE runs no input pipeline => peak is a flat
// 0), which froze the bar the moment Studio FX pointed the default source at it.
pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // Smoothed 0-100 value the meter bar binds to.
    property real level: 0

    // Only monitor while the popup is open — no point tapping peaks for a bar
    // nobody's looking at, and it lets the source suspend when idle.
    readonly property bool active: VolumeState.popupOpen

    // The physical mic to meter. Normally the default source; when Studio FX has
    // switched the default to easyeffects_source we keep the last real mic seen
    // (falling back to the first hardware input if we never saw one).
    property var rawSource: null

    function updateRaw() {
        if (!Pipewire.ready)
            return;
        const def = Pipewire.defaultAudioSource;
        if (def && def.name !== "easyeffects_source") {
            root.rawSource = def;
            return;
        }
        // Studio FX on (default is the virtual source): meter the mic EE actually
        // reads from — its pinned input device — matched by name. This avoids
        // grabbing the wrong hardware input (e.g. the silent onboard line-in,
        // which sorts before the MixPre). Fall back to the last real mic, then
        // to any hardware input.
        const eeIn = Volume.eeInputDevice;
        if (eeIn.length) {
            const m = Pipewire.nodes.values.find(n => n.name === eeIn);
            if (m) { root.rawSource = m; return; }
        }
        if (!root.rawSource)
            root.rawSource = Pipewire.nodes.values.find(n =>
                n.audio !== null && !n.isStream && !n.isSink
                && n.name !== "easyeffects_source") || null;
    }

    Component.onCompleted: updateRaw()

    Connections {
        target: Pipewire
        function onReadyChanged() { root.updateRaw() }
        function onDefaultAudioSourceChanged() { root.updateRaw() }
    }

    // EE's input device is read asynchronously; re-resolve once it lands.
    Connections {
        target: Volume
        function onEeInputDeviceChanged() { root.updateRaw() }
    }

    PwNodePeakMonitor {
        id: monitor
        node: root.rawSource
        enabled: root.active
    }

    onActiveChanged: if (!active) root.level = 0

    // peak is a native 0-1 float. Fast attack, slow release so the bar snaps to
    // a transient and eases back down like a real VU meter.
    Timer {
        interval: 33
        running: root.active
        repeat: true
        onTriggered: {
            const t = Math.max(0, Math.min(1, monitor.peak || 0)) * 100
            root.level = t > root.level ? t : root.level * 0.75
        }
    }
}
