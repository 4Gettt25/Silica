import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "extras"

// The macOS menu bar, one per screen.
//
//   left   Apple menu, the bold focused-app menu, File/Edit/View/Window/Help
//   right  system tray, Spotlight, Focus, Sound, Wi-Fi, Battery,
//          Control Center, clock  (macOS orders these right-to-left)
//
// The bar never takes keyboard focus: a layer surface that grabs focus makes
// the compositor report "no focused toplevel", which would blank the app name
// and steal input from the user's window (see DESIGN.md).
Scope {
    id: barScope

    // Menu ids in bar order, so ← / → can walk between open menus.
    readonly property var menuOrder: ["apple", "app", "file", "edit", "view", "window", "help"]

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: barWindow
            required property var modelData // a ShellScreen
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: Theme.barHeight
            color: "transparent"

            // Reserve space only when the bar is actually on screen.
            exclusionMode: Settings.menuBarAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
            // Named like every other surface the shell maps, so a compositor
            // layer-rule can single the menu bar out.
            WlrLayershell.namespace: "macos-shell-bar"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Both the input mask and the compositor blur follow the surface,
            // so a hidden (slid-out) bar is fully click-through and unblurred.
            mask: Region {
                item: barSurface
            }

            BackgroundEffect.blurRegion: Region {
                item: barSurface
            }

            // -------------------------------------------------- auto-hide
            property bool revealedRaw: false
            readonly property bool hovering: barHover.hovered || revealStrip.pointerAtTop
            readonly property bool revealed: !Settings.menuBarAutoHide || revealedRaw || ShellState.openMenu !== ""

            onHoveringChanged: {
                if (hovering) {
                    hideTimer.stop();
                    revealedRaw = true;
                } else {
                    hideTimer.restart();
                }
            }

            Timer {
                id: hideTimer
                interval: 400
                onTriggered: barWindow.revealedRaw = false
            }

            // A 2px strip on the BOTTOM layer: while the bar is hidden its
            // mask is empty, so the pointer falls through to this strip; while
            // the bar is shown the bar sits on top of it and swallows clicks.
            LazyLoader {
                id: revealStrip
                active: Settings.menuBarAutoHide

                property bool pointerAtTop: item ? item.hovered : false

                PanelWindow {
                    screen: barWindow.screen
                    anchors {
                        top: true
                        left: true
                        right: true
                    }
                    implicitHeight: 2
                    color: "transparent"
                    exclusionMode: ExclusionMode.Ignore
                    WlrLayershell.layer: WlrLayer.Bottom
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                    property alias hovered: stripHover.hovered

                    // A pointer handler must live on an Item, not on the
                    // window object itself.
                    Item {
                        anchors.fill: parent

                        HoverHandler {
                            id: stripHover
                        }
                    }
                }
            }

            // ------------------------------------------------------ surface
            Item {
                id: barSurface
                width: parent.width
                height: Theme.barHeight
                y: barWindow.revealed ? 0 : -height

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                // HoverHandler instead of a MouseArea: it observes the pointer
                // without stealing hover from the bar items underneath it.
                HoverHandler {
                    id: barHover
                }

                // The menu bar is square and borderless; only the bottom edge
                // carries a hairline.
                Vibrancy {
                    anchors.fill: parent
                    material: "menuBar"
                    radius: 0
                    showBorder: false
                    showHighlight: false
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.separator
                }

                // ------------------------------------------------ left side
                Row {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space1 + 2
                    height: parent.height
                    spacing: Theme.barItemSpacing

                    AppleMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        menuId: "app"
                        title: ShellState.focusedAppName
                        bold: true
                        items: [
                            {
                                text: "About " + ShellState.focusedAppName,
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Settings…",
                                shortcut: "⌘,",
                                enabled: BarActions.settingsAvailable,
                                action: () => BarActions.openSettings()
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Services",
                                submenu: [
                                    {
                                        text: "No Services Apply",
                                        enabled: false
                                    }
                                ]
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Hide " + ShellState.focusedAppName,
                                shortcut: "⌘H",
                                enabled: false
                            },
                            {
                                text: "Hide Others",
                                shortcut: "⌥⌘H",
                                enabled: false
                            },
                            {
                                text: "Show All",
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Quit " + ShellState.focusedAppName,
                                shortcut: "⌘Q",
                                action: () => BarActions.closeFocusedWindow()
                            }
                        ]
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        title: "File"
                        items: [
                            {
                                text: "New Window",
                                shortcut: "⌘N",
                                enabled: false
                            },
                            {
                                text: "New Tab",
                                shortcut: "⌘T",
                                enabled: false
                            },
                            {
                                text: "Open…",
                                shortcut: "⌘O",
                                enabled: false
                            },
                            {
                                text: "Open Recent",
                                submenu: [
                                    {
                                        text: "Clear Menu",
                                        enabled: false
                                    }
                                ]
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Close Window",
                                shortcut: "⌘W",
                                action: () => BarActions.closeFocusedWindow()
                            },
                            {
                                text: "Save",
                                shortcut: "⌘S",
                                enabled: false
                            },
                            {
                                text: "Duplicate",
                                shortcut: "⇧⌘S",
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Print…",
                                shortcut: "⌘P",
                                enabled: false
                            }
                        ]
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        title: "Edit"
                        items: [
                            {
                                text: "Undo",
                                shortcut: "⌘Z",
                                enabled: false
                            },
                            {
                                text: "Redo",
                                shortcut: "⇧⌘Z",
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Cut",
                                shortcut: "⌘X",
                                enabled: false
                            },
                            {
                                text: "Copy",
                                shortcut: "⌘C",
                                enabled: false
                            },
                            {
                                text: "Paste",
                                shortcut: "⌘V",
                                enabled: false
                            },
                            {
                                text: "Select All",
                                shortcut: "⌘A",
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Find",
                                submenu: [
                                    {
                                        text: "Find…",
                                        shortcut: "⌘F",
                                        enabled: false
                                    },
                                    {
                                        text: "Find Next",
                                        shortcut: "⌘G",
                                        enabled: false
                                    }
                                ]
                            },
                            {
                                text: "Emoji & Symbols",
                                shortcut: "⌃⌘Space",
                                enabled: false
                            }
                        ]
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        title: "View"
                        items: [
                            {
                                text: "Show Toolbar",
                                shortcut: "⌥⌘T",
                                enabled: false
                            },
                            {
                                text: "Show Sidebar",
                                shortcut: "⌃⌘S",
                                enabled: false
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Enter Full Screen",
                                shortcut: "⌃⌘F",
                                action: () => Compositor.dispatch("fullscreen-window")
                            }
                        ]
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        title: "Window"
                        // niri has no minimize, so that macOS row is omitted
                        // rather than shown dead.
                        items: [
                            {
                                text: "Zoom",
                                action: () => Compositor.dispatch("maximize-column")
                            },
                            {
                                text: "Center Window",
                                action: () => Compositor.dispatch("center-window")
                            },
                            {
                                text: "Move to Floating Layer",
                                action: () => Compositor.dispatch("toggle-window-floating")
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Bring All to Front",
                                enabled: false
                            }
                        ]
                    }

                    BarMenu {
                        screen: barWindow.screen
                        order: barScope.menuOrder
                        title: "Help"
                        items: [
                            {
                                text: "macos-shell Help",
                                enabled: false
                            },
                            {
                                text: "Report an Issue",
                                enabled: false
                            }
                        ]
                    }
                }

                // ----------------------------------------------- right side
                Row {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space1 + 2
                    height: parent.height
                    spacing: Theme.barItemSpacing

                    TrayExtras {
                        screen: barWindow.screen
                    }

                    SpotlightExtra {
                        screen: barWindow.screen
                    }

                    FocusExtra {
                        screen: barWindow.screen
                    }

                    SoundExtra {
                        screen: barWindow.screen
                    }

                    WifiExtra {
                        screen: barWindow.screen
                    }

                    BatteryExtra {
                        screen: barWindow.screen
                    }

                    ControlCenterExtra {
                        screen: barWindow.screen
                    }

                    ClockExtra {
                        screen: barWindow.screen
                    }
                }
            }
        }
    }
}
