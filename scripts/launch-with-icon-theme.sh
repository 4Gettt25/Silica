#!/usr/bin/env bash
# Launches `qs -c macos-shell` with QS_ICON_THEME set to the WhiteSur variant
# matching the saved appearance. Quickshell has no runtime icon-theme API, so
# the theme is picked once at process start; switching appearance at runtime
# changes every color instantly but keeps the icon variant until the next
# start (macOS app icons do not change with appearance either).
#
# Usage: launch-with-icon-theme.sh [light|dark]
# With no argument, the appearance is read from state.json (niri startup).
set -euo pipefail

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
    export QS_ICON_THEME=WhiteSur
else
    export QS_ICON_THEME=WhiteSur-dark
fi

exec qs -c macos-shell
