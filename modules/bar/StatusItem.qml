import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// Base for a "menu bar extra" — the clickable items on the right of the bar.
//
// An extra either performs an action (`activated`) or owns a popover. Popovers
// go through `ShellState.openMenu = "extra:<id>"` so ShellState's exclusivity
// guarantees only one menu OR popover is ever open.
//
// The popover lives in its own full-screen overlay window (created only while
// open) which — like the app menus — excludes the bar strip from its input
// mask, so clicking a different extra switches directly instead of just
// dismissing.
PanelItem {
    id: root

    property string extraId: ""
    property var screen: null
    // Popover body. Given `width`; must supply `implicitHeight`.
    property Component popover: null
    property int popoverWidth: 280
    property int popoverPadding: Theme.space3

    readonly property bool open: extraId !== "" && ShellState.openMenu === "extra:" + extraId

    // Emitted on click when this extra has no popover.
    signal activated

    implicitHeight: Theme.barHeight - 6
    implicitWidth: 24
    radius: 4
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    acceptedButtons: Qt.LeftButton
    // The open extra gets a neutral fill in macOS, not the accent.
    color: (open || (hovered && interactive)) ? (pressed || open ? Theme.pressed : Theme.hover) : "transparent"

    function toggle() {
        ShellState.openMenu = root.open ? "" : ("extra:" + root.extraId);
    }

    onClicked: {
        if (popover)
            toggle();
        else
            root.activated();
    }

    LazyLoader {
        active: root.open && root.popover !== null

        PanelWindow {
            id: popup
            screen: root.screen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            mask: Region {
                item: catcher
            }

            BackgroundEffect.blurRegion: Region {
                item: card
                radius: card.radius
            }

            Item {
                id: catcher
                anchors.fill: parent
                anchors.topMargin: Theme.barHeight
                focus: true

                Keys.onEscapePressed: ShellState.openMenu = ""

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: ShellState.openMenu = ""
                }
            }

            Popover {
                id: card
                screenRef: popup.screen
                width: root.popoverWidth
                height: body.implicitHeight + root.popoverPadding * 2

                // Centred under the bar item, clamped to the screen edges.
                readonly property real anchorCenter: root.mapToItem(null, root.width / 2, 0).x
                x: Math.round(Math.max(8, Math.min(anchorCenter - width / 2, popup.width - width - 8)))
                y: Theme.barHeight + 2

                Loader {
                    id: body
                    x: root.popoverPadding
                    y: root.popoverPadding
                    width: card.width - root.popoverPadding * 2
                    sourceComponent: root.popover
                }
            }
        }
    }
}
