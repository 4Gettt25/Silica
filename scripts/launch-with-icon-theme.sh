#!/usr/bin/env bash
# Starts `qs -c macos-shell` with QS_ICON_THEME pointed at the WhiteSur variant
# that matches the saved appearance, installing the theme first if this machine
# does not have it yet.
#
# Both halves exist because Quickshell has no runtime icon-theme API: the theme
# is resolved once at process start, and it is the source of both the dock's
# app icons and (via common/SymbolIcons.qml) the shell's own UI symbols. So the
# theme has to be on disk and named in the environment before qs is exec'd.
# Switching appearance later still recolours everything instantly; only the
# icon *variant* waits for the next start, exactly as macOS app icons do not
# change with appearance either.
#
# Usage: launch-with-icon-theme.sh [light|dark]
# With no argument the appearance is read from state.json (this is how niri
# starts it).
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE="$HOME/.config/macos-shell/state.json"

mode="${1:-}"
if [[ -z "$mode" ]]; then
    mode=dark
    if [[ -f "$STATE_FILE" ]]; then
        parsed=$(sed -n 's/.*"appearance"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$STATE_FILE")
        [[ -n "$parsed" ]] && mode="$parsed"
    fi
fi

if [[ "$mode" == "light" ]]; then
    theme=WhiteSur
else
    theme=WhiteSur-dark
fi

# First run on a new machine: fetch the theme before starting, because the
# shell can only read it at startup. Capped, and never fatal — a session that
# comes up with drawn symbols is fine, one that never comes up is not.
if ! "$SCRIPT_DIR/install-icons.sh" --check; then
    echo "macos-shell: icon theme missing, installing WhiteSur (first run only)..." >&2
    timeout 300 "$SCRIPT_DIR/install-icons.sh" --quiet ||
        echo "macos-shell: icon theme install failed; falling back to the drawn symbols" >&2
fi

# Only claim a theme that is really there. QS_ICON_THEME naming a missing theme
# would lose the icons the system theme could still have provided.
if "$SCRIPT_DIR/install-icons.sh" --check; then
    export QS_ICON_THEME="$theme"

    # And point the rest of the session at the same theme, every login — not
    # only on the login that installed it. The shell is not the only thing on
    # screen: Nautilus and every other GTK app read the GNOME icon-theme key,
    # and if that key names a theme this machine does not have (it said
    # 'Papirus' here, with no Papirus installed) they fall all the way back to
    # hicolor and show generic icons next to the shell's WhiteSur ones.
    "$SCRIPT_DIR/install-icons.sh" --configure --theme "$theme" --quiet || true
fi

exec qs -c macos-shell
