pragma Singleton

import QtQuick
import Quickshell

// The shell's view of the installed applications, and of what the user pinned
// to the dock.
//
// This used to live inside modules/dock/DockApps.qml, but System Settings needs
// exactly the same answers ("what is pinned?", "what does this key look like?")
// to let the user edit the dock, and two copies of that logic would drift. The
// dock keeps everything that is about *running* windows; this singleton owns
// the static side: the desktop-entry index, the default dock set, and the
// pinned list stored in Settings.
Singleton {
    id: root

    // ------------------------------------------------------------- helpers

    // Case/punctuation-insensitive key used everywhere app ids are compared
    // ("org.gnome.Nautilus", "org.gnome.nautilus" and "Nautilus" all collapse).
    function normalize(s) {
        return String(s === undefined || s === null ? "" : s).toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function prettify(id) {
        let s = String(id ?? "");
        if (s.endsWith(".desktop"))
            s = s.slice(0, s.length - 8);
        if (s.indexOf(".") >= 0)
            s = s.split(".").pop(); // reverse-DNS id -> last segment
        s = s.replace(/[-_]+/g, " ").trim();
        if (s === "")
            return "App";
        return s.split(" ").map(w => w.length > 0 ? w.charAt(0).toUpperCase() + w.slice(1) : w).join(" ");
    }

    // Desktop entries indexed under every key an app-id might arrive as: the
    // entry id, its last reverse-DNS segment, StartupWMClass and the visible
    // name — all normalized. First writer wins, so exact ids beat fuzzy names.
    readonly property var entryIndex: {
        const idx = {};
        const all = DesktopEntries.applications.values;
        function put(key, e) {
            const n = root.normalize(key);
            if (n.length > 0 && idx[n] === undefined)
                idx[n] = e;
        }
        for (const e of all)
            put(e.id, e);
        for (const e of all) {
            const id = String(e.id ?? "");
            if (id.indexOf(".") >= 0)
                put(id.split(".").pop(), e);
        }
        for (const e of all)
            put(e.startupClass, e);
        for (const e of all)
            put(e.name, e);
        return idx;
    }

    // Never uses DesktopEntries.byId(): that logs a warning for every miss and
    // our candidate lists miss on purpose.
    function entryFor(key) {
        const e = entryIndex[normalize(key)];
        return e === undefined ? null : e;
    }

    // Every installed, non-hidden application, sorted by name — the model
    // behind System Settings' "add an app to the Dock" picker.
    readonly property var allEntries: {
        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay === true)
                continue;
            out.push(e);
        }
        out.sort((a, b) => String(a.name ?? "").localeCompare(String(b.name ?? "")));
        return out;
    }

    // First icon-theme name that actually resolves; "" when none does, which is
    // what makes DockIcon fall back to a drawn tile.
    function resolveIcon(candidates) {
        for (const c of candidates) {
            if (c === undefined || c === null || String(c).length === 0)
                continue;
            const name = String(c);
            if (name.charAt(0) === "/")
                return "file://" + name; // desktop entries may carry a path
            const p = Quickshell.iconPath(name, true);
            if (p.length > 0)
                return p;
        }
        return "";
    }

    // ------------------------------------------------------ default dock set
    // Each role lists candidate desktop-entry ids across distros; the first one
    // installed wins. A role that resolves to nothing is silently dropped, so a
    // machine without (say) a browser still gets a working dock.
    readonly property var defaultRoles: [
        {
            "role": "launchpad",
            "ids": ["@launchpad"] // drawn by us, not an installed app
        },
        {
            "role": "finder",
            "ids": ["org.gnome.Nautilus", "nautilus", "org.kde.dolphin", "dolphin", "thunar", "Thunar", "nemo", "pcmanfm", "pcmanfm-qt", "io.elementary.files", "caja", "org.gnome.Files"]
        },
        {
            "role": "browser",
            "ids": ["firefox", "firefox-developer-edition", "org.mozilla.firefox", "zen-browser", "librewolf", "chromium", "google-chrome", "brave-browser", "org.gnome.Epiphany", "vivaldi-stable"]
        },
        {
            "role": "terminal",
            "ids": ["kitty", "Alacritty", "alacritty", "foot", "org.gnome.Console", "org.gnome.Terminal", "konsole", "org.wezfurlong.wezterm", "wezterm", "xterm"]
        },
        {
            "role": "editor",
            "ids": ["code", "code-oss", "codium", "vscodium", "visual-studio-code", "dev.zed.Zed", "sublime_text", "org.gnome.TextEditor", "gedit", "nvim", "vim"]
        },
        {
            "role": "settings",
            "ids": ["@settings"] // the shell's own System Settings window
        }
    ]

    readonly property var defaultPinned: {
        const out = [];
        for (const r of defaultRoles) {
            if (String(r.ids[0]).charAt(0) === "@") {
                out.push(r.ids[0]);
                continue;
            }
            for (const id of r.ids) {
                const e = entryFor(id);
                if (e !== null) {
                    out.push(e.id);
                    break;
                }
            }
        }
        return out;
    }

    // ---------------------------------------------------------- pinned list
    // Settings.dockPinned is a list<string>; empty means "use the defaults".
    // Launchpad is always hoisted to the front: it is the dock's leftmost
    // (topmost, for a side dock) icon in macOS and stays there whatever order
    // the stored list happens to have.
    readonly property var pinnedKeys: {
        const s = Settings.dockPinned;
        const stored = [];
        for (let i = 0; i < s.length; i++)
            stored.push(String(s[i]));
        const list = stored.length > 0 ? stored : defaultPinned;

        const out = ["@launchpad"];
        for (const k of list)
            if (k !== "@launchpad")
                out.push(k);
        return out;
    }

    // Writing the full list materializes the defaults on first change, so an
    // edit persists instead of silently reverting to the defaults.
    function setPinnedKeys(keys) {
        const out = ["@launchpad"];
        for (const k of keys)
            if (String(k) !== "@launchpad")
                out.push(String(k));
        Settings.dockPinned = out;
    }

    function isPinned(key) {
        return pinnedKeys.indexOf(key) >= 0;
    }

    function setPinned(key, on) {
        const cur = pinnedKeys.slice();
        const i = cur.indexOf(key);
        if (on && i < 0)
            cur.push(key);
        else if (!on && i >= 0)
            cur.splice(i, 1);
        else
            return;
        setPinnedKeys(cur);
    }

    // Move the pinned entry at `from` to index `to` (both are indices into
    // pinnedKeys). Launchpad's slot 0 is fixed, so both ends are clamped.
    function movePinned(from, to) {
        const cur = pinnedKeys.slice();
        if (from <= 0 || from >= cur.length)
            return;
        const t = Math.max(1, Math.min(cur.length - 1, to));
        if (t === from)
            return;
        const item = cur.splice(from, 1)[0];
        cur.splice(t, 0, item);
        setPinnedKeys(cur);
    }

    function resetPinned() {
        Settings.dockPinned = [];
    }

    // ---------------------------------------------------------- dock items
    // Every entry the dock lays out is one of these plain objects:
    //   kind:    "app" | "sep"
    //   special: "" | "launchpad" | "settings" | "trash" | "downloads"
    //   key:     stable identity (desktop id, "@launchpad", ...) used by
    //            Settings.dockPinned and by the bounce animation
    //   matchIds: normalized ids a foreign-toplevel appId may equal
    function makeItem(key, pinned) {
        if (key === "@launchpad")
            return {
                "kind": "app",
                "special": "launchpad",
                "key": key,
                "name": "Launchpad",
                "glyph": "square.grid.3x3",
                "iconPath": "",
                "matchIds": [],
                "pinned": pinned
            };

        if (key === "@settings")
            return {
                "kind": "app",
                "special": "settings",
                "key": key,
                "name": "System Settings",
                "glyph": "gear",
                // The icon theme's own settings icon when it has one (WhiteSur
                // ships the macOS gear); the drawn tile otherwise.
                "iconPath": resolveIcon(["preferences-system", "org.gnome.Settings", "systemsettings", "preferences-desktop"]),
                // The settings window is one of our own toplevels, so claim it:
                // the dock then shows a running dot on this icon instead of
                // listing "Quickshell" a second time.
                "matchIds": ["orgquickshell", "quickshell"],
                "pinned": pinned
            };

        const e = entryFor(key);
        const ids = [key];
        let icons = [];
        if (e !== null) {
            ids.push(e.id, e.startupClass, e.name);
            const sid = String(e.id ?? "");
            if (sid.indexOf(".") >= 0)
                ids.push(sid.split(".").pop());
            icons = [e.icon, e.id, sid.indexOf(".") >= 0 ? sid.split(".").pop() : ""];
        } else {
            icons = [key];
        }

        const match = [];
        for (const i of ids) {
            const n = normalize(i);
            if (n.length > 0 && match.indexOf(n) < 0)
                match.push(n);
        }

        return {
            "kind": "app",
            "special": "",
            "key": key,
            "name": e !== null && String(e.name ?? "").length > 0 ? e.name : prettify(key),
            "glyph": "",
            "iconPath": resolveIcon(icons),
            "matchIds": match,
            "pinned": pinned
        };
    }

    // ------------------------------------------------------------- launching
    // DesktopEntry.execute() when Quickshell provides it, otherwise the Exec
    // string with desktop-entry field codes stripped.
    function launchEntry(e) {
        if (e === null || e === undefined)
            return false;
        if (typeof e.execute === "function") {
            e.execute();
            return true;
        }
        const cmd = String(e.execString ?? "").replace(/%[fFuUdDnNickvm]/g, " ").replace(/%%/g, "%").replace(/\s+/g, " ").trim();
        if (cmd.length === 0)
            return false;
        Quickshell.execDetached(["sh", "-c", cmd]);
        return true;
    }

    function launchKey(key) {
        return launchEntry(entryFor(key));
    }
}
