pragma Singleton

import QtQuick
import Quickshell

// Maps the shell's SF-Symbols-style glyph names onto real XDG icon names, so
// Glyph can draw an installed icon theme instead of its own Canvas paths.
//
// WhiteSur (https://github.com/vinceliuice/WhiteSur-icon-theme) is the theme
// this is tuned for — scripts/install-icons.sh installs it and the launcher
// exports QS_ICON_THEME before starting the shell — but nothing here is
// WhiteSur-specific: every name below is a standard freedesktop icon name, so
// Papirus, Adwaita or Breeze all resolve too.
//
// Only "-symbolic" names are used. Symbolic icons are single-colour with a
// meaningful alpha channel, which is what lets Glyph tint them to the current
// label colour; a full-colour icon masked to one colour would come out as a
// silhouette. A name that the theme does not have resolves to "" and Glyph
// falls back to its drawn version, so the shell still works with no icon theme
// installed at all.
//
// Deliberately NOT mapped, because the drawn version is better:
//   * the shell's own marks — apple, controlcenter, rectangle.3.group, stage;
//   * geometry too simple to be worth a file — chevron.*, circle, circle.fill,
//     ellipsis, plus, minus, xmark;
//   * names where WhiteSur's nearest icon means something else. globe and
//     network are a detailed earth that turns to mush at 18px; star.fill and
//     the media transport marks would come out hollow; xmark.circle.fill is a
//     backspace key, sidebar an arrow, bolt a struck-through bolt.
// Adding a mapping is just another line in `table` — no other file changes.
Singleton {
    id: root

    // Off when the user asked for the drawn symbols, or when no icon theme
    // with symbolic icons is reachable from this process.
    readonly property bool enabled: Settings.symbolStyle !== "drawn" && available

    // One probe is enough: every theme that ships symbolic icons has this one.
    readonly property bool available: _lookup("network-wireless-signal-good-symbolic") !== ""

    // Resolved icon URLs, keyed by icon name. Icon lookup hits the filesystem,
    // and Glyph asks on every name/level change, so the answers are kept.
    property var _cache: ({})

    function _lookup(name) {
        if (_cache[name] === undefined)
            _cache[name] = Quickshell.iconPath(name, true);
        return _cache[name];
    }

    // First candidate the theme actually has.
    function _first(names) {
        for (const n of names) {
            const p = _lookup(n);
            if (p !== "")
                return p;
        }
        return "";
    }

    // ------------------------------------------------------- static names
    // glyph name -> candidate icon names, best first.
    readonly property var table: ({
            // ---- connectivity
            "wifi.slash": ["network-wireless-disabled-symbolic", "network-wireless-offline-symbolic"],
            "bluetooth": ["bluetooth-active-symbolic", "bluetooth-symbolic"],
            "ethernet": ["network-wired-symbolic"],

            // ---- power
            "power": ["system-shutdown-symbolic"],
            "restart": ["system-restart-symbolic", "view-refresh-symbolic"],
            "moon": ["weather-clear-night-symbolic", "night-light-symbolic"],
            "moon.zzz": ["weather-clear-night-symbolic", "night-light-symbolic"],
            "lock": ["changes-prevent-symbolic", "lock-symbolic", "system-lock-screen-symbolic"],
            "lock.open": ["changes-allow-symbolic", "padlock-open-symbolic"],

            // ---- audio
            "speaker.slash": ["audio-volume-muted-symbolic"],
            "headphones": ["headphones-symbolic", "audio-headphones-symbolic"],
            "mic": ["microphone-symbolic", "audio-input-microphone-high-symbolic"],
            "music.note": ["music-note-symbolic", "audio-x-generic-symbolic"],

            // ---- display
            "sun.max": ["display-brightness-high-symbolic", "brightness-display-symbolic"],
            "sun.min": ["display-brightness-low-symbolic", "brightness-display-symbolic"],
            "display": ["video-display-symbolic", "preferences-desktop-display-symbolic"],
            "airplay": ["screen-shared-symbolic", "tv-symbolic"],
            // WhiteSur draws this one as the Command key, which is exactly
            // right where the shell uses it (the Shortcuts pane).
            "keyboard": ["input-keyboard-symbolic"],

            // ---- ui / actions
            "magnifyingglass": ["system-search-symbolic", "edit-find-symbolic"],
            "square.grid.3x3": ["view-app-grid-symbolic", "view-grid-symbolic"],
            "bell": ["notifications-symbolic", "bell-outline-symbolic"],
            "bell.slash": ["notifications-disabled-symbolic"],
            "gear": ["preferences-system-symbolic", "settings-symbolic", "emblem-system-symbolic"],
            "checkmark": ["checkmark-symbolic", "object-select-symbolic"],
            "info.circle": ["info-symbolic", "dialog-information-symbolic", "help-about-symbolic"],
            "exclamationmark.triangle": ["dialog-warning-symbolic"],
            "arrow.up.left.and.arrow.down.right": ["view-fullscreen-symbolic"],
            "arrow.right": ["go-next-symbolic"],
            "arrow.down": ["go-down-symbolic"],
            "return": ["keyboard-enter-symbolic"],

            // ---- objects
            "folder": ["folder-symbolic"],
            "trash": ["user-trash-symbolic"],
            "clock": ["alarm-symbolic", "stopwatch-symbolic"],
            "calendar": ["calendar-symbolic", "office-calendar-symbolic"],
            "person.crop.circle": ["avatar-default-symbolic", "system-users-symbolic"],
            "eye": ["view-reveal-symbolic"],
            "camera": ["camera-photo-symbolic", "photo-camera-symbolic"],
            "hand.raised": ["hand-open-symbolic"],
            "terminal": ["utilities-terminal-symbolic"]
        })

    // Wi-Fi signal, 0..3 arcs.
    readonly property var wifiLevels: ["network-wireless-signal-none-symbolic", "network-wireless-signal-weak-symbolic", "network-wireless-signal-ok-symbolic", "network-wireless-signal-excellent-symbolic"]

    // Speaker, 0..3 waves. Level 0 stays a plain speaker rather than the
    // muted icon — "muted" is a separate glyph (speaker.slash) and the slider
    // reaches level 0 simply by being turned all the way down.
    readonly property var speakerLevels: ["audio-volume-low-symbolic", "audio-volume-low-symbolic", "audio-volume-medium-symbolic", "audio-volume-high-symbolic"]

    function _clampLevel(level, count) {
        return Math.max(0, Math.min(count - 1, level));
    }

    // Battery icon names go in tens; -charging and -charged are separate sets.
    function _battery(value, charging) {
        const pct = Math.max(0, Math.min(100, Math.round(Math.max(0, Math.min(1, value)) * 10) * 10));
        if (charging && pct >= 100)
            return ["battery-level-100-charged-symbolic", "battery-full-charged-symbolic", "battery-level-100-charging-symbolic"];
        if (charging)
            return ["battery-level-" + pct + "-charging-symbolic", "battery-good-charging-symbolic"];
        return ["battery-level-" + pct + "-symbolic", "battery-good-symbolic"];
    }

    // --------------------------------------------------------------- api
    // The icon URL for a glyph in a given state, or "" to draw it instead.
    function resolve(name, level, value, charging) {
        if (!enabled || name === "")
            return "";

        switch (name) {
        case "wifi":
            return _first([wifiLevels[_clampLevel(level, 4)]]);
        case "speaker":
            return _first([speakerLevels[_clampLevel(level, 4)]]);
        case "battery":
            return _first(_battery(value, charging));
        }

        const cands = table[name];
        return cands === undefined ? "" : _first(cands);
    }
}
