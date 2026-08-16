import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// One menu bar title (Apple / app name / File / Edit / …) plus its dropdown.
//
// The dropdown is a full-screen transparent PanelWindow that exists only while
// the menu is open (LazyLoader). Two Quickshell idioms make it behave like
// macOS:
//
//   * `exclusionMode: ExclusionMode.Ignore` — the overlay must cover the WHOLE
//     output including the strip the bar reserves, so menu coordinates are
//     plain screen coordinates.
//   * `mask: Region { item: catcher }` where `catcher` starts below the bar —
//     the bar strip is click/hover-through, so moving the pointer onto another
//     title reaches the bar window underneath and switches menus ("scrubbing").
PanelItem {
    id: root

    property string title: ""
    // Icon title (the Apple mark) instead of a text label.
    property string glyph: ""
    property real glyphSize: 14
    // Optical centering nudge for the icon title.
    property real glyphOffsetY: 0
    // An image title (the distribution logo, or the user's own picture); takes
    // precedence over `glyph` when set.
    property string iconSource: ""

    property string menuId: title.toLowerCase()
    property bool bold: false
    // MenuCard model; see common/MenuCard.qml for the entry shape.
    property var items: []
    property var screen: null
    // Every menu id in bar order — lets ←/→ walk between menus.
    property var order: []

    readonly property bool open: menuId !== "" && ShellState.openMenu === menuId

    readonly property bool iconTitle: iconSource !== "" || glyph !== ""

    implicitHeight: Theme.barHeight - 6
    implicitWidth: (iconTitle ? glyphSize + 4 : label.implicitWidth) + Theme.barItemPadding * 2
    radius: 4
    selected: open
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    readonly property color ink: open ? Theme.onSelection : Theme.label

    StyledText {
        id: label
        anchors.centerIn: parent
        visible: !root.iconTitle
        role: "bar"
        text: root.title
        font.weight: root.bold ? Theme.wSemibold : Theme.wRegular
        color: root.ink
    }

    Glyph {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.glyphOffsetY
        // Also the fallback when the configured picture cannot be loaded, so
        // a bad path can never leave an invisible menu title.
        visible: root.glyph !== "" && (root.iconSource === "" || titleImage.status === Image.Error)
        name: root.glyph
        size: root.glyphSize
        color: root.ink
    }

    Image {
        id: titleImage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        visible: root.iconSource !== "" && status !== Image.Error
        source: root.iconSource
        // Rasterise the SVG at the size it is shown at, not at its natural
        // size scaled down — that is the difference between a crisp logo and
        // a smudge.
        width: Math.round(root.glyphSize)
        height: Math.round(root.glyphSize)
        sourceSize.width: Math.round(root.glyphSize) * 2
        sourceSize.height: Math.round(root.glyphSize) * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
    }

    onClicked: ShellState.openMenu = root.open ? "" : root.menuId

    // macOS scrubbing: with a menu already open, hovering another title switches.
    onHoveredChanged: {
        if (hovered && ShellState.openMenu !== "" && !root.open)
            ShellState.openMenu = root.menuId;
    }

    // Walk to the previous/next menu title (← / →).
    function stepMenu(delta) {
        if (!order || order.length === 0)
            return;
        const i = order.indexOf(root.menuId);
        if (i < 0)
            return;
        let n = (i + delta) % order.length;
        if (n < 0)
            n += order.length;
        ShellState.openMenu = order[n];
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: popup
            screen: root.screen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            // Cover the whole output, including the strip the bar reserves.
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            // OnDemand is deliberate: the popup only exists while the menu is
            // open, and keyboard focus is what makes Esc/arrows work. Focus is
            // released when the window is destroyed on close.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            // Everything except the bar strip takes input (see file header).
            mask: Region {
                item: catcher
            }

            BackgroundEffect.blurRegion: Region {
                Region {
                    item: card
                    radius: Theme.radiusMenu
                }
                Region {
                    // null while no submenu is open => contributes nothing.
                    item: submenuLoader.item
                    radius: Theme.radiusMenu
                }
            }

            Item {
                id: catcher
                anchors.fill: parent
                anchors.topMargin: Theme.barHeight
                focus: true

                Keys.onEscapePressed: ShellState.openMenu = ""
                Keys.onUpPressed: card.moveSelection(-1)
                Keys.onDownPressed: card.moveSelection(1)
                Keys.onLeftPressed: root.stepMenu(-1)
                Keys.onRightPressed: root.stepMenu(1)
                Keys.onReturnPressed: card.activateSelected()
                Keys.onEnterPressed: card.activateSelected()

                // Click anywhere outside the card closes.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: ShellState.openMenu = ""
                }
            }

            // ---- the menu itself (screen coordinates) ----
            MenuCard {
                id: card
                screenRef: popup.screen
                items: root.items
                // Left-aligned with the title, clamped to the screen.
                readonly property int desiredX: Math.round(root.mapToItem(null, 0, 0).x)
                x: Math.max(4, Math.min(desiredX, popup.width - width - 4))
                y: Theme.barHeight + 2

                onActivated: entry => {
                    if (entry.submenu !== undefined)
                        return; // parent rows only open their submenu
                    ShellState.openMenu = "";
                    if (entry.action)
                        entry.action();
                }
            }

            // ---- submenu (opens on hover of a row that has one) ----
            // MenuCard reports the hovered row through selectedIndex.
            readonly property int submenuIndex: {
                const i = card.selectedIndex;
                const e = (i >= 0 && i < root.items.length) ? root.items[i] : null;
                return (e && e.submenu !== undefined) ? i : -1;
            }

            // y offset of row `idx` inside the card (rows and separators differ).
            function rowOffset(idx) {
                let y = card._vPad;
                for (let i = 0; i < idx; i++)
                    y += (root.items[i].separator === true) ? card.separatorHeight : card.rowHeight;
                return y;
            }

            Loader {
                id: submenuLoader
                active: popup.submenuIndex >= 0
                x: Math.max(4, Math.min(card.x + card.width - 4, popup.width - (item ? item.width : 0) - 4))
                y: card.y + (popup.submenuIndex >= 0 ? popup.rowOffset(popup.submenuIndex) : 0) - card._vPad

                sourceComponent: MenuCard {
                    screenRef: popup.screen
                    // Guarded: `active` and `submenuIndex` may settle in either
                    // order while the submenu is closing.
                    items: popup.submenuIndex >= 0 ? (root.items[popup.submenuIndex].submenu || []) : []

                    onActivated: entry => {
                        ShellState.openMenu = "";
                        if (entry.action)
                            entry.action();
                    }
                }
            }
        }
    }
}
