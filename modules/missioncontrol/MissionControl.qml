import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

// Mission Control (Contract: full-screen window overview).
//
// Driven by ShellState.missionControlOpen through a LazyLoader, so the overlay
// window — and its keyboard grab — only exist while it is open (see DESIGN.md
// "Keyboard focus").
//
// Bind a key to it:
//   niri:  Mod+Up { spawn "qs" "-c" "macos-shell" "ipc" "call" "missioncontrol" "toggle"; }
Scope {
    id: root

    function open() {
        ShellState.closeAll();
        ShellState.missionControlOpen = true;
    }

    function close() {
        ShellState.missionControlOpen = false;
    }

    IpcHandler {
        target: "missioncontrol"

        function toggle(): void {
            if (ShellState.missionControlOpen)
                root.close();
            else
                root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    LazyLoader {
        active: ShellState.missionControlOpen

        // One overlay on the primary screen. macOS shows Mission Control on
        // every display, but a per-screen Variants would need per-screen window
        // sets from a protocol that does not expose window geometry, so the
        // single-overlay form is the honest one here.
        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusiveZone: 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "macos-shell-missioncontrol"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Compositor-side blur of everything behind the whole surface.
            BackgroundEffect.blurRegion: Region {
                item: backdrop
            }

            // ---------------------------------------------------- metrics
            readonly property real cellGap: Theme.space5
            readonly property real labelH: Theme.fsBody + Theme.space2
            readonly property real headerH: Theme.fsCaption + Theme.space4
            readonly property real groupGap: Theme.space5
            readonly property real screenAspect: width / Math.max(1, height)

            // Spaces bar thumbnails are ~11% of the screen.
            readonly property real thumbW: Math.round(width * 0.11)
            readonly property real thumbH: Math.round(thumbW / screenAspect)

            // ------------------------------------------------------ model
            // Flat entries and workspace groups, rebuilt whenever the window
            // list or the workspace list changes.
            property var groups: []
            property real cellW: 200

            readonly property var spaces: {
                const name = (screen && screen.name) ? screen.name : "";
                const all = Compositor.workspaces;
                // Only this output's spaces; compositors that report no output
                // name (or the "unknown" backend) fall through to all of them.
                const mine = all.filter(w => w.output === name);
                return mine.length > 0 ? mine : all;
            }

            // Toplevel handles carry no workspace, so pair each one with the
            // compositor's own window record (which does) on app id + title.
            function _workspaceOf(tl, pool, used) {
                const app = (tl.appId || "").toLowerCase();
                const title = tl.title || "";
                for (let pass = 0; pass < 2; pass++) {
                    for (let i = 0; i < pool.length; i++) {
                        if (used[i])
                            continue;
                        if ((pool[i].appId || "").toLowerCase() !== app)
                            continue;
                        if (pass === 0 && (pool[i].title || "") !== title)
                            continue;
                        used[i] = true;
                        return pool[i].workspaceId;
                    }
                }
                return "";
            }

            function rebuild() {
                const tls = Compositor.toplevels.values;
                const pool = Compositor.windows;
                const used = {};
                const byWs = {};
                const order = [];

                for (const tl of tls) {
                    if (!tl)
                        continue;
                    const ws = _workspaceOf(tl, pool, used);
                    if (byWs[ws] === undefined) {
                        byWs[ws] = [];
                        order.push(ws);
                    }
                    byWs[ws].push(tl);
                }

                // Sort groups by the workspace index the compositor reports.
                const indexOf = {};
                for (const w of Compositor.workspaces)
                    indexOf[w.id] = w.index;
                order.sort((a, b) => (indexOf[a] ?? 1e9) - (indexOf[b] ?? 1e9));

                const occupied = Compositor.workspaces.filter(w => w.occupied).length;
                let seq = 0;
                const gs = [];
                const sig = [];
                for (const ws of order) {
                    const items = byWs[ws].map(tl => ({
                        tl: tl,
                        seq: seq++
                    }));
                    gs.push({
                        key: ws,
                        label: indexOf[ws] !== undefined ? ("Desktop " + indexOf[ws]) : "Other",
                        items: items
                    });
                    // App ids + count identify the layout; titles change while
                    // the overview is open and must not reshuffle it.
                    sig.push(ws + ":" + items.map(i => i.tl.appId).join("|"));
                }

                showHeaders = occupied > 1 && gs.length > 1;

                // Replacing `groups` recreates every delegate — and restarts the
                // entrance animation with it — so only do it when the layout
                // actually changed. Title edits alone must not reshuffle cards.
                const signature = sig.join(";;");
                if (signature === _signature)
                    return;
                _signature = signature;
                groups = gs;
                recomputeCell();
            }

            property string _signature: ""
            property bool showHeaders: false

            // Largest cell width whose grid still fits the available area.
            // (macOS keeps every window the same scale and shrinks all of them
            // as the count grows.)
            function recomputeCell() {
                if (groups.length === 0 || gridArea.width <= 0 || gridArea.height <= 0)
                    return;
                const availW = gridArea.width;
                const availH = gridArea.height;
                // Never let a lone window fill the screen — macOS keeps a
                // comfortable margin around the biggest card.
                const maxW = Math.floor(Math.min(availW, width * 0.32));
                const minW = 140;
                let best = minW;
                for (let w = maxW; w >= minW; w -= 6) {
                    const cols = Math.max(1, Math.floor((availW + cellGap) / (w + cellGap)));
                    let h = 0;
                    for (const g of groups) {
                        const rows = Math.ceil(g.items.length / cols);
                        h += (showHeaders ? headerH : 0) + rows * (w / screenAspect + labelH + cellGap);
                    }
                    h += Math.max(0, groups.length - 1) * groupGap;
                    if (h <= availH) {
                        best = w;
                        break;
                    }
                }
                cellW = best;
            }

            readonly property int columns: Math.max(1, Math.floor((gridArea.width + cellGap) / (cellW + cellGap)))

            // Split a group's windows into centred rows of `columns`.
            function chunk(items, n) {
                const out = [];
                for (let i = 0; i < items.length; i += n)
                    out.push(items.slice(i, i + n));
                return out;
            }

            Component.onCompleted: rebuild()
            onWidthChanged: recomputeCell()
            onHeightChanged: recomputeCell()

            // ObjectModel emits valuesChanged on insert/remove.
            Connections {
                target: Compositor.toplevels
                function onValuesChanged() {
                    win.rebuild();
                }
            }
            Connections {
                target: Compositor
                function onWindowsChanged() {
                    win.rebuild();
                }
                function onWorkspacesChanged() {
                    win.rebuild();
                }
            }

            // ------------------------------------------------------- chrome
            Item {
                id: backdrop
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: event => {
                    event.accepted = true;
                    root.close();
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.scrim
                }

                // Click on empty space dismisses; cards and tiles sit above.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // ------------------------------------------- spaces bar
                Row {
                    id: spacesBar
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.barHeight + Theme.space3
                    spacing: Theme.space3

                    Repeater {
                        model: win.spaces

                        delegate: SpaceThumb {
                            required property var modelData

                            width: win.thumbW
                            height: win.thumbH
                            index: modelData.index
                            active: modelData.active
                            onActivated: {
                                Compositor.activateWorkspace(modelData.id);
                                root.close();
                            }
                        }
                    }

                    // No trailing "+" tile: niri creates workspaces implicitly
                    // and always keeps one empty space at the end of the list
                    // (it is already rendered above), so a "+" would either be
                    // a duplicate or a fake button.
                }

                // ------------------------------------------- window grid
                Item {
                    id: gridArea
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: spacesBar.bottom
                        bottom: parent.bottom
                        leftMargin: Theme.space6 * 2
                        rightMargin: Theme.space6 * 2
                        topMargin: Theme.space5
                        bottomMargin: Theme.space5
                    }
                    onWidthChanged: win.recomputeCell()
                    onHeightChanged: win.recomputeCell()

                    StyledText {
                        anchors.centerIn: parent
                        visible: win.groups.length === 0
                        role: "title2"
                        color: Theme.alwaysLight
                        opacity: 0.7
                        text: "No Windows"
                    }

                    Column {
                        id: groupColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        spacing: win.groupGap

                        Repeater {
                            model: win.groups

                            delegate: Column {
                                id: groupItem
                                required property var modelData

                                width: groupColumn.width
                                spacing: Theme.space1

                                StyledText {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: win.showHeaders
                                    height: visible ? implicitHeight : 0
                                    role: "caption"
                                    color: Theme.alwaysLight
                                    opacity: 0.65
                                    text: groupItem.modelData.label
                                }

                                Column {
                                    width: parent.width
                                    spacing: win.cellGap

                                    Repeater {
                                        // Rows are built explicitly (rather than
                                        // with a Grid) so the last, short row is
                                        // centred like macOS does it.
                                        model: win.chunk(groupItem.modelData.items, win.columns)

                                        delegate: Row {
                                            id: gridRow
                                            required property var modelData

                                            anchors.horizontalCenter: parent.horizontalCenter
                                            spacing: win.cellGap

                                            Repeater {
                                                model: gridRow.modelData

                                                delegate: WindowCard {
                                                    required property var modelData

                                                    toplevel: modelData.tl
                                                    seq: modelData.seq
                                                    cellWidth: win.cellW
                                                    cellHeight: win.cellW / win.screenAspect
                                                    labelHeight: win.labelH
                                                    fallbackAspect: win.screenAspect

                                                    onActivated: {
                                                        if (toplevel)
                                                            toplevel.activate();
                                                        root.close();
                                                    }
                                                    onCloseRequested: {
                                                        if (toplevel)
                                                            toplevel.close();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
