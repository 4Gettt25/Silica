import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// Hot corners: pushing the pointer into a screen corner runs the action the
// user picked in System Settings → Desktop & Dock.
//
// One surface per screen, masked down to four small squares so it never eats
// a click meant for the window underneath. The window is only created while at
// least one corner is configured (LazyLoader), and it never takes keyboard
// focus.
Scope {
    id: root

    readonly property int cornerSize: 6
    // macOS fires a hot corner as soon as the pointer touches the corner, but
    // a short dwell keeps a pointer that is merely crossing the corner from
    // triggering it.
    readonly property int dwellMs: 180

    readonly property bool anyConfigured: Settings.hotCornerTopLeft !== "" || Settings.hotCornerTopRight !== "" || Settings.hotCornerBottomLeft !== "" || Settings.hotCornerBottomRight !== ""

    LazyLoader {
        active: root.anyConfigured

        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: win

                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                // The corners must be the real screen corners, so the bar's
                // and the dock's exclusive zones must not shrink this surface.
                exclusiveZone: 0
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                // Below the overlays (Launchpad, Mission Control, Spotlight)
                // so a corner cannot fire while one of them is up, but above
                // ordinary windows so the pointer reaches it.
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "macos-shell-hotcorners"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Only the four squares accept input; everything else is
                // click-through.
                mask: Region {
                    Region {
                        item: topLeft
                    }
                    Region {
                        item: topRight
                    }
                    Region {
                        item: bottomLeft
                    }
                    Region {
                        item: bottomRight
                    }
                }

                Corner {
                    id: topLeft
                    anchors.top: parent.top
                    anchors.left: parent.left
                    width: root.cornerSize
                    height: root.cornerSize
                    dwellMs: root.dwellMs
                    action: Settings.hotCornerTopLeft
                }

                Corner {
                    id: topRight
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: root.cornerSize
                    height: root.cornerSize
                    dwellMs: root.dwellMs
                    action: Settings.hotCornerTopRight
                }

                Corner {
                    id: bottomLeft
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: root.cornerSize
                    height: root.cornerSize
                    dwellMs: root.dwellMs
                    action: Settings.hotCornerBottomLeft
                }

                Corner {
                    id: bottomRight
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    width: root.cornerSize
                    height: root.cornerSize
                    dwellMs: root.dwellMs
                    action: Settings.hotCornerBottomRight
                }
            }
        }
    }
}
