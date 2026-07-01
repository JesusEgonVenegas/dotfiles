import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Hyprland

Scope {
    Bar {}
    VolumePopup {}
    TooltipPopup {}
    MprisPopup {}
    NotificationToasts {}
    PowerMenu {}
    ClipboardPopup {}
    ScreenshotPopup {}
    RecordMenuPopup {}
    LauncherPopup {}

    // Super+D (bound in hyprland.conf: `global, quickshell:launcher`)
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        onPressed: LauncherState.toggle()
    }

    // Super+Shift+V (bound in hyprland.conf: `global, quickshell:clipboard`)
    GlobalShortcut {
        appid: "quickshell"
        name: "clipboard"
        onPressed: ClipboardState.toggle()
    }

    // Print (bound in hyprland.conf: `global, quickshell:screenshot`)
    GlobalShortcut {
        appid: "quickshell"
        name: "screenshot"
        onPressed: ScreenshotState.toggle()
    }

    // Super+R (bound in hyprland.conf: `global, quickshell:record`)
    GlobalShortcut {
        appid: "quickshell"
        name: "record"
        onPressed: RecordMenuState.toggle()
    }

    NotificationServer {
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        keepOnReload: false

        onNotification: notif => {
            notif.tracked = true
            NotifState.add(notif)
        }
    }
}
