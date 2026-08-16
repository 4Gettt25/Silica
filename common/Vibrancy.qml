import QtQuick
import Quickshell
import Quickshell.Wayland

// A macOS material (HIG > Foundations > Materials): the translucent tint and
// hairlines that sit on top of a blurred backdrop.
//
// The blur itself is done by the compositor. niri (and KWin) implement
// ext-background-effect-v1, which Quickshell exposes as the window-attached
// `BackgroundEffect.blurRegion`, so the WINDOW must declare which regions to
// blur — a child item cannot do it for its window. Every window that uses a
// material therefore pairs it with a region of the same geometry and radius:
//
//   PanelWindow {
//       BackgroundEffect.blurRegion: Region { item: card; radius: Theme.radiusPopover }
//
//       Vibrancy { id: card; material: "popover"; radius: Theme.radiusPopover }
//   }
//
// Regions support per-corner radii, so rounded materials blur correctly.
// On a compositor without the protocol nothing breaks: the tint alone still
// reads as a translucent panel (Hyprland users can add
// `layerrule = blur, macos-shell.*` for the same effect).
Item {
    id: root

    // menuBar | menu | popover | hud | sidebar | dock | window | sheet | tooltip
    property string material: "popover"
    property real radius: Theme.radiusPopover
    property bool showBorder: true
    // The bright 1px inner line macOS draws along the top edge of a material.
    property bool showHighlight: true
    // Extra tint painted over the material (e.g. an open menu bar title).
    property color overlayColor: "transparent"

    readonly property color tint: {
        switch (material) {
        case "menuBar":
            return Theme.menuBarMaterial;
        case "menu":
            return Theme.menuMaterial;
        case "hud":
            return Theme.hudMaterial;
        case "sidebar":
            return Theme.sidebarMaterial;
        case "dock":
            return Theme.dockMaterial;
        case "window":
            return Theme.windowMaterial;
        case "sheet":
            return Theme.sheetMaterial;
        case "tooltip":
            return Theme.tooltipMaterial;
        default:
            return Theme.popoverMaterial;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: root.tint

        Behavior on color {
            ColorAnimation {
                duration: Theme.durBase
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: root.radius
            antialiasing: true
            visible: root.overlayColor.a > 0
            color: root.overlayColor
        }
    }

    // Outer hairline.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        antialiasing: true
        color: "transparent"
        visible: root.showBorder
        border.width: 1
        border.color: Theme.materialBorder
    }

    // Inner top highlight — macOS catches light on the upper edge of glass.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, root.radius - 1)
        antialiasing: true
        color: "transparent"
        visible: root.showHighlight && Theme.transparency
        border.width: 1
        border.color: Theme.materialHighlight
        opacity: 0.5
    }
}
