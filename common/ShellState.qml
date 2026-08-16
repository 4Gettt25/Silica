pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Global UI state: which surface currently owns the screen, plus the small
// pieces of cross-module state (focused app name, HUD, notification counts).
//
// Rule: the shell shows AT MOST ONE modal surface at a time. Every module only
// ever sets its own flag; the exclusivity is enforced centrally here.
Singleton {
    id: root

    // ------------------------------------------------------------ surfaces
    property bool launcherOpen: false          // Spotlight
    property bool launchpadOpen: false         // Launchpad
    property bool controlCenterOpen: false     // Control Center popover
    property bool notificationCenterOpen: false
    property bool missionControlOpen: false
    property bool appSwitcherOpen: false

    // Menu bar dropdowns and menu-bar-extra popovers share one namespace:
    //   ""            nothing open
    //   "apple"       the Apple menu
    //   "app"|"file"… an application menu
    //   "extra:wifi"  a menu bar extra popover (see modules/bar/extras)
    property string openMenu: ""

    readonly property bool anyOverlayOpen: launcherOpen || launchpadOpen || controlCenterOpen || notificationCenterOpen || missionControlOpen || appSwitcherOpen || openMenu !== ""

    // Surfaces that dim/blur the whole screen; the dock and bar dim with them.
    readonly property bool fullscreenOverlay: launchpadOpen || missionControlOpen

    // System Settings is an ordinary window, not an overlay, so it is
    // deliberately NOT part of the exclusivity rules above.
    property bool settingsOpen: false
    property string settingsPane: "appearance"

    function openSettings(pane) {
        if (pane !== undefined && pane !== "")
            settingsPane = pane;
        settingsOpen = true;
    }

    // ------------------------------------------------------- focused app
    property string focusedAppName: "Finder" // bold entry in the menu bar
    property string focusedWindowTitle: ""

    // ------------------------------------------------------------- HUD
    // macOS on-screen display for volume / brightness / mute etc.
    // Modules call showHud(); modules/hud/Hud.qml renders it.
    property string hudKind: ""     // "volume" | "mute" | "brightness"
    property real hudValue: 0       // 0..1
    signal hudRequested(string kind, real value)

    function showHud(kind, value) {
        hudKind = kind;
        hudValue = value;
        hudRequested(kind, value);
    }

    // --------------------------------------------------- notifications
    // Owned by modules/notifications; mirrored here so the menu bar and
    // Control Center can show a badge without importing that module.
    property int notificationCount: 0
    property bool doNotDisturb: Settings.doNotDisturb

    onDoNotDisturbChanged: {
        if (Settings.doNotDisturb !== doNotDisturb)
            Settings.doNotDisturb = doNotDisturb;
    }

    // ------------------------------------------------------ exclusivity
    // niri does not always hand keyboard focus back to the previously focused
    // window when a layer surface that took focus is destroyed; the bar would
    // then be stuck showing "Desktop". Remember and restore it around menus.
    property var _preMenuFocusedWindowId: null

    function _exclude(keep) {
        if (keep !== "launcher")
            launcherOpen = false;
        if (keep !== "launchpad")
            launchpadOpen = false;
        if (keep !== "controlCenter")
            controlCenterOpen = false;
        if (keep !== "notificationCenter")
            notificationCenterOpen = false;
        if (keep !== "missionControl")
            missionControlOpen = false;
        if (keep !== "appSwitcher")
            appSwitcherOpen = false;
        if (keep !== "menu")
            openMenu = "";
    }

    onLauncherOpenChanged: if (launcherOpen) _exclude("launcher")
    onLaunchpadOpenChanged: if (launchpadOpen) _exclude("launchpad")
    onControlCenterOpenChanged: if (controlCenterOpen) _exclude("controlCenter")
    onNotificationCenterOpenChanged: if (notificationCenterOpen) _exclude("notificationCenter")
    onMissionControlOpenChanged: if (missionControlOpen) _exclude("missionControl")
    onAppSwitcherOpenChanged: if (appSwitcherOpen) _exclude("appSwitcher")

    onOpenMenuChanged: {
        if (openMenu !== "") {
            _exclude("menu");
            if (_preMenuFocusedWindowId === null) {
                const w = Compositor.windows.find(win => win.focused);
                _preMenuFocusedWindowId = w ? w.id : null;
            }
        } else if (_preMenuFocusedWindowId !== null) {
            Compositor.focusWindow(_preMenuFocusedWindowId);
            _preMenuFocusedWindowId = null;
        }
    }

    function closeAll() {
        launcherOpen = false;
        launchpadOpen = false;
        controlCenterOpen = false;
        notificationCenterOpen = false;
        missionControlOpen = false;
        appSwitcherOpen = false;
        openMenu = "";
    }

    // ------------------------------------------------------------- toggles
    function toggleLauncher() {
        launcherOpen = !launcherOpen;
    }
    function toggleLaunchpad() {
        launchpadOpen = !launchpadOpen;
    }
    function toggleControlCenter() {
        controlCenterOpen = !controlCenterOpen;
    }
    function toggleNotificationCenter() {
        notificationCenterOpen = !notificationCenterOpen;
    }
    function toggleMissionControl() {
        missionControlOpen = !missionControlOpen;
    }

    // Hot corners and menu items funnel through one place.
    function runAction(name) {
        switch (name) {
        case "missioncontrol":
            toggleMissionControl();
            break;
        case "launchpad":
            toggleLaunchpad();
            break;
        case "spotlight":
            toggleLauncher();
            break;
        case "notificationcenter":
            toggleNotificationCenter();
            break;
        case "controlcenter":
            toggleControlCenter();
            break;
        case "settings":
            openSettings("");
            break;
        case "lockscreen":
            lockRequested();
            break;
        case "sleep":
            Quickshell.execDetached(["systemctl", "suspend"]);
            break;
        case "desktop":
            Compositor.dispatch("toggle-overview");
            break;
        default:
            break;
        }
    }

    signal lockRequested()

    // ---------------------------------------------------------------- lock
    // Actually authenticating a password is security-critical and belongs to
    // a dedicated, audited locker rather than something reimplemented here —
    // swaylock is spawned and skinned with the shell's accent color rather
    // than the shell trying to become the session lock itself.
    readonly property bool lockAvailable: _lockCheck.available

    QtObject {
        id: _lockCheck
        property bool available: false
    }

    Process {
        command: ["sh", "-c", "command -v swaylock >/dev/null 2>&1 && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: _lockCheck.available = text.trim() === "yes"
        }
    }

    function _hex(c) {
        const ch = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return ch(c.r) + ch(c.g) + ch(c.b);
    }

    onLockRequested: {
        if (!lockAvailable) {
            console.warn("macos-shell: Lock Screen requested but swaylock is not installed");
            return;
        }
        const accent = _hex(Theme.accent);
        // ring-color is the dim idle/typing ring; key-hl-color is the per-keystroke
        // highlight segment. They used to both be the plain accent, which made typing
        // invisible — the highlight was the same color as the ring underneath it.
        const lockArgs = "--clock --indicator --indicator-radius 110 --indicator-thickness 10" +
            " --ring-color " + accent + "40 --key-hl-color " + accent + "ff" +
            " --inside-color 000000cc --line-color 00000000 --separator-color 00000000 --text-color ffffffff";
        // swaylock-effects' own --screenshots/--effect-blur crash under niri (its wlr-screencopy
        // grab is flaky there), and when the locker dies mid-lock niri is left showing a solid
        // fallback color with no lock surface to interact with — an unrecoverable lockout that
        // needs a TTY switch to fix (https://github.com/niri-wm/niri/issues/2986). So grab and
        // blur the screenshot ourselves with niri's own (reliable) screenshot command + ImageMagick
        // *before* swaylock ever starts, and hand it a static --image. Falls back to a flat color
        // if that pipeline fails for any reason — never falls back to the crashy internal path.
        const script = `
            dir="\${XDG_RUNTIME_DIR:-/tmp}"
            shot="$dir/quickshell-lock-shot.png"
            blur="$dir/quickshell-lock-blur.png"
            rm -f "$shot" "$blur"
            niri msg action screenshot-screen --show-pointer false --path "$shot" >/dev/null 2>&1
            for i in $(seq 1 40); do [ -s "$shot" ] && break; sleep 0.05; done
            magick "$shot" -scale 15% -blur 0x6 -resize 700% "$blur" >/dev/null 2>&1
            if [ -s "$blur" ]; then
                swaylock -i "$blur" --scaling fill ${lockArgs}
            else
                swaylock --color 000000ff ${lockArgs}
            fi
            rm -f "$shot" "$blur"
        `;
        Quickshell.execDetached(["sh", "-c", script]);
    }

    // Bindable from the compositor: `qs -c macos-shell ipc call shell <fn>`.
    IpcHandler {
        target: "shell"

        function toggleControlCenter(): void {
            root.toggleControlCenter();
        }
        function toggleAppleMenu(): void {
            root.openMenu = (root.openMenu === "apple") ? "" : "apple";
        }
        function toggleNotificationCenter(): void {
            root.toggleNotificationCenter();
        }
        function toggleLaunchpad(): void {
            root.toggleLaunchpad();
        }
        function toggleMissionControl(): void {
            root.toggleMissionControl();
        }
        function toggleAppearance(): void {
            Settings.toggleAppearance();
        }
        function openSettings(pane: string): void {
            root.openSettings(pane);
        }
        function toggleDoNotDisturb(): void {
            root.doNotDisturb = !root.doNotDisturb;
        }
        function lock(): void {
            root.lockRequested();
        }
        function close(): void {
            root.closeAll();
        }
    }
}
