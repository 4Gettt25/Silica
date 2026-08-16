pragma Singleton

import QtQuick
import Quickshell

// The current desktop picture.
//
// Two consumers: modules/background/Background.qml paints it, and
// common/Vibrancy.qml samples it to fake the blur behind every material
// (Wayland gives a client no way to read the pixels under its own surface,
// so the wallpaper is the backdrop we can actually reproduce).
Singleton {
    id: root

    readonly property url bundledLight: Qt.resolvedUrl("../assets/wallpapers/wallpaper-light.jpg")
    readonly property url bundledDark: Qt.resolvedUrl("../assets/wallpapers/wallpaper-dark.jpg")

    function _resolve(custom, fallback) {
        const s = (custom || "").trim();
        if (s.length === 0)
            return fallback;
        if (s.indexOf("file://") === 0 || s.indexOf("qrc:") === 0)
            return s;
        if (s.charAt(0) === "~")
            return "file://" + Quickshell.env("HOME") + s.slice(1);
        if (s.charAt(0) === "/")
            return "file://" + s;
        return Qt.resolvedUrl("../" + s);
    }

    readonly property url light: _resolve(Settings.wallpaperLight, bundledLight)
    readonly property url dark: _resolve(Settings.wallpaperDark, bundledDark)
    readonly property url current: Theme.dark ? dark : light
}
