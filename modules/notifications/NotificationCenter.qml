import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"
import "widgets"

// The macOS Notification Center: the panel that slides in from the right edge
// under the menu bar, driven by ShellState.notificationCenterOpen.
//
// Public entry point: `NotificationCenter {}` in shell.qml.
Scope {
    id: root

    readonly property bool open: ShellState.notificationCenterOpen

    // The LazyLoader has to outlive the flag by one animation so the panel can
    // slide back out before the surface is destroyed.
    property bool alive: false

    onOpenChanged: {
        if (root.open) {
            closeTimer.stop();
            root.alive = true;
            // Opening Notification Center clears the unread badge, as in macOS.
            NotificationStore.markAllRead();
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.durBase + 40
        onTriggered: root.alive = false
    }

    LazyLoader {
        active: root.alive

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // Transient surface created through a LazyLoader, so it only holds
            // focus while it is open — needed for Esc to close it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Only the left corners are rounded (the panel is flush with the
            // right screen edge), so the blur region uses per-corner radii.
            BackgroundEffect.blurRegion: Region {
                Region {
                    x: Math.round(panel.x)
                    y: Math.round(panel.y)
                    width: panel.width
                    height: panel.height
                    topLeftRadius: Theme.radiusPopover
                    bottomLeftRadius: Theme.radiusPopover
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: ShellState.notificationCenterOpen = false
            }

            // Click-away layer.
            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.notificationCenterOpen = false
            }

            Item {
                id: panel

                property bool shown: false

                width: NotifMetrics.panelWidth
                y: Theme.barHeight
                height: parent.height - Theme.barHeight
                x: parent.width - width + (panel.shown ? 0 : width)
                opacity: panel.shown ? 1 : 0

                // Playing the entry animation needs a value change after the
                // Behaviors exist, so it is flipped on completion.
                Component.onCompleted: panel.shown = true

                Connections {
                    target: ShellState

                    function onNotificationCenterOpenChanged() {
                        panel.shown = ShellState.notificationCenterOpen;
                    }
                }

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                // Swallow clicks so they never reach the click-away layer.
                MouseArea {
                    anchors.fill: parent
                }

                // The surface is drawn wider than the panel and its right half
                // hangs off the screen, so only the left corners show a
                // radius while still using the shared material component.
                Shadow {
                    anchors.fill: surface
                    radius: Theme.radiusPopover
                }

                Vibrancy {
                    id: surface
                    anchors.fill: parent
                    anchors.rightMargin: -Theme.radiusPopover
                    material: "sidebar"
                    radius: Theme.radiusPopover
                }

                // ------------------------------------------------ content
                Flickable {
                    id: flick

                    anchors.fill: parent
                    anchors.leftMargin: Theme.space2
                    anchors.rightMargin: Theme.space4
                    anchors.topMargin: Theme.space3
                    anchors.bottomMargin: Theme.space3
                    clip: true
                    contentWidth: width
                    contentHeight: column.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    flickDeceleration: 3000

                    property bool scrolling: false
                    onContentYChanged: {
                        flick.scrolling = true;
                        scrollFade.restart();
                    }

                    Timer {
                        id: scrollFade
                        interval: 900
                        onTriggered: flick.scrolling = false
                    }

                    Column {
                        id: column
                        // Inset from the Flickable's clip rect so the cards'
                        // hover close buttons, which overhang the top-left
                        // corner, are not cut off.
                        x: Theme.space1 + 2
                        width: flick.width - x
                        spacing: Theme.space2

                        // ------------------------------ notifications header
                        Item {
                            width: parent.width
                            height: Math.max(sectionTitle.implicitHeight, clearAll.implicitHeight)
                            visible: !NotificationStore.empty

                            StyledText {
                                id: sectionTitle
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                role: "title3"
                                text: "Notifications"
                            }

                            MacButton {
                                id: clearAll
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                variant: "text"
                                text: "Clear All"
                                onClicked: NotificationStore.clearAll()
                            }
                        }

                        Repeater {
                            model: NotificationStore.groups

                            delegate: NotificationGroup {
                                required property var modelData

                                width: column.width
                                group: modelData
                            }
                        }

                        // ------------------------------------- empty state
                        Item {
                            width: parent.width
                            height: NotifMetrics.panelWidth * 0.55
                            visible: NotificationStore.empty

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.space2

                                Glyph {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    name: "bell"
                                    size: 34
                                    color: Theme.tertiaryLabel
                                }

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    role: "title3"
                                    color: Theme.tertiaryLabel
                                    text: "No Notifications"
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: Theme.space2
                        }

                        StyledText {
                            role: "title3"
                            text: "Today"
                        }

                        CalendarWidget {
                            width: column.width
                        }

                        // Two square widgets side by side; the clock centres
                        // itself when there is no battery to pair it with.
                        Item {
                            width: parent.width
                            height: clock.height

                            readonly property real cell: (width - Theme.space3) / 2

                            ClockWidget {
                                id: clock
                                width: parent.cell
                                height: width
                                x: battery.available ? 0 : (parent.width - width) / 2
                            }

                            BatteryWidget {
                                id: battery
                                width: parent.cell
                                height: width
                                x: parent.width - width
                                visible: available
                            }
                        }

                        // ---------------------------------- do not disturb
                        Popover {
                            width: column.width
                            height: dndRow.implicitHeight + Theme.space3 * 2
                            radius: Theme.radiusPopover
                            contentPadding: Theme.space3

                            Row {
                                id: dndRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.space2

                                Glyph {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "moon.zzz"
                                    size: 18
                                    color: ShellState.doNotDisturb ? Theme.accent : Theme.secondaryLabel
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - parent.spacing * 2 - 18 - dndSwitch.width
                                    role: "body"
                                    elide: Text.ElideRight
                                    text: "Do Not Disturb"
                                }

                                MacSwitch {
                                    id: dndSwitch
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: ShellState.doNotDisturb
                                    onToggled: value => ShellState.doNotDisturb = value
                                }
                            }

                            // Clicking the switch breaks its `checked` binding,
                            // so external changes are pushed back explicitly.
                            Connections {
                                target: ShellState

                                function onDoNotDisturbChanged() {
                                    dndSwitch.checked = ShellState.doNotDisturb;
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: Theme.space2
                        }
                    }
                }

                // macOS overlay scrollbar: thin, fades in while scrolling.
                Rectangle {
                    id: scrollbar

                    readonly property real trackHeight: flick.height
                    readonly property bool needed: flick.contentHeight > flick.height + 1

                    width: 5
                    radius: width / 2
                    antialiasing: true
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.28)
                    x: parent.width - width - Theme.space1
                    y: flick.y + flick.visibleArea.yPosition * trackHeight
                    height: Math.max(Theme.space6, flick.visibleArea.heightRatio * trackHeight)
                    visible: scrollbar.needed
                    opacity: flick.scrolling ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durBase
                        }
                    }
                }
            }
        }
    }
}
