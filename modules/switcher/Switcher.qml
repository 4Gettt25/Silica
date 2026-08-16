import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

// The Command-Tab application switcher.
//
// macOS switches *applications*, not windows, and orders them most-recently-
// used first. The foreign-toplevel protocol reports neither grouping nor
// recency, so both are built here: toplevels are folded by app id, and an MRU
// list is maintained from Compositor.activeToplevel while the shell runs. That
// tracker lives in this Scope (not in the overlay) so the order survives the
// window being destroyed on every close.
//
// Bind the compositor's switcher key to it — and keep the modifier in the
// binding, because the overlay commits when that modifier is released:
//   niri:      Alt+Tab repeat=false { spawn "qs" "-c" "macos-shell" "ipc" "call" "switcher" "next"; }
//              Alt+Shift+Tab repeat=false { spawn "qs" "-c" "macos-shell" "ipc" "call" "switcher" "prev"; }
//   hyprland:  bind = ALT, TAB, exec, qs -c macos-shell ipc call switcher next
//              bind = ALT SHIFT, TAB, exec, qs -c macos-shell ipc call switcher prev
Scope {
    id: root

    // App ids, most recently focused first. Lowercased; "" is never stored.
    property var mru: []

    function _touch(appId) {
        const id = (appId || "").toLowerCase();
        if (id.length === 0)
            return;
        const next = mru.filter(x => x !== id);
        next.unshift(id);
        mru = next;
    }

    Connections {
        target: Compositor

        function onActiveToplevelChanged() {
            const tl = Compositor.activeToplevel;
            if (tl)
                root._touch(tl.appId);
        }
    }

    // ------------------------------------------------------------- entries
    // One row per application: the app id, a display name, every toplevel it
    // owns and the one that should be raised (its most recent).
    readonly property var entries: {
        const byApp = {};
        const order = [];
        for (const tl of Compositor.toplevels.values) {
            if (!tl)
                continue;
            const id = (tl.appId || "").toLowerCase();
            const key = id.length > 0 ? id : ("?" + (tl.title || ""));
            if (byApp[key] === undefined) {
                byApp[key] = {
                    appId: tl.appId || "",
                    key: key,
                    name: "",
                    windows: []
                };
                order.push(key);
            }
            byApp[key].windows.push(tl);
        }

        for (const key of order) {
            const e = byApp[key];
            const de = e.appId.length > 0 ? DesktopEntries.heuristicLookup(e.appId) : null;
            e.name = (de && de.name) ? de.name : (e.appId.length > 0 ? e.appId : (e.windows[0].title || "Window"));
            e.count = e.windows.length;
        }

        // MRU first, then anything the tracker has not seen yet (windows that
        // already existed when the shell started).
        const rank = {};
        for (let i = 0; i < root.mru.length; i++)
            rank[root.mru[i]] = i;
        order.sort((a, b) => (rank[a] ?? 1e9) - (rank[b] ?? 1e9));

        return order.map(k => byApp[k]);
    }

    // ---------------------------------------------------------- selection
    // Kept here rather than in the window so a second `next` while the
    // overlay is already up keeps advancing instead of restarting.
    property int index: 0

    function _open(step) {
        if (entries.length === 0)
            return;
        if (!ShellState.appSwitcherOpen) {
            // macOS starts on the *previous* app, so a tap-and-release of the
            // binding flips between the last two apps.
            index = entries.length > 1 ? (step > 0 ? 1 : entries.length - 1) : 0;
            ShellState.appSwitcherOpen = true;
        } else {
            index = (index + step + entries.length) % entries.length;
        }
    }

    function next() {
        _open(1);
    }
    function prev() {
        _open(-1);
    }

    function commit() {
        const e = (index >= 0 && index < entries.length) ? entries[index] : null;
        ShellState.appSwitcherOpen = false;
        if (!e)
            return;
        // Raise the app's most recently used window: the MRU tracker only
        // knows apps, so fall back to the first toplevel it owns.
        const tl = e.windows.find(w => w === Compositor.activeToplevel) || e.windows[0];
        if (tl)
            tl.activate();
    }

    function cancel() {
        ShellState.appSwitcherOpen = false;
    }

    // A switcher with nothing to switch to must not linger on screen.
    onEntriesChanged: if (ShellState.appSwitcherOpen && entries.length === 0)
        cancel()

    IpcHandler {
        target: "switcher"

        function next(): void {
            root.next();
        }
        function prev(): void {
            root.prev();
        }
        function commit(): void {
            root.commit();
        }
        function cancel(): void {
            root.cancel();
        }
    }

    LazyLoader {
        active: ShellState.appSwitcherOpen

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
            WlrLayershell.namespace: "macos-shell-switcher"
            // The overlay needs the keyboard to see Tab and — more importantly
            // — the release of the modifier that opened it.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // Only the panel is clickable; the rest of the screen keeps
            // hover/scroll working in the app underneath.
            mask: Region {
                item: panel
            }

            BackgroundEffect.blurRegion: Region {
                item: panel
                radius: panel.radius
            }

            // -------------------------------------------------- metrics
            readonly property real tile: 64
            readonly property real gap: Theme.space3
            readonly property real pad: Theme.space4
            // The panel never grows past the screen; icons shrink instead.
            readonly property real maxW: win.width - Theme.space6 * 4
            readonly property real naturalW: root.entries.length * tile + Math.max(0, root.entries.length - 1) * gap + pad * 2
            readonly property real squeeze: naturalW > maxW ? maxW / naturalW : 1
            readonly property real cell: Math.max(28, tile * squeeze)

            Item {
                id: panel
                readonly property real radius: Theme.radiusWindow + Theme.space1

                anchors.centerIn: parent
                width: row.width + win.pad * 2 * win.squeeze
                height: row.height + win.pad * 2 * win.squeeze + label.height + Theme.space2

                focus: true

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Tab:
                    case Qt.Key_Right:
                        root.next();
                        event.accepted = true;
                        break;
                    case Qt.Key_Backtab:
                    case Qt.Key_Left:
                        root.prev();
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.cancel();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.commit();
                        event.accepted = true;
                        break;
                    default:
                        break;
                    }
                }

                // Releasing the modifier that opened the switcher commits it,
                // exactly like letting go of Command on macOS. Both Alt and
                // Super are accepted since the binding is the user's choice.
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Control) {
                        event.accepted = true;
                        root.commit();
                    }
                }

                Shadow {
                    anchors.fill: parent
                    radius: panel.radius
                }

                Vibrancy {
                    anchors.fill: parent
                    material: "hud"
                    radius: panel.radius
                }

                Row {
                    id: row
                    x: win.pad * win.squeeze
                    y: win.pad * win.squeeze
                    spacing: win.gap * win.squeeze

                    Repeater {
                        model: root.entries

                        delegate: Item {
                            id: slot
                            required property int index
                            required property var modelData

                            width: win.cell
                            height: win.cell

                            readonly property bool selected: slot.index === root.index

                            // The selection is a rounded plate behind the icon.
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -Theme.space2 * win.squeeze
                                radius: Theme.radiusTile
                                color: Theme.fill
                                opacity: slot.selected ? 1 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.durFast
                                    }
                                }
                            }

                            AppIcon {
                                anchors.centerIn: parent
                                appId: slot.modelData.appId
                                label: slot.modelData.name
                                iconSize: win.cell
                            }

                            // macOS marks apps with an open window by a dot
                            // under the icon; every entry here has one, so the
                            // dot is only interesting for multi-window apps.
                            Rectangle {
                                visible: slot.modelData.count > 1
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.bottom
                                anchors.topMargin: Theme.space1 * win.squeeze
                                width: 4
                                height: 4
                                radius: 2
                                color: Theme.secondaryLabel
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.index = slot.index
                                onClicked: {
                                    root.index = slot.index;
                                    root.commit();
                                }
                            }
                        }
                    }
                }

                StyledText {
                    id: label
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: row.bottom
                    anchors.topMargin: Theme.space2
                    width: parent.width - Theme.space4
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    role: "body"
                    text: (root.index >= 0 && root.index < root.entries.length) ? root.entries[root.index].name : ""
                }

                // The switcher appears instantly on macOS but still fades.
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durInstant
                    }
                }
            }
        }
    }
}
