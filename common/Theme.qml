pragma Singleton

import QtQuick
import Quickshell

// The design system.
//
// Mirrors the macOS Human Interface Guidelines foundations — semantic colors,
// system colors, materials, typography, layout metrics and motion — so no
// module ever hardcodes a color, size or duration. Everything derives from
// `Settings.appearance` ("light" | "dark") and `Settings.accent`.
//
// Naming follows AppKit's semantic vocabulary where one exists
// (labelColor -> label, controlAccentColor -> accent, ...) because that is
// what the HIG documents; the older flat names from the first version of this
// shell are kept at the bottom as deprecated aliases so partially-migrated
// modules keep rendering.
Singleton {
    id: theme

    // ---------------------------------------------------------------- mode
    readonly property string mode: Settings.appearance === "light" ? "light" : "dark"
    readonly property bool dark: mode === "dark"

    function toggle() {
        Settings.toggleAppearance();
    }

    // Accessibility switches (HIG > Foundations > Accessibility).
    readonly property bool transparency: !Settings.reduceTransparency
    readonly property bool motion: !Settings.reduceMotion

    // ------------------------------------------------------- system colors
    // AppKit's NSColor system palette, light and dark variants.
    readonly property color blue: dark ? "#0A84FF" : "#007AFF"
    readonly property color brown: dark ? "#AC8E68" : "#A2845E"
    readonly property color gray: dark ? "#98989D" : "#8E8E93"
    readonly property color green: dark ? "#32D74B" : "#28CD41"
    readonly property color indigo: dark ? "#5E5CE6" : "#5856D6"
    readonly property color mint: dark ? "#63E6E1" : "#00C7BE"
    readonly property color orange: dark ? "#FF9F0A" : "#FF9500"
    readonly property color pink: dark ? "#FF375F" : "#FF2D55"
    readonly property color purple: dark ? "#BF5AF2" : "#AF52DE"
    readonly property color red: dark ? "#FF453A" : "#FF3B30"
    readonly property color teal: dark ? "#6AC4DC" : "#59ADC4"
    readonly property color yellow: dark ? "#FFD60A" : "#FFCC00"

    // Traffic-light / status colors are fixed in macOS (they do not follow the
    // accent) — close red, minimize yellow, zoom green.
    readonly property color trafficClose: "#FF5F57"
    readonly property color trafficMinimize: "#FEBC2E"
    readonly property color trafficZoom: "#28C840"

    // ---------------------------------------------------------- accent color
    // System Settings > Appearance > accent color.
    readonly property color accent: {
        switch (Settings.accent) {
        case "purple":
            return dark ? "#BF5AF2" : "#A550A7";
        case "pink":
            return dark ? "#FF375F" : "#F74F9E";
        case "red":
            return dark ? "#FF453A" : "#FF5257";
        case "orange":
            return dark ? "#FF9F0A" : "#F7821B";
        case "yellow":
            return dark ? "#FFD60A" : "#FFC600";
        case "green":
            return dark ? "#32D74B" : "#62BA46";
        case "graphite":
            return dark ? "#98989D" : "#8C8C8C";
        default:
            return blue;
        }
    }
    // Ink that stays legible on top of a filled accent shape.
    readonly property color onAccent: (Settings.accent === "yellow") ? "#1D1D1F" : "#FFFFFF"

    // ------------------------------------------------------ semantic labels
    // NSColor.labelColor and friends: four levels of foreground emphasis.
    readonly property color label: dark ? Qt.rgba(1, 1, 1, 0.92) : Qt.rgba(0, 0, 0, 0.88)
    readonly property color secondaryLabel: dark ? Qt.rgba(1, 1, 1, 0.60) : Qt.rgba(0, 0, 0, 0.55)
    readonly property color tertiaryLabel: dark ? Qt.rgba(1, 1, 1, 0.36) : Qt.rgba(0, 0, 0, 0.31)
    readonly property color quaternaryLabel: dark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.16)
    // Text drawn on a colored/vibrant surface where the label must stay white.
    readonly property color alwaysLight: "#FFFFFF"

    // ------------------------------------------------------- semantic fills
    // NSColor.*FillColor: the neutral backgrounds of controls sitting on a
    // material (Control Center tiles, slider tracks, segmented controls...).
    readonly property color fill: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.09)
    readonly property color secondaryFill: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color tertiaryFill: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color quaternaryFill: dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.02)
    // Hover / pressed feedback on an otherwise transparent row or button.
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)

    readonly property color separator: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.10)
    readonly property color opaqueSeparator: dark ? "#3A3A3C" : "#D8D8DC"

    // Selected menu row / selected list row (macOS fills these with the accent).
    readonly property color selection: accent
    readonly property color onSelection: onAccent

    // ------------------------------------------------------------ materials
    // HIG > Foundations > Materials. Each material is a translucent tint that
    // sits on top of a blurred backdrop (see common/Vibrancy.qml). When
    // "Reduce transparency" is on, the tints below are replaced by their
    // opaque equivalents so contrast is preserved.
    readonly property real _o: transparency ? 1.0 : 0.0 // 1 = translucent allowed

    readonly property color menuBarMaterial: transparency ? (dark ? Qt.rgba(0.13, 0.13, 0.14, 0.62) : Qt.rgba(0.98, 0.98, 0.99, 0.60)) : (dark ? "#1E1E20" : "#F2F2F5")
    readonly property color menuMaterial: transparency ? (dark ? Qt.rgba(0.16, 0.16, 0.17, 0.72) : Qt.rgba(0.98, 0.98, 0.99, 0.72)) : (dark ? "#2A2A2C" : "#F7F7F9")
    readonly property color popoverMaterial: transparency ? (dark ? Qt.rgba(0.16, 0.16, 0.17, 0.74) : Qt.rgba(0.98, 0.98, 0.99, 0.74)) : (dark ? "#2A2A2C" : "#F7F7F9")
    readonly property color hudMaterial: transparency ? (dark ? Qt.rgba(0.14, 0.14, 0.15, 0.66) : Qt.rgba(0.90, 0.90, 0.92, 0.66)) : (dark ? "#232325" : "#E8E8EB")
    readonly property color sidebarMaterial: transparency ? (dark ? Qt.rgba(0.12, 0.12, 0.13, 0.58) : Qt.rgba(0.96, 0.96, 0.97, 0.58)) : (dark ? "#1C1C1E" : "#F0F0F2")
    readonly property color dockMaterial: transparency ? (dark ? Qt.rgba(0.16, 0.16, 0.18, 0.50) : Qt.rgba(0.98, 0.98, 0.99, 0.46)) : (dark ? "#2A2A2E" : "#F0F0F3")
    readonly property color windowMaterial: dark ? Qt.rgba(0.19, 0.19, 0.20, 0.94) : Qt.rgba(0.96, 0.96, 0.97, 0.94)
    readonly property color sheetMaterial: dark ? Qt.rgba(0.17, 0.17, 0.18, 0.96) : Qt.rgba(0.98, 0.98, 0.99, 0.96)
    readonly property color tooltipMaterial: transparency ? (dark ? Qt.rgba(0.18, 0.18, 0.19, 0.88) : Qt.rgba(0.99, 0.99, 1.0, 0.90)) : (dark ? "#2E2E30" : "#FCFCFE")
    // Full-screen scrim behind Mission Control / Launchpad / the lock screen.
    readonly property color scrim: dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.30)

    // Hairlines: macOS draws a 1px inner light stroke at the top of a material
    // and a darker outer stroke around it.
    readonly property color materialBorder: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.11)
    readonly property color materialHighlight: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.55)

    // How much of the wallpaper shows through a material (0 = flat tint).
    readonly property real vibrancy: transparency ? 1.0 : 0.0
    readonly property int blurRadius: 48
    // Materials are slightly saturated versions of what is behind them.
    readonly property real blurSaturation: dark ? 1.6 : 1.9

    // Shadows (HIG: popovers and menus float above their content).
    readonly property color shadowColor: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.28)
    readonly property int shadowBlur: 32
    readonly property int shadowOffset: 6

    // ----------------------------------------------------------- typography
    // SF Pro is not redistributable; Adwaita Sans (an Inter derivative) is the
    // closest thing shipped by most distros and is listed after the real
    // Apple/Inter families so a user who installs them gets them.
    // (The QML `font` value type has no `families` list, so the first
    // installed candidate is resolved once at startup instead.)
    readonly property var fontCandidates: ["SF Pro Text", "SF Pro Display", "Inter", "Inter Display", "Adwaita Sans", "Helvetica Neue", "Noto Sans", "DejaVu Sans"]
    readonly property var monoCandidates: ["SF Mono", "Adwaita Mono", "JetBrains Mono", "DejaVu Sans Mono"]

    function _firstInstalled(candidates, fallback) {
        const available = Qt.fontFamilies();
        for (const c of candidates)
            if (available.indexOf(c) >= 0)
                return c;
        return fallback;
    }

    readonly property string fontFamily: _firstInstalled(fontCandidates, "sans-serif")
    readonly property string monoFamily: _firstInstalled(monoCandidates, "monospace")

    // macOS text styles (points at 1x). Use these, never a raw number.
    readonly property int fsLargeTitle: 26
    readonly property int fsTitle1: 22
    readonly property int fsTitle2: 17
    readonly property int fsTitle3: 15
    readonly property int fsHeadline: 13
    readonly property int fsBody: 13
    readonly property int fsCallout: 12
    readonly property int fsSubheadline: 11
    readonly property int fsFootnote: 10
    readonly property int fsCaption: 10

    readonly property int wRegular: Font.Normal
    readonly property int wMedium: Font.Medium
    readonly property int wSemibold: Font.DemiBold
    readonly property int wBold: Font.Bold

    // Menu bar / menu text is body size in macOS.
    readonly property int barFontSize: barSmall ? fsBody : (barLarge ? 16 : 14)

    // --------------------------------------------------------------- metrics
    // Menu bar scale. macOS has one size (24pt); a Linux desktop can be a 4K
    // panel running unscaled, where 24pt of bar is unreadably thin, so the
    // user picks from three (System Settings > Menu Bar & Clock).
    readonly property bool barSmall: Settings.menuBarSize === "small"
    readonly property bool barLarge: Settings.menuBarSize === "large"

    readonly property int barHeight: barSmall ? 24 : (barLarge ? 34 : 28)
    // Default side of a menu bar glyph. Extras that need a different optical
    // weight scale this rather than hardcoding a number.
    readonly property int barGlyphSize: barSmall ? 15 : (barLarge ? 21 : 18)
    readonly property int barItemSpacing: 2
    readonly property int barItemPadding: barLarge ? 10 : 8

    readonly property real radiusMenu: 7
    readonly property real radiusPopover: 12
    readonly property real radiusWindow: 12
    readonly property real radiusControl: 6
    readonly property real radiusTile: 10
    readonly property real radiusDock: 20
    readonly property real radiusIcon: 0.2237 // macOS "squircle" ratio: r = 22.37% of side

    // 4pt spacing scale.
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 20
    readonly property int space6: 24

    // ---------------------------------------------------------------- motion
    // Reduce Motion collapses every duration to ~0 without removing behaviors.
    readonly property int durInstant: motion ? 90 : 0
    readonly property int durFast: motion ? 150 : 0
    readonly property int durBase: motion ? 250 : 0
    readonly property int durSlow: motion ? 400 : 0
    readonly property int durWallpaper: motion ? 600 : 0

    // macOS default timing curve (CAMediaTimingFunction .default).
    readonly property var easeStandard: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
    // Entering the screen: fast start, gentle settle.
    readonly property var easeOut: [0.0, 0.0, 0.2, 1.0, 1.0, 1.0]
    // Leaving the screen.
    readonly property var easeIn: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
    readonly property int easingType: Easing.BezierSpline

    // ------------------------------------------------------------- helpers
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }
    // Radius of a macOS-style app icon of side `size`.
    function iconRadius(size) {
        return size * radiusIcon;
    }

    // ---------------------------------------------- deprecated flat aliases
    // Kept so modules that have not been migrated yet still render.
    readonly property color barBg: menuBarMaterial
    readonly property color barText: label
    readonly property color panelBg: popoverMaterial
    readonly property color panelBorder: materialBorder
    readonly property color panelText: label
    readonly property color panelSubtext: secondaryLabel
    readonly property color hoverBg: hover
    readonly property color dockBg: dockMaterial
    readonly property color dockBorder: materialBorder
    readonly property color tooltipBg: tooltipMaterial
    readonly property color tooltipText: label
    readonly property color danger: red
    readonly property color warning: yellow
    readonly property color success: green
    readonly property real panelRadius: radiusPopover
    readonly property real panelMargin: 6
}
