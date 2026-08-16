pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// Contract 3: compositor-agnostic window/workspace abstraction.
// Detects Hyprland or niri at startup and maps both into the same plain-JS
// object lists, so no UI code ever touches compositor-specific types.
//
// Internally there are three small strategy sections:
//   hyprland — the Quickshell.Hyprland singleton; lists rebuilt on rawEvent
//              (debounced) plus a 1s fallback poll.
//   niri     — no native Quickshell module exists (v0.2.x), so we stream
//              `niri msg --json event-stream` via Process + SplitParser. The
//              stream sends the FULL state up-front, then incremental events.
//   unknown  — empty lists; all functions are no-ops.
Singleton {
    id: root

    // ---------- public surface (Contract 3; compositor-agnostic) ----------

    readonly property string compositor: {
        const hypr = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE");
        if (hypr !== null && hypr !== "")
            return "hyprland";
        const niri = Quickshell.env("NIRI_SOCKET");
        if (niri !== null && niri !== "")
            return "niri";
        return "unknown";
    }

    // Writable backing properties; the public readonly properties below are
    // initialized with bindings to them (readonly properties keep updating
    // through their initialization binding, but cannot be reassigned).
    property var _workspaces: []
    property var _windows: []
    property string _focusedTitle: ""
    property string _focusedApp: ""

    // list of { id: string, index: int, active: bool, occupied: bool, output: string }
    readonly property var workspaces: _workspaces
    // list of { id: string, title: string, appId: string, workspaceId: string, focused: bool }
    readonly property var windows: _windows
    readonly property string focusedTitle: _focusedTitle
    readonly property string focusedApp: _focusedApp

    function activateWorkspace(id) {
        if (compositor === "hyprland") {
            Hyprland.dispatch("workspace " + id);
        } else if (compositor === "niri") {
            // The positional arg of `niri msg action focus-workspace` parses a
            // number as INDEX (or a string as Name) — never as Id. Our contract
            // exposes niri's stable u64 id, so resolve id -> idx first.
            const ws = _niriWorkspaces.find(w => String(w.id) === String(id));
            if (ws)
                _niriAction(["focus-workspace", String(ws.idx)]);
            else
                console.warn("macos-shell: activateWorkspace: unknown niri workspace id", id);
        }
    }

    function focusWindow(id) {
        if (compositor === "hyprland")
            Hyprland.dispatch("focuswindow address:" + id);
        else if (compositor === "niri")
            _niriAction(["focus-window", "--id", String(id)]);
    }

    function closeWindow(id) {
        if (compositor === "hyprland")
            Hyprland.dispatch("closewindow address:" + id);
        else if (compositor === "niri")
            _niriAction(["close-window", "--id", String(id)]);
    }

    // ---------- wlr-foreign-toplevel (portable window handles) ----------
    // Quickshell's ToplevelManager works on every wlroots-style compositor and
    // gives us live handles that can be activated, closed and — crucially —
    // captured with ScreencopyView for Mission Control / window previews.
    // The compositor-specific lists above stay authoritative for WORKSPACES;
    // this is the portable window layer.
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property var activeToplevel: ToplevelManager.activeToplevel

    // Best-effort handle for one of our plain `windows` entries: matched on
    // app id first, then title, since neither compositor exposes the
    // foreign-toplevel handle in its IPC.
    function toplevelFor(win) {
        if (!win)
            return null;
        const list = ToplevelManager.toplevels.values;
        let appMatches = [];
        for (const tl of list) {
            if ((tl.appId || "").toLowerCase() === (win.appId || "").toLowerCase())
                appMatches.push(tl);
        }
        if (appMatches.length === 1)
            return appMatches[0];
        for (const tl of appMatches) {
            if ((tl.title || "") === (win.title || ""))
                return tl;
        }
        return appMatches.length > 0 ? appMatches[0] : null;
    }

    // niri's own workspace overview (used as a fallback / companion to the
    // shell's Mission Control).
    function toggleOverview() {
        if (compositor === "niri")
            _niriAction(["toggle-overview"]);
        else if (compositor === "hyprland")
            Hyprland.dispatch("hyprexpo:expo toggle");
    }

    function focusWorkspaceIndex(idx) {
        if (compositor === "niri")
            _niriAction(["focus-workspace", String(idx)]);
        else if (compositor === "hyprland")
            Hyprland.dispatch("workspace " + idx);
    }

    function moveWindowToWorkspace(windowId, workspaceIdx) {
        if (compositor === "niri")
            _niriAction(["move-window-to-workspace", "--window-id", String(windowId), String(workspaceIdx)]);
        else if (compositor === "hyprland")
            Hyprland.dispatch("movetoworkspacesilent " + workspaceIdx + ",address:" + windowId);
    }

    // Raw passthrough: "hyprctl dispatch <cmd>" / "niri msg action <words...>".
    function dispatch(cmd) {
        if (compositor === "hyprland")
            Hyprland.dispatch(cmd);
        else if (compositor === "niri")
            _niriAction(String(cmd).split(" ").filter(s => s.length > 0));
    }

    // Bold app name in the menu bar, prettified from the focused app id.
    //
    // A shell surface that takes keyboard focus (a menu, Spotlight, Control
    // Center) makes the compositor report "no focused toplevel", which would
    // blank the bar to "Desktop" the moment a menu is opened — while the menu's
    // own actions still act on the window underneath. So while one of our
    // overlays owns the focus, the last real app name is held; it is re-read
    // once the overlay closes and the compositor has handed focus back.
    onFocusedAppChanged: _publishAppName()

    function _publishAppName() {
        if (focusedApp === "" && ShellState.anyOverlayOpen)
            return;
        ShellState.focusedAppName = _prettifyAppName(focusedApp);
    }

    Connections {
        target: ShellState
        function onAnyOverlayOpenChanged() {
            // Not immediately: ShellState asks the compositor to re-focus the
            // window the menu stole focus from, and that round trip is async.
            // Re-reading right away would flash "Desktop" for one frame.
            if (!ShellState.anyOverlayOpen)
                appNameSettle.restart();
        }
    }

    Timer {
        id: appNameSettle
        interval: 300
        onTriggered: root._publishAppName()
    }

    function _prettifyAppName(appId) {
        if (appId === null || appId === undefined || appId === "")
            return "Desktop";
        let s = String(appId);
        if (s.endsWith(".desktop"))
            s = s.slice(0, s.length - 8);
        if (s.indexOf(".") >= 0)
            s = s.split(".").pop(); // reverse-DNS id ("org.kde.dolphin") -> last segment
        s = s.replace(/[-_]+/g, " ").trim();
        if (s === "")
            return "Desktop";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    Component.onCompleted: {
        ShellState.focusedAppName = _prettifyAppName(focusedApp);
        if (compositor === "hyprland")
            _rebuildHyprland();
        // niri: the stream Process starts via its `running` binding and sends a
        // full state dump up-front, so no one-shot startup queries are needed.
        // unknown: intentionally nothing — lists stay empty, functions no-op.
    }

    // ================= hyprland strategy =================

    // Robust approach: snapshot Hyprland.workspaces/toplevels (.values) into
    // brand-new plain arrays so property bindings re-evaluate. Called from a
    // debounced rawEvent handler, a 1s fallback poll, and once at startup.
    function _rebuildHyprland() {
        if (compositor !== "hyprland")
            return;

        const wins = [];
        for (const tl of Hyprland.toplevels.values) {
            wins.push({
                id: tl.address, // hex address string is our uniform window id
                title: tl.title ?? "",
                appId: _hyprAppId(tl),
                workspaceId: tl.workspace ? String(tl.workspace.id) : "",
                focused: tl.activated
            });
        }

        const occupied = {};
        for (const w of wins)
            if (w.workspaceId !== "")
                occupied[w.workspaceId] = true;

        const wss = [];
        for (const ws of Hyprland.workspaces.values) {
            wss.push({
                id: String(ws.id),
                index: ws.id, // hyprland workspace id doubles as the index
                active: ws.active,
                occupied: occupied[String(ws.id)] === true || ws.toplevels.values.length > 0,
                output: (ws.monitor && ws.monitor.name) ? ws.monitor.name : ""
            });
        }
        wss.sort((a, b) => a.index - b.index);

        _windows = wins;
        _workspaces = wss;

        const active = Hyprland.activeToplevel;
        _focusedTitle = active ? (active.title ?? "") : "";
        _focusedApp = active ? _hyprAppId(active) : "";
    }

    // lastIpcObject is the raw hyprctl JSON; the class is set at window
    // creation and never changes, so its documented staleness is harmless.
    function _hyprAppId(tl) {
        const ipc = tl.lastIpcObject;
        return (ipc && ipc["class"]) ? String(ipc["class"]) : "";
    }

    Connections {
        target: Hyprland
        enabled: root.compositor === "hyprland"
        // rawEvent fires for every socket2 event; debounce to one rebuild.
        function onRawEvent(event) {
            hyprDebounce.restart();
        }
    }

    Timer {
        id: hyprDebounce
        interval: 40
        onTriggered: root._rebuildHyprland()
    }

    // Fallback poll in case anything is missed.
    Timer {
        interval: 1000
        running: root.compositor === "hyprland"
        repeat: true
        onTriggered: root._rebuildHyprland()
    }

    // ================= niri strategy =================

    // Raw niri state (int ids); mapped into the contract lists by _syncNiri().
    property var _niriWorkspaces: []
    property var _niriWindows: []

    function _niriAction(args) {
        // fire-and-forget one-shot; never blocks the UI
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    Process {
        id: niriStream
        command: ["niri", "msg", "--json", "event-stream"]
        running: root.compositor === "niri"

        stdout: SplitParser {
            // splitMarker defaults to "\n": onRead fires once per JSON line.
            onRead: data => root._handleNiriLine(data)
        }

        // If the stream dies (niri restarted etc.) retry after 2s.
        onExited: {
            if (root.compositor === "niri")
                niriRestart.start();
        }
    }

    Timer {
        id: niriRestart
        interval: 2000
        onTriggered: niriStream.running = true
    }

    function _handleNiriLine(line) {
        if (!line || line.length === 0)
            return;
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            console.warn("macos-shell: unparsable niri event line:", line);
            return;
        }
        _handleNiriEvent(ev);
    }

    // Each event line is an externally-tagged enum: exactly one top-level key.
    // Unknown variants (newer niri versions add some) are ignored on purpose.
    function _handleNiriEvent(ev) {
        const kind = Object.keys(ev)[0];
        const d = ev[kind];
        switch (kind) {
        case "WorkspacesChanged": // full replacement
            _niriWorkspaces = (d && d.workspaces) ? d.workspaces : [];
            _syncNiri();
            break;
        case "WorkspaceActivated": { // active on its output; focused => global
            const target = _niriWorkspaces.find(w => w.id === d.id);
            _niriWorkspaces = _niriWorkspaces.map(w => Object.assign({}, w, {
                is_active: (target && w.output === target.output) ? (w.id === d.id) : w.is_active,
                is_focused: d.focused ? (w.id === d.id) : w.is_focused
            }));
            _syncNiri();
            break;
        }
        case "WorkspaceActiveWindowChanged": // active_window_id may be null
            _niriWorkspaces = _niriWorkspaces.map(w => w.id === d.workspace_id ? Object.assign({}, w, {
                active_window_id: d.active_window_id ?? null
            }) : w);
            break; // not part of the contract mapping; no re-sync needed
        case "WindowsChanged": // full replacement
            _niriWindows = (d && d.windows) ? d.windows : [];
            _syncNiri();
            break;
        case "WindowOpenedOrChanged": { // upsert
            const w = d ? d.window : null;
            if (!w || w.id === undefined || w.id === null)
                break;
            _niriWindows = _niriWindows.some(x => x.id === w.id) ? _niriWindows.map(x => x.id === w.id ? w : x) : _niriWindows.concat([w]);
            _syncNiri();
            break;
        }
        case "WindowClosed":
            _niriWindows = _niriWindows.filter(x => x.id !== d.id);
            _syncNiri();
            break;
        case "WindowFocusChanged": { // id may be null (nothing focused)
            const fid = (d && d.id !== undefined && d.id !== null) ? d.id : null;
            _niriWindows = _niriWindows.map(w => Object.assign({}, w, {
                is_focused: w.id === fid
            }));
            _syncNiri();
            break;
        }
        default:
            break; // tolerate variants added by newer niri (CastsChanged, ...)
        }
    }

    // Map raw niri state into the compositor-agnostic contract lists.
    function _syncNiri() {
        if (compositor !== "niri")
            return;

        const wins = _niriWindows.map(w => ({
            id: String(w.id),
            title: w.title ?? "",
            appId: w.app_id ?? "",
            workspaceId: (w.workspace_id === null || w.workspace_id === undefined) ? "" : String(w.workspace_id),
            focused: w.is_focused === true
        }));

        const occupied = {}; // derived from the windows list
        for (const w of wins)
            if (w.workspaceId !== "")
                occupied[w.workspaceId] = true;

        const wss = _niriWorkspaces.map(ws => ({
            id: String(ws.id),
            index: ws.idx ?? 0,
            active: ws.is_active === true,
            occupied: occupied[String(ws.id)] === true,
            output: ws.output ?? ""
        }));
        // idx is per-output; sort by (output, index) for stable multi-monitor order.
        wss.sort((a, b) => a.output === b.output ? a.index - b.index : (a.output < b.output ? -1 : 1));

        _windows = wins;
        _workspaces = wss;

        const f = wins.find(w => w.focused);
        _focusedTitle = f ? f.title : "";
        _focusedApp = f ? f.appId : "";
    }
}
