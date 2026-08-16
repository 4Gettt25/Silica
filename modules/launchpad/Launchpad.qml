import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

// Launchpad: the full-screen, paged grid of every installed application.
//
// Like Mission Control it lives behind a LazyLoader keyed on its ShellState
// flag, so the overlay window — and the keyboard grab that comes with it —
// only exists while Launchpad is open (see DESIGN.md "Keyboard focus").
//
// Bind a key to it:
//   niri:      Mod+A { spawn "qs" "-c" "macos-shell" "ipc" "call" "launchpad" "toggle"; }
//   hyprland:  bind = SUPER, A, exec, qs -c macos-shell ipc call launchpad toggle
Scope {
    id: root

    function open() {
        ShellState.launchpadOpen = true;
    }

    function close() {
        ShellState.launchpadOpen = false;
    }

    IpcHandler {
        target: "launchpad"

        function toggle(): void {
            ShellState.launchpadOpen = !ShellState.launchpadOpen;
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    LazyLoader {
        active: ShellState.launchpadOpen

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
            WlrLayershell.namespace: "macos-shell-launchpad"
            // Launchpad is a typing surface (type-to-filter), so it holds the
            // keyboard for as long as it exists.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // The compositor blurs the whole desktop behind the overlay.
            BackgroundEffect.blurRegion: Region {
                item: backdrop
            }

            // ------------------------------------------------------- model
            // Every visible application, sorted the way macOS sorts Launchpad:
            // case-insensitively by display name.
            readonly property var allApps: {
                const out = [];
                for (const e of DesktopEntries.applications.values) {
                    if (!e || e.noDisplay)
                        continue;
                    out.push(e);
                }
                out.sort((a, b) => (a.name || "").toLowerCase().localeCompare((b.name || "").toLowerCase()));
                return out;
            }

            property string query: ""

            // Launchpad filters by a plain case-insensitive substring — it is
            // not Spotlight, and macOS does not fuzzy-match here either.
            readonly property var apps: {
                const q = query.trim().toLowerCase();
                if (q.length === 0)
                    return allApps;
                const out = [];
                for (const e of allApps) {
                    if ((e.name || "").toLowerCase().indexOf(q) >= 0 || (e.genericName || "").toLowerCase().indexOf(q) >= 0)
                        out.push(e);
                }
                return out;
            }

            // ----------------------------------------------------- metrics
            // macOS lays Launchpad out as 7×5 on a laptop display and adds
            // columns on larger ones; the grid always keeps generous margins.
            readonly property int columns: Math.max(4, Math.min(9, Math.round(width / 210)))
            readonly property int rows: Math.max(3, Math.min(6, Math.round(gridArea.height / 190)))
            readonly property int perPage: Math.max(1, columns * rows)

            readonly property int pageCount: Math.max(1, Math.ceil(apps.length / perPage))
            property int page: 0

            readonly property real cellW: gridArea.width / columns
            readonly property real cellH: gridArea.height / rows
            // The label needs about a third of the cell; the icon takes the
            // rest, capped so a sparse grid does not grow absurd icons.
            readonly property real iconSize: Math.max(48, Math.min(112, Math.min(cellW * 0.55, cellH * 0.58)))

            // Slice `apps` into pages of `perPage`.
            readonly property var pages: {
                const out = [];
                for (let i = 0; i < apps.length; i += perPage)
                    out.push(apps.slice(i, i + perPage));
                return out.length > 0 ? out : [[]];
            }

            // A shrinking result set must never leave us on a page past the end.
            onPageCountChanged: if (page > pageCount - 1)
                page = pageCount - 1
            onQueryChanged: page = 0

            function goto(p) {
                page = Math.max(0, Math.min(pageCount - 1, p));
            }

            // --------------------------------------------------- launching
            // Same contract as Spotlight: DesktopEntry.execute() handles field
            // codes and DBus activation; execString is only a safety net.
            function launch(entry) {
                if (!entry)
                    return;
                if (typeof entry.execute === "function") {
                    entry.execute();
                } else {
                    const cmd = (entry.execString || "").replace(/%[fFuUdDnNickvm]/g, " ").replace(/%%/g, "%").replace(/\s+/g, " ").trim();
                    if (cmd.length > 0)
                        Quickshell.execDetached(["sh", "-c", cmd]);
                }
                root.close();
            }

            // Enter launches the first match, which is the only selection
            // Launchpad has.
            function activateFirst() {
                if (apps.length > 0)
                    launch(apps[0]);
            }

            // ------------------------------------------------------ chrome
            Item {
                id: backdrop
                anchors.fill: parent

                Rectangle {
                    anchors.fill: parent
                    color: Theme.scrim
                }

                // Clicking the empty space between tiles closes Launchpad.
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()

                    // Vertical wheel pages sideways, the way a trackpad swipe
                    // does on macOS. Deltas are accumulated so a high-res
                    // wheel does not fly through every page at once.
                    property real accum: 0
                    onWheel: wheel => {
                        const d = (wheel.angleDelta.x !== 0) ? -wheel.angleDelta.x : wheel.angleDelta.y;
                        accum += d;
                        if (accum <= -120) {
                            accum = 0;
                            win.goto(win.page + 1);
                        } else if (accum >= 120) {
                            accum = 0;
                            win.goto(win.page - 1);
                        }
                    }
                }

                // Left/Right page even while the search field owns the
                // keyboard, matching macOS. Shortcuts are seen before the
                // focused TextInput, so the field never eats them.
                Shortcut {
                    sequences: ["Left"]
                    onActivated: win.goto(win.page - 1)
                }
                Shortcut {
                    sequences: ["Right"]
                    onActivated: win.goto(win.page + 1)
                }

                // ----------------------------------------------- search
                SearchField {
                    id: field
                    focus: true
                    width: Math.min(320, win.width * 0.3)
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Theme.barHeight + Theme.space5
                    fieldSize: 15
                    showBackground: true
                    placeholder: "Search"

                    onTextChanged: win.query = text
                    onAccepted: win.activateFirst()
                    // First Esc clears the filter, second closes — as in macOS.
                    onCancelled: {
                        if (text.length > 0)
                            clear();
                        else
                            root.close();
                    }
                    onDownPressed: win.goto(win.page + 1)
                    onUpPressed: win.goto(win.page - 1)
                    onTabPressed: win.goto(win.page + 1)

                    Component.onCompleted: focusInput()
                }

                // ------------------------------------------------- grid
                Item {
                    id: gridArea
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: field.bottom
                        bottom: parent.bottom
                        leftMargin: Math.round(win.width * 0.08)
                        rightMargin: Math.round(win.width * 0.08)
                        topMargin: Theme.space6
                        // Reserves the strip the page dots and the dock sit
                        // in. It is a constant rather than an anchor to the
                        // dots, because `dots.visible` is derived from the
                        // page count, which is derived from this height.
                        bottomMargin: Theme.space6 * 4
                    }
                    clip: true

                    StyledText {
                        anchors.centerIn: parent
                        visible: win.apps.length === 0
                        role: "title2"
                        color: Theme.alwaysLight
                        opacity: 0.7
                        text: "No Results"
                    }

                    // The pages sit side by side in one strip that slides.
                    Row {
                        id: strip
                        height: parent.height
                        x: -win.page * gridArea.width

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.durBase
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easeOut
                            }
                        }

                        Repeater {
                            model: win.pages

                            delegate: Grid {
                                id: pageGrid
                                required property var modelData

                                width: gridArea.width
                                height: gridArea.height
                                columns: win.columns

                                Repeater {
                                    model: pageGrid.modelData

                                    delegate: AppTile {
                                        required property var modelData

                                        width: win.cellW
                                        height: win.cellH
                                        entry: modelData
                                        iconSize: win.iconSize
                                        onActivated: win.launch(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------- page dots
                Row {
                    id: dots
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: gridArea.bottom
                    anchors.topMargin: Theme.space5
                    spacing: Theme.space2
                    visible: win.pageCount > 1
                    height: 8

                    Repeater {
                        model: win.pageCount

                        delegate: Rectangle {
                            id: dot
                            required property int index

                            width: 8
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alwaysLight
                            opacity: dot.index === win.page ? 0.9 : 0.35

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.durFast
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -Theme.space1
                                onClicked: win.goto(dot.index)
                            }
                        }
                    }
                }

                // macOS zooms Launchpad in from slightly oversized while it
                // fades up; the whole backdrop is the animated item.
                opacity: 0
                scale: 1.08
                Component.onCompleted: {
                    opacity = 1;
                    scale = 1;
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durFast
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }
            }
        }
    }
}
