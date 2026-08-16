import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// The Spotlight surface: one centred card on a full-screen, click-away
// overlay window.
//
// Created and destroyed by Launcher.qml's LazyLoader, so keyboard focus goes
// back to the user's window the moment the card is gone (a layer surface that
// holds focus makes the compositor report "no focused toplevel").
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
    WlrLayershell.namespace: "macos-shell-spotlight"
    // Spotlight is a typing surface, so it takes the keyboard for as long as
    // it exists — which is only while it is open.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // macOS Sonoma proportions: a 700pt card whose top edge sits at ~22% of
    // the screen, results on the left ~40%, preview on the right.
    readonly property int cardWidth: 700
    // Spotlight's corners are rounder than a normal window's.
    readonly property real cardRadius: Theme.radiusWindow + Theme.space1
    readonly property int listWidth: Math.round(cardWidth * 0.4)
    readonly property int maxListHeight: 380

    // The compositor blurs what is behind the card (ext-background-effect-v1);
    // the region must track the card's geometry and corner radius.
    BackgroundEffect.blurRegion: Region {
        item: card
        radius: win.cardRadius
    }

    SearchModel {
        id: finder
        query: field.text
    }

    property int selectedIndex: -1
    readonly property var selectedRow: (selectedIndex >= 0 && selectedIndex < finder.rows.length) ? finder.rows[selectedIndex] : null
    readonly property bool hasResults: finder.rows.length > 0

    function firstSelectable() {
        for (let i = 0; i < finder.rows.length; i++)
            if (finder.rows[i].kind !== "header")
                return i;
        return -1;
    }

    // ↑/↓ wrap around and step over the section headers.
    function moveSelection(delta) {
        const n = finder.rows.length;
        if (n === 0) {
            selectedIndex = -1;
            return;
        }
        let i = selectedIndex;
        for (let steps = 0; steps < n; steps++) {
            i += delta;
            if (i < 0)
                i = n - 1;
            else if (i >= n)
                i = 0;
            if (finder.rows[i].kind !== "header") {
                selectedIndex = i;
                return;
            }
        }
    }

    function dismiss() {
        ShellState.launcherOpen = false;
    }

    // DesktopEntry.execute() runs the entry the way the spec says to (field
    // codes stripped, DBus activation when available); the execString branch
    // is only a safety net for an entry that somehow has no execute().
    function launchEntry(entry) {
        if (typeof entry.execute === "function") {
            entry.execute();
            return;
        }
        const cmd = (entry.execString || "").replace(/%[fFuUdDnNickvm]/g, " ").replace(/%%/g, "%").replace(/\s+/g, " ").trim();
        if (cmd.length > 0)
            Quickshell.execDetached(["sh", "-c", cmd]);
    }

    function activate(index) {
        if (index < 0 || index >= finder.rows.length)
            return;
        const row = finder.rows[index];
        switch (row.kind) {
        case "header":
            return;
        case "app":
            launchEntry(row.entry);
            break;
        case "calc":
            // Spotlight copies the result. This surface owns the keyboard, so
            // the Wayland clipboard is writable from here.
            Quickshell.clipboardText = row.plain;
            break;
        case "web":
            Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(row.term)]);
            break;
        case "run":
            Quickshell.execDetached(["sh", "-c", row.command]);
            break;
        default:
            break;
        }
        dismiss();
    }

    // ⇥ completes the query to whatever is selected.
    function completeToSelection() {
        const row = selectedRow;
        if (!row)
            return;
        const name = row.kind === "app" ? row.name : (row.kind === "calc" ? row.value : "");
        if (name.length === 0)
            return;
        field.text = name;
        field.input.cursorPosition = name.length;
    }

    Connections {
        target: finder
        // A new result set always re-selects the top hit.
        function onRowsChanged() {
            win.selectedIndex = win.firstSelectable();
        }
    }

    onSelectedIndexChanged: if (selectedIndex >= 0)
        list.positionViewAtIndex(selectedIndex, ListView.Contain)

    // Optional pre-filled query (Launcher.searchFor / `ipc call launcher search`).
    property string seed: ""
    onSeedChanged: if (seed.length > 0)
        setQuery(seed)

    function setQuery(text) {
        field.text = text;
        field.input.cursorPosition = text.length;
        field.focusInput();
    }

    Component.onCompleted: {
        field.focusInput();
        if (seed.length > 0)
            setQuery(seed);
    }

    // Click-away layer.
    MouseArea {
        anchors.fill: parent
        onClicked: win.dismiss()
    }

    Popover {
        id: card
        material: "popover"
        radius: win.cardRadius
        origin: "top"
        shown: ShellState.launcherOpen
        width: win.cardWidth
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height * 0.22)
        height: searchRow.height + separator.height + bodyHeight

        // ListView.contentHeight excludes its own margins.
        readonly property int listHeight: list.contentHeight + list.topMargin + list.bottomMargin
        readonly property int bodyHeight: win.hasResults ? Math.max(Math.min(listHeight, win.maxListHeight), preview.implicitHeight) : 0

        // The card grows and shrinks with the result set.
        Behavior on height {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }

        Item {
            id: searchRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.round(field.implicitHeight + Theme.space3)

            SearchField {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.space3
                anchors.rightMargin: Theme.space3
                fieldSize: 24
                placeholder: "Spotlight Search"

                onCancelled: win.dismiss()
                onAccepted: win.activate(win.selectedIndex)
                onUpPressed: win.moveSelection(-1)
                onDownPressed: win.moveSelection(1)
                onTabPressed: win.completeToSelection()
            }
        }

        Rectangle {
            id: separator
            anchors.top: searchRow.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: win.hasResults ? 1 : 0
            color: Theme.separator
        }

        Item {
            id: body
            anchors.top: separator.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            visible: win.hasResults

            ListView {
                id: list
                width: win.listWidth
                height: parent.height
                clip: true
                model: finder.rows
                boundsBehavior: Flickable.StopAtBounds
                topMargin: Theme.space1
                bottomMargin: Theme.space2
                // Keyboard handling lives on the search field, not here.
                keyNavigationEnabled: false

                delegate: ResultRow {
                    required property var modelData
                    required property int index

                    width: list.width
                    row: modelData
                    search: finder
                    selected: index === win.selectedIndex

                    onHovered: if (modelData.kind !== "header")
                        win.selectedIndex = index
                    onClicked: win.activate(index)
                }
            }

            // Vertical hairline between results and preview.
            Rectangle {
                x: win.listWidth
                width: 1
                height: parent.height
                color: Theme.separator
            }

            PreviewPane {
                id: preview
                anchors.left: parent.left
                anchors.leftMargin: win.listWidth + 1
                anchors.right: parent.right
                height: parent.height
                row: win.selectedRow
                search: finder
            }
        }
    }
}
