pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Persisted user preferences for the whole shell.
//
// Everything the user can change from the UI lives here and is written to
// ~/.config/macos-shell/state.json through FileView + JsonAdapter. Theme,
// Dock, Bar, Control Center etc. read these; nothing else owns persistence.
//
// Adding a preference = add a property to the JsonAdapter below and read it
// via `Settings.<name>`. Missing keys in an older state.json keep their
// defaults, so the file format is forward/backward tolerant.
Singleton {
    id: root

    // --- appearance -------------------------------------------------------
    // "light" | "dark"
    property alias appearance: adapter.appearance
    // macOS accent color name: blue purple pink red orange yellow green graphite
    property alias accent: adapter.accent
    // Accessibility (HIG "Foundations > Accessibility"): when on, the shell
    // drops blur/translucency and long animations.
    property alias reduceTransparency: adapter.reduceTransparency
    property alias reduceMotion: adapter.reduceMotion
    // Where the shell's UI symbols come from: "theme" takes them from the
    // installed icon theme (WhiteSur, see scripts/install-icons.sh) wherever
    // it has one, "drawn" always uses Glyph's own Canvas paths.
    property alias symbolStyle: adapter.symbolStyle

    // --- menu bar ---------------------------------------------------------
    property alias clock24h: adapter.clock24h
    property alias clockShowSeconds: adapter.clockShowSeconds
    property alias clockShowDate: adapter.clockShowDate
    property alias menuBarAutoHide: adapter.menuBarAutoHide
    // "small" | "medium" | "large" — drives Theme.barHeight and the size of
    // every menu bar glyph.
    property alias menuBarSize: adapter.menuBarSize
    // What the leftmost menu bar title shows: "apple" (the drawn Apple mark),
    // "distro" (this machine's OS logo) or "custom" (menuBarLogoPath).
    property alias menuBarLogo: adapter.menuBarLogo
    property alias menuBarLogoPath: adapter.menuBarLogoPath

    // --- dock -------------------------------------------------------------
    // "bottom" | "left" | "right"
    property alias dockPosition: adapter.dockPosition
    property alias dockSize: adapter.dockSize
    property alias dockMagnification: adapter.dockMagnification
    property alias dockMagnificationSize: adapter.dockMagnificationSize
    property alias dockAutoHide: adapter.dockAutoHide
    property alias dockShowRecents: adapter.dockShowRecents
    // JSON array of pinned dock entries; empty = use Dock.qml's defaults.
    property alias dockPinned: adapter.dockPinned

    // --- desktop ----------------------------------------------------------
    property alias wallpaperLight: adapter.wallpaperLight
    property alias wallpaperDark: adapter.wallpaperDark
    // Hot corner actions: "" | "missioncontrol" | "launchpad" | "desktop" |
    // "notificationcenter" | "lockscreen" | "sleep"
    property alias hotCornerTopLeft: adapter.hotCornerTopLeft
    property alias hotCornerTopRight: adapter.hotCornerTopRight
    property alias hotCornerBottomLeft: adapter.hotCornerBottomLeft
    property alias hotCornerBottomRight: adapter.hotCornerBottomRight

    // --- notifications ----------------------------------------------------
    property alias doNotDisturb: adapter.doNotDisturb
    property alias notificationSounds: adapter.notificationSounds

    function toggleAppearance() {
        adapter.appearance = (adapter.appearance === "dark") ? "light" : "dark";
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.config/macos-shell/state.json"
        // Config files are the documented use of blockLoading: the load
        // finishes before any window is mapped, so the saved appearance
        // applies without a visible flash. A missing file fails fast.
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {} // first run: defaults stay

        JsonAdapter {
            id: adapter

            property string appearance: "dark"
            property string accent: "blue"
            property bool reduceTransparency: false
            property bool reduceMotion: false
            property string symbolStyle: "theme"

            property bool clock24h: true
            property bool clockShowSeconds: false
            property bool clockShowDate: true
            property bool menuBarAutoHide: false
            property string menuBarSize: "medium"
            property string menuBarLogo: "apple"
            property string menuBarLogoPath: ""

            property string dockPosition: "bottom"
            property int dockSize: 52
            property bool dockMagnification: true
            property int dockMagnificationSize: 82
            property bool dockAutoHide: false
            property bool dockShowRecents: true
            property list<string> dockPinned: []

            property string wallpaperLight: ""
            property string wallpaperDark: ""
            property string hotCornerTopLeft: ""
            property string hotCornerTopRight: ""
            property string hotCornerBottomLeft: ""
            property string hotCornerBottomRight: ""

            property bool doNotDisturb: false
            property bool notificationSounds: false
        }
    }

    // writeAdapter() renames atomically inside the target directory and cannot
    // create it — make sure it exists (short-lived, async).
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.config/macos-shell"]
    }
}
