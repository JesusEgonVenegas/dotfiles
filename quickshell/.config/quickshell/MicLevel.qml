// MicLevel.qml — live peak meter for the current input (mic) device.
// Uses Quickshell's native PwNodePeakMonitor (no external capture), so it never
// holds the mic open on its own and follows the default source automatically.
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

    PwNodePeakMonitor {
        id: monitor
        node: Pipewire.defaultAudioSource
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
