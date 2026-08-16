import QtQuick
import Quickshell
import Quickshell.Io
import "../../common"

// The screen-independent brain behind the dock.
//
// One instance lives in Dock.qml and feeds every per-screen dock window: which
// apps are running, how to launch / activate / hide / quit them, plus the state
// of the two trailing "stacks" (Downloads and Trash).
//
// The static half — the desktop-entry index, the default dock set and the
// pinned list — lives in the `Apps` singleton, because System Settings edits
// exactly the same data.
//
// It is a QtObject rather than an Item because it draws nothing; children that
// need to be instantiated (Process, Timer, Connections) are declared as typed
// properties, which is the QML way of parenting objects to a QtObject.
QtObject {
    id: apps

    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string trashFilesDir: home + "/.local/share/Trash/files"
    readonly property string downloadsDir: home + "/Downloads"

    // ------------------------------------------------------------- helpers
    // Thin forwarders to the Apps singleton, kept so the dock's delegates and
    // menus read the same as before.
    function normalize(s) {
        return Apps.normalize(s);
    }

    function entryFor(key) {
        return Apps.entryFor(key);
    }

    function makeItem(key, pinned) {
        return Apps.makeItem(key, pinned);
    }

    readonly property var pinnedKeys: Apps.pinnedKeys

    readonly property var pinnedItems: {
        const out = [];
        for (const k of pinnedKeys)
            out.push(Apps.makeItem(k, true));
        return out;
    }

    readonly property var pinnedMatchIds: {
        const s = {};
        for (const it of pinnedItems)
            for (const m of it.matchIds)
                s[m] = true;
        return s;
    }

    // Running apps that are not pinned, one entry per app id, in the order
    // their first window appeared. Re-evaluates when toplevels come and go.
    readonly property var runningItems: {
        const out = [];
        const seen = {};
        for (const tl of Compositor.toplevels.values) {
            const n = normalize(tl.appId);
            if (n.length === 0 || seen[n] === true || pinnedMatchIds[n] === true)
                continue;
            seen[n] = true;
            const e = Apps.entryIndex[n];
            const key = (e !== undefined && e !== null) ? e.id : tl.appId;
            const item = makeItem(key, false);
            // Keep the raw app id as a match key even when no entry was found.
            if (item.matchIds.indexOf(n) < 0)
                item.matchIds.push(n);
            out.push(item);
        }
        return out;
    }

    readonly property var downloadsItem: ({
            "kind": "app",
            "special": "downloads",
            "key": "@downloads",
            "name": "Downloads",
            "glyph": "folder",
            "iconPath": Apps.resolveIcon(["folder-download", "folder-downloads", "download", "folder"]),
            "matchIds": [],
            "pinned": true
        })

    readonly property var trashItem: ({
            "kind": "app",
            "special": "trash",
            "key": "@trash",
            "name": "Trash",
            "glyph": "trash",
            // The "full" variant is swapped in as soon as the probe below sees
            // something in ~/.local/share/Trash/files.
            "iconPath": trashFull ? Apps.resolveIcon(["user-trash-full", "trash-full", "user-trash"]) : Apps.resolveIcon(["user-trash", "user-trash-empty", "trashcan_empty"]),
            "matchIds": [],
            "pinned": true
        })

    // ------------------------------------------------------------- matching
    function toplevelsFor(item) {
        const out = [];
        if (!item || item.kind !== "app" || item.matchIds === undefined || item.matchIds.length === 0)
            return out;
        for (const tl of Compositor.toplevels.values) {
            if (item.matchIds.indexOf(normalize(tl.appId)) >= 0)
                out.push(tl);
        }
        return out;
    }

    function isRunning(item) {
        return toplevelsFor(item).length > 0;
    }

    // Most-recently-used order of foreign toplevels, newest first. Entries of
    // closed windows are never dereferenced, only compared, so a stale handle
    // in the list is harmless.
    property var mru: []

    property Connections activeWatcher: Connections {
        target: Compositor
        function onActiveToplevelChanged() {
            const t = Compositor.activeToplevel;
            if (!t)
                return;
            const next = [t];
            for (const o of apps.mru)
                if (o !== t && next.length < 32)
                    next.push(o);
            apps.mru = next;
        }
    }

    function mostRecent(wins) {
        for (const o of mru)
            if (wins.indexOf(o) >= 0)
                return o;
        return wins[0];
    }

    // -------------------------------------------------------------- actions

    // DesktopEntry.execute() when Quickshell provides it, otherwise the Exec
    // string with desktop-entry field codes stripped.
    function launch(item) {
        return Apps.launchKey(item.key);
    }

    // Returns "launch" when a bounce should be started, "" otherwise.
    function activate(item) {
        switch (item.special) {
        case "launchpad":
            ShellState.launchpadOpen = true;
            return "";
        case "settings":
            ShellState.openSettings("");
            return "";
        case "trash":
            Quickshell.execDetached(["xdg-open", "trash:///"]);
            return "";
        case "downloads":
            Quickshell.execDetached(["xdg-open", downloadsDir]);
            return "";
        }

        const wins = toplevelsFor(item);
        if (wins.length === 0)
            return launch(item) ? "launch" : "";

        // Already frontmost with several windows: cycle to the next one.
        const active = Compositor.activeToplevel;
        const idx = active ? wins.indexOf(active) : -1;
        const target = (idx >= 0 && wins.length > 1) ? wins[(idx + 1) % wins.length] : mostRecent(wins);
        if (target.minimized)
            target.minimized = false;
        target.activate();
        return "";
    }

    function showAllWindows(item) {
        const wins = toplevelsFor(item);
        for (const t of wins)
            if (t.minimized)
                t.minimized = false;
        if (wins.length > 0)
            mostRecent(wins).activate();
    }

    function hideApp(item) {
        for (const t of toplevelsFor(item))
            t.minimized = true;
    }

    function quitApp(item) {
        for (const t of toplevelsFor(item))
            t.close();
    }

    // ------------------------------------------------------------- pinning
    function isPinned(item) {
        return Apps.isPinned(item.key);
    }

    function setPinned(item, on) {
        Apps.setPinned(item.key, on);
    }

    // -------------------------------------------------------- launch bounce
    // Dock.qml bounces the icon whose key equals bounceKey; the delegate clears
    // it as soon as the app's first window shows up, and this timer is the
    // backstop for apps that never map one.
    property string bounceKey: ""

    property Timer bounceTimeout: Timer {
        interval: Theme.durSlow * 12
        onTriggered: apps.bounceKey = ""
    }

    function startBounce(key) {
        bounceKey = key;
        bounceTimeout.restart();
    }

    // --------------------------------------------------------------- trash
    property bool trashFull: false

    property Process trashProbe: Process {
        command: ["sh", "-c", "ls -A \"$HOME/.local/share/Trash/files\" 2>/dev/null | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: apps.trashFull = text.trim().length > 0
        }
    }

    // Cheap enough to poll: one `ls | head -1` every few seconds.
    property Timer trashPoll: Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: apps.trashProbe.running = true
    }

    function emptyTrash() {
        Quickshell.execDetached(["sh", "-c", "find \"$HOME/.local/share/Trash/files\" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + ; " + "find \"$HOME/.local/share/Trash/info\" -mindepth 1 -maxdepth 1 -name '*.trashinfo' -exec rm -f -- {} +"]);
        trashRecheck.restart();
    }

    property Timer trashRecheck: Timer {
        interval: Theme.durSlow * 2
        onTriggered: apps.trashProbe.running = true
    }

    // ----------------------------------------------------- downloads stack
    // Newest few entries of ~/Downloads, refreshed when the stack is hovered.
    property var downloadFiles: []

    property Process downloadsProbe: Process {
        command: ["sh", "-c", "ls -t \"$HOME/Downloads\" 2>/dev/null | head -n 6"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                apps.downloadFiles = lines;
            }
        }
    }

    function refreshDownloads() {
        downloadsProbe.running = true;
    }

    Component.onCompleted: refreshDownloads()
}
