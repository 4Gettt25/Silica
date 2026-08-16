// Dock/launcher icons: Quickshell resolves themed icons through the Qt
// platform theme, which bare Hyprland/niri sessions usually lack. Fixes (all
// startup-only; Quickshell <= 0.2 has no runtime icon-theme API):
//   * scripts/install-icons.sh + QT_QPA_PLATFORMTHEME=gtk3, or
//   * the QS_ICON_THEME env var, or
//   * the IconTheme root-file pragma.
// See README "Icons" for exact syntax — do not paste pragma lines anywhere
// else, they are only parsed at the top of this file.
import Quickshell
import "common"
import "modules/background"
import "modules/bar"
import "modules/dock"
import "modules/launcher"
import "modules/launchpad"
import "modules/controlcenter"
import "modules/notifications"
import "modules/missioncontrol"
import "modules/switcher"
import "modules/hud"
import "modules/hotcorners"
import "modules/settings"

// Shell root: instantiates every module. The common/ directory provides the
// Theme / Settings / ShellState / Compositor / Time / Wallpaper singletons
// used throughout.
//
// Order matters only for same-layer surfaces; each module sets its own
// WlrLayer, so this list is grouped by role instead: the desktop, the two
// persistent chrome surfaces, then the transient ones.
ShellRoot {
    // Desktop
    Background {}
    HotCorners {}

    // Persistent chrome
    Bar {}
    Dock {}

    // Popovers and overlays
    ControlCenter {}
    Launcher {}
    Launchpad {}
    MissionControl {}
    Switcher {}

    // Feedback surfaces
    Notifications {}
    Hud {}

    // An ordinary window rather than an overlay, opened from the Apple menu.
    SystemSettings {}
}
