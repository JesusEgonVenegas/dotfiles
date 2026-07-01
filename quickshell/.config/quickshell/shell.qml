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
    QuickIdeaPopup {}
    CalendarPopup {}

    // Super+D (bound in hyprland.conf: `global, quickshell:launcher`)
    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        onPressed: LauncherState.toggle()
    }

    // Super+Shift+I (bound in hyprland.conf: `global, quickshell:quickidea`)
    GlobalShortcut {
        appid: "quickshell"
        name: "quickidea"
        onPressed: QuickIdeaState.toggle()
    }

    // Super+Shift+C (bound in hyprland.conf: `global, quickshell:calendar`)
    GlobalShortcut {
        appid: "quickshell"
        name: "calendar"
        onPressed: CalendarState.toggle()
    }

    // Super+C (bound in hyprland.conf: `global, quickshell:claude`) — launcher
    // straight into "cc" mode: live Claude sessions + recent projects.
    GlobalShortcut {
        appid: "quickshell"
        name: "claude"
        onPressed: LauncherState.openClaude()
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
