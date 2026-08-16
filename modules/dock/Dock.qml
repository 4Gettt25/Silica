import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// The dock.
//
// One window per screen; DockApps (a single, screen-independent instance) owns
// what is in it and what clicking it does, and DockIcon draws one cell.
//
// Magnification is the interesting part. Every cell's size is a function of its
// distance from the pointer, so the layout the pointer is measured against must
// be the RESTING one — measuring against the magnified layout would let an icon
// growing under the pointer change the distance that decided how much it should
// grow, and the whole row would shiver.
//
// So this file keeps two coordinate spaces along the dock's axis:
//
//   * resting space ("u"), where every app cell is `base + gap` long. The
//     magnification falloff in DockIcon is evaluated here.
//   * animated space, what is actually on screen, where each cell is as long as
//     its current magnification makes it.
//
// The pointer arrives in animated space, so `invert()` solves for the resting
// coordinate that maps to it and publishes the result as `hoverU`. Everything
// else — cell sizes, the running dot, the tooltip, hit testing — follows from
// that one number.
Scope {
    id: root

    // The shared model. A QtObject, so it costs nothing per screen.
    DockApps {
        id: appModel
    }

    readonly property var apps: appModel

    // -------------------------------------------------------------- metrics
    readonly property string edge: Settings.dockPosition // "bottom" | "left" | "right"
    readonly property bool vertical: edge !== "bottom"

    readonly property real base: Settings.dockSize
    readonly property real peak: Settings.dockMagnification ? Math.max(base, Settings.dockMagnificationSize) : base
    readonly property bool magnifyOn: Settings.dockMagnification && peak > base && Theme.motion

    readonly property real gap: Math.max(2, Math.round(base * 0.09))
    readonly property real sepLen: Theme.space4
    // Band along the pill's inner edge that holds the running indicator; icons
    // rest on top of it.
    readonly property real dotBand: Math.max(6, Math.round(base * 0.22))
    readonly property real dotSize: 4
    readonly property real pillPad: Math.max(4, Math.round(base * 0.09))
    readonly property real dockMargin: Theme.space2

    // Cross-axis size of a cell: tall enough for a fully magnified icon.
    readonly property real pillThickness: peak + dotBand
    // Cross-axis size of the visible pill: only the resting icon plus padding.
    readonly property real pillCross: base + dotBand + pillPad * 2
    // The falloff reaches zero about two and a half icons out.
    readonly property real magRadius: (base + gap) * 2.5

    // ---------------------------------------------------------------- items
    function _sep(key) {
        return {
            "kind": "sep",
            "special": "",
            "key": key,
            "name": "",
            "glyph": "",
            "iconPath": "",
            "matchIds": [],
            "pinned": false
        };
    }

    // Pinned apps · running-but-unpinned apps · the two stacks, in macOS order
    // and with a hairline between the groups.
    readonly property var items: {
        const out = [];
        for (const it of appModel.pinnedItems)
            out.push(it);
        const extra = Settings.dockShowRecents ? appModel.runningItems : [];
        if (extra.length > 0) {
            out.push(_sep("@sep-running"));
            for (const it of extra)
                out.push(it);
        }
        out.push(_sep("@sep-stacks"));
        out.push(appModel.downloadsItem);
        out.push(appModel.trashItem);
        return out;
    }

    // ------------------------------------------------------- resting layout
    function restLen(item) {
        return (item && item.kind === "sep") ? sepLen : base + gap;
    }

    readonly property var restCenters: {
        const out = [];
        let acc = 0;
        for (const it of items) {
            const l = restLen(it);
            out.push(acc + l / 2);
            acc += l;
        }
        return out;
    }

    readonly property real restTotal: {
        let acc = 0;
        for (const it of items)
            acc += restLen(it);
        return acc;
    }

    // ------------------------------------------------------ hover inversion
    // Resting coordinate under the pointer; far outside the dock means "not
    // hovering", which makes every falloff zero.
    property real hoverU: -1000000
    property int hoverIndex: -1

    // The animated length of cell `i` if the pointer were at resting
    // coordinate `u`. Mirrors DockIcon's `falloff`/`cellLen` exactly — the two
    // must agree or the layout and the hit test drift apart.
    function animLen(i, u) {
        const it = items[i];
        if (!it || it.kind === "sep")
            return sepLen;
        const d = Math.abs(u - restCenters[i]);
        const f = (!magnifyOn || d >= magRadius) ? 0 : 0.5 * (Math.cos(Math.PI * d / magRadius) + 1);
        return base * (1 + (peak / base - 1) * f) + gap;
    }

    // Where resting coordinate `u` lands in animated space, measured from the
    // centre of the row (which is what the pill is centred on).
    function offsetFor(u) {
        let before = 0;
        let total = 0;
        for (let i = 0; i < items.length; i++) {
            const l = animLen(i, u);
            const rl = restLen(items[i]);
            const start = restCenters[i] - rl / 2;
            if (u >= start + rl)
                before += l;
            else if (u > start)
                before += l * (u - start) / rl;
            total += l;
        }
        return before - total / 2;
    }

    // offsetFor() is monotonic in u, so plain bisection inverts it; 24 halvings
    // are far below a pixel for any dock length.
    function invert(px) {
        let lo = 0;
        let hi = restTotal;
        if (px <= offsetFor(lo))
            return lo;
        if (px >= offsetFor(hi))
            return hi;
        for (let k = 0; k < 24; k++) {
            const mid = (lo + hi) / 2;
            if (offsetFor(mid) < px)
                lo = mid;
            else
                hi = mid;
        }
        return (lo + hi) / 2;
    }

    function indexAt(u) {
        for (let i = 0; i < items.length; i++) {
            const rl = restLen(items[i]);
            const s = restCenters[i] - rl / 2;
            if (u >= s && u < s + rl)
                return i;
        }
        return -1;
    }

    function clearHover() {
        hoverU = -1000000;
        hoverIndex = -1;
    }

    // ------------------------------------------------------------- clicking
    function activateIndex(i) {
        if (i < 0 || i >= items.length)
            return;
        const item = items[i];
        if (item.kind === "sep")
            return;
        if (appModel.activate(item) === "launch")
            appModel.startBounce(item.key);
    }

    // --------------------------------------------------------- context menu
    // macOS's dock menu, built per item. `action` is dispatched below.
    function menuItems(item) {
        if (!item || item.kind === "sep")
            return [];

        if (item.special === "trash")
            return [
                {
                    "text": "Open",
                    "action": "open"
                },
                {
                    "separator": true
                },
                {
                    "text": "Empty Trash",
                    "action": "empty",
                    "enabled": appModel.trashFull,
                    "destructive": true
                }
            ];

        if (item.special === "downloads")
            return [
                {
                    "text": "Open in Files",
                    "action": "open"
                }
            ];

        if (item.special === "launchpad")
            return [
                {
                    "text": "Open",
                    "action": "open"
                }
            ];

        if (item.special === "settings")
            return [
                {
                    "text": "Open",
                    "action": "open"
                },
                {
                    "separator": true
                },
                {
                    "text": "Remove from Dock",
                    "action": "pin"
                }
            ];

        const wins = appModel.toplevelsFor(item);
        const out = [];
        if (wins.length > 1)
            out.push({
                "text": "Show All Windows",
                "action": "showall"
            }, {
                "separator": true
            });
        out.push({
            "text": appModel.isPinned(item) ? "Remove from Dock" : "Keep in Dock",
            "action": "pin"
        });
        out.push({
            "separator": true
        });
        if (wins.length > 0)
            out.push({
                "text": "Hide",
                "action": "hide"
            }, {
                "text": "Quit",
                "action": "quit"
            });
        else
            out.push({
                "text": "Open",
                "action": "open"
            });
        return out;
    }

    function runMenuAction(item, action) {
        if (!item)
            return;
        switch (action) {
        case "open":
            activateIndex(items.indexOf(item));
            break;
        case "empty":
            appModel.emptyTrash();
            break;
        case "showall":
            appModel.showAllWindows(item);
            break;
        case "pin":
            appModel.setPinned(item, !appModel.isPinned(item));
            break;
        case "hide":
            appModel.hideApp(item);
            break;
        case "quit":
            appModel.quitApp(item);
            break;
        default:
            break;
        }
    }

    // The open dock menu, shared across screens (only one can be open).
    property var menuItem: null
    property real menuAnchor: 0     // centre of the icon, along the dock axis
    readonly property bool menuOpen: menuItem !== null

    function closeMenu() {
        menuItem = null;
    }

    // -------------------------------------------------------- one per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            // bottom dock: bottom + both sides. Side dock: top + bottom + its
            // own side, so the strip spans the full height.
            anchors {
                bottom: true
                top: root.vertical
                left: root.edge !== "right"
                right: root.edge !== "left"
            }
            margins {
                bottom: root.vertical ? 0 : root.dockMargin
                left: root.edge === "left" ? root.dockMargin : 0
                right: root.edge === "right" ? root.dockMargin : 0
            }

            // Auto-hide gives up the reserved strip; otherwise the dock keeps
            // windows off it, as macOS does.
            exclusiveZone: Settings.dockAutoHide ? 0 : Math.round(root.pillCross + root.dockMargin)

            color: "transparent"
            // Clicking a dock icon must never move keyboard focus away from
            // the user's window (see DESIGN.md "Keyboard focus").
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "macos-shell-dock"

            // The window is deliberately bigger than the pill: magnified icons
            // and the tooltip draw in the headroom.
            readonly property real thickness: root.pillPad + root.pillThickness + 40
            implicitHeight: root.vertical ? 0 : thickness
            implicitWidth: root.vertical ? thickness : 0

            // Only the pill takes input — and, while auto-hidden, the sliver
            // along the screen edge that brings it back.
            mask: Region {
                Region {
                    item: pill
                }
                Region {
                    item: revealStrip
                }
            }

            BackgroundEffect.blurRegion: Region {
                item: pill
                radius: Theme.radiusDock
            }

            // ------------------------------------------------- auto-hide
            property bool revealed: !Settings.dockAutoHide || pointer.containsMouse || root.menuOpen

            // How far the dock is pushed off screen while hidden. Not
            // readonly: it is the animated quantity.
            property real slide: revealed ? 0 : root.pillCross + root.dockMargin

            Behavior on slide {
                NumberAnimation {
                    duration: Theme.durBase
                    easing.type: Theme.easingType
                    easing.bezierCurve: Theme.easeOut
                }
            }

            Item {
                id: revealStrip
                // Zero-sized (not just invisible) when auto-hide is off: the
                // window mask reads geometry, not visibility.
                width: !Settings.dockAutoHide ? 0 : (root.vertical ? 2 : parent.width)
                height: !Settings.dockAutoHide ? 0 : (root.vertical ? parent.height : 2)
                x: root.edge === "right" ? parent.width - width : 0
                y: root.vertical ? 0 : parent.height - height
            }

            // -------------------------------------------------- the pill
            readonly property real pillLen: strip.length + root.pillPad * 2

            Item {
                id: pill

                width: root.vertical ? root.pillCross : win.pillLen
                height: root.vertical ? win.pillLen : root.pillCross
                x: {
                    switch (root.edge) {
                    case "left":
                        return -win.slide;
                    case "right":
                        return parent.width - width + win.slide;
                    default:
                        return (parent.width - width) / 2;
                    }
                }
                y: root.vertical ? (parent.height - height) / 2 : parent.height - height + win.slide

                Shadow {
                    anchors.fill: parent
                    radius: Theme.radiusDock
                }

                Vibrancy {
                    anchors.fill: parent
                    material: "dock"
                    radius: Theme.radiusDock
                }
            }

            // ------------------------------------------------- the icons
            // The strip of cells. It is bottom-aligned inside the pill and
            // taller than it, so magnified icons grow into the headroom.
            Item {
                id: strip

                readonly property real length: root.vertical ? vCol.implicitHeight : hRow.implicitWidth

                width: root.vertical ? root.pillThickness : length
                height: root.vertical ? length : root.pillThickness
                x: {
                    switch (root.edge) {
                    case "left":
                        return root.pillPad - win.slide;
                    case "right":
                        return parent.width - root.pillPad - width + win.slide;
                    default:
                        return (parent.width - width) / 2;
                    }
                }
                y: root.vertical ? (parent.height - height) / 2 : parent.height - root.pillPad - height + win.slide

                // Two positioners rather than one Flow: only the one matching
                // the dock's orientation is ever populated, so the idle one
                // costs nothing.
                Row {
                    id: hRow
                    visible: !root.vertical
                    width: implicitWidth
                    height: implicitHeight

                    Repeater {
                        model: root.vertical ? [] : root.items
                        delegate: DockIcon {
                            dock: root
                        }
                    }
                }

                Column {
                    id: vCol
                    visible: root.vertical
                    width: implicitWidth
                    height: implicitHeight

                    Repeater {
                        model: root.vertical ? root.items : []
                        delegate: DockIcon {
                            dock: root
                        }
                    }
                }
            }

            // ---------------------------------------------------- pointer
            // One tracker for the whole dock: individual cells must not own
            // hover, because the cell under the pointer is only known after
            // the resting coordinate has been solved for.
            MouseArea {
                id: pointer
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                function track(mx, my) {
                    const p = mapToItem(strip, mx, my);
                    const along = root.vertical ? p.y : p.x;
                    const across = root.vertical ? p.x : p.y;
                    const crossLen = root.vertical ? strip.width : strip.height;
                    const alongLen = root.vertical ? strip.height : strip.width;

                    // Outside the strip: no magnification, no selection.
                    if (across < 0 || across > crossLen || along < -8 || along > alongLen + 8) {
                        root.clearHover();
                        return;
                    }

                    const u = root.invert(along - alongLen / 2);
                    root.hoverU = u;
                    root.hoverIndex = root.indexAt(u);
                }

                onPositionChanged: mouse => track(mouse.x, mouse.y)
                // A press that arrives without a preceding move (a tap, or the
                // pointer warping onto the dock) still has to know its cell.
                onPressed: mouse => track(mouse.x, mouse.y)
                onExited: root.clearHover()

                onClicked: mouse => {
                    const i = root.hoverIndex;
                    if (i < 0)
                        return;
                    if (mouse.button === Qt.RightButton) {
                        const cell = root.items[i];
                        if (cell.kind === "sep")
                            return;
                        // Anchor the menu on the icon's animated centre, in
                        // screen coordinates. A side dock's window is pushed
                        // down by whatever the menu bar reserves, so that
                        // offset has to be added back.
                        const originShift = root.vertical ? (Settings.menuBarAutoHide ? 0 : Theme.barHeight) : 0;
                        root.menuAnchor = originShift + (root.vertical ? strip.y : strip.x) + root.offsetFor(root.restCenters[i]) + (root.vertical ? strip.height : strip.width) / 2;
                        root.menuItem = cell;
                    } else {
                        root.activateIndex(i);
                    }
                }
            }

            // ----------------------------------------------- context menu
            // Its own overlay window: the dock window is only as tall as the
            // pill plus headroom, and a dock menu is taller than that.
            LazyLoader {
                active: root.menuOpen

                PanelWindow {
                    id: menuWin
                    screen: win.screen

                    anchors {
                        top: true
                        bottom: true
                        left: true
                        right: true
                    }
                    exclusionMode: ExclusionMode.Ignore
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Overlay
                    WlrLayershell.namespace: "macos-shell-dockmenu"
                    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                    BackgroundEffect.blurRegion: Region {
                        item: card
                        radius: Theme.radiusMenu
                    }

                    Item {
                        anchors.fill: parent
                        focus: true

                        Keys.onEscapePressed: root.closeMenu()

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: root.closeMenu()
                        }
                    }

                    MenuCard {
                        id: card
                        screenRef: menuWin.screen
                        items: root.menuItems(root.menuItem)

                        readonly property real edgeGap: root.dockMargin + root.pillCross + Theme.space2

                        x: {
                            switch (root.edge) {
                            case "left":
                                return edgeGap;
                            case "right":
                                return parent.width - edgeGap - width;
                            default:
                                return Math.max(Theme.space2, Math.min(parent.width - width - Theme.space2, root.menuAnchor - width / 2));
                            }
                        }
                        y: root.vertical ? Math.max(Theme.barHeight + Theme.space2, Math.min(parent.height - height - Theme.space2, root.menuAnchor - height / 2)) : parent.height - edgeGap - height

                        onActivated: entry => {
                            const item = root.menuItem;
                            root.closeMenu();
                            root.runMenuAction(item, entry.action);
                        }
                        onDismissed: root.closeMenu()
                    }
                }
            }
        }
    }
}
