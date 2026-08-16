#!/usr/bin/env bash
#
# install-icons.sh — install an XDG icon theme and point Qt/GTK apps at it.
#
# Why this exists: Quickshell resolves themed icons via QIcon::fromTheme,
# which asks the Qt platform theme for the current icon theme. On a bare
# Wayland session (Hyprland/niri) no platform theme is configured, so
# QIcon::fromTheme finds NOTHING and the dock/launcher show fallback tiles.
#
# This script:
#   1. clones + installs the WhiteSur icon theme for the current user
#      (~/.local/share/icons) — skipped if already installed;
#   2. writes ~/.config/gtk-3.0/settings.ini and ~/.config/gtk-4.0/settings.ini
#      with gtk-icon-theme-name=<theme>;
#   3. prints the compositor env lines needed so Qt apps (incl. Quickshell)
#      use the GTK platform theme and pick the theme up.
#
# Usage:
#   ./scripts/install-icons.sh                 # install WhiteSur + configure
#   ./scripts/install-icons.sh --theme Papirus # (re)configure an installed theme
#   ./scripts/install-icons.sh --uninstall     # remove settings + WhiteSur
#
set -euo pipefail

readonly DEFAULT_THEME="WhiteSur-dark"
readonly WHITESUR_REPO="https://github.com/vinceliuice/WhiteSur-icon-theme"
readonly ICON_DIR="$HOME/.local/share/icons"

theme="$DEFAULT_THEME"
do_uninstall=0

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ${0##*/} [--theme <name>] [--uninstall] [--help]

  (no args)         Install the WhiteSur icon theme for the current user and
                    configure GTK/Qt to use '$DEFAULT_THEME'.
  --theme <name>    Skip installation; just point GTK/Qt at an already
                    installed icon theme (e.g. Papirus, WhiteSur-light).
  --uninstall       Remove the gtk-icon-theme-name settings and the WhiteSur
                    icon directories installed by this script.
EOF
}

# Write one GTK settings.ini, preserving any unrelated existing keys.
write_settings_ini() {
    local ini_dir="$1"
    local ini="$ini_dir/settings.ini"
    mkdir -p "$ini_dir"
    if [[ -f "$ini" ]] && grep -q '^\[Settings\]' "$ini"; then
        # Replace an existing gtk-icon-theme-name line in place, else append.
        if grep -q '^gtk-icon-theme-name=' "$ini"; then
            sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=$theme|" "$ini"
        else
            sed -i "/^\[Settings\]/a gtk-icon-theme-name=$theme" "$ini"
        fi
    else
        printf '[Settings]\ngtk-icon-theme-name=%s\n' "$theme" > "$ini"
    fi
    log "wrote $ini (gtk-icon-theme-name=$theme)"
}

# Remove the gtk-icon-theme-name key (used by --uninstall).
clear_settings_ini() {
    local ini="$1/settings.ini"
    [[ -f "$ini" ]] || return 0
    sed -i '/^gtk-icon-theme-name=/d' "$ini"
    log "cleared gtk-icon-theme-name in $ini"
}

print_env_instructions() {
    cat <<EOF

DONE. One more step — Qt apps (including Quickshell) only read the GTK icon
theme when the GTK platform theme is active. Add ONE of these and relog:

  Hyprland (~/.config/hypr/hyprland.conf):
      env = QT_QPA_PLATFORMTHEME,gtk3

  niri (~/.config/niri/config.kdl):
      environment { QT_QPA_PLATFORMTHEME "gtk3" }

Quickshell-only alternative (no GTK platform theme needed; verified against
the Quickshell v0.2 docs): set the theme just for the shell —

      env = QS_ICON_THEME,$theme

or add '//@ pragma IconTheme $theme' at the very top of shell.qml.
Note: Quickshell <= 0.2 has no runtime (QML) icon-theme API; both the pragma
and QS_ICON_THEME are read once at shell startup, so restart qs after changes.
EOF
}

install_whitesur() {
    if [[ -d "$ICON_DIR/WhiteSur-dark" || -d "$ICON_DIR/WhiteSur" ]]; then
        log "WhiteSur already installed in $ICON_DIR — skipping clone (idempotent)"
        return 0
    fi
    command -v git >/dev/null 2>&1 || die "git is required to fetch WhiteSur"
    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    log "cloning WhiteSur-icon-theme (shallow) into $tmp ..."
    git clone --depth=1 "$WHITESUR_REPO" "$tmp/WhiteSur-icon-theme"
    log "running its install.sh (user install -> $ICON_DIR) ..."
    # install.sh installs WhiteSur / WhiteSur-light / WhiteSur-dark by default.
    "$tmp/WhiteSur-icon-theme/install.sh"
    rm -rf "$tmp"
    trap - EXIT
}

uninstall() {
    log "removing gtk-icon-theme-name from GTK 3/4 settings"
    clear_settings_ini "$HOME/.config/gtk-3.0"
    clear_settings_ini "$HOME/.config/gtk-4.0"
    local d removed=0
    for d in "$ICON_DIR"/WhiteSur "$ICON_DIR"/WhiteSur-light "$ICON_DIR"/WhiteSur-dark; do
        if [[ -d "$d" ]]; then
            rm -rf "$d"
            log "removed $d"
            removed=1
        fi
    done
    [[ "$removed" -eq 0 ]] && log "no WhiteSur icon directories found in $ICON_DIR"
    log "uninstall complete (QT_QPA_PLATFORMTHEME/QS_ICON_THEME env lines, if any, were left untouched)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --theme)
            [[ $# -ge 2 && "$2" != -* ]] || die "--theme requires a theme name"
            theme="$2"
            shift 2
            ;;
        --uninstall)
            do_uninstall=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "unknown argument: $1"
            ;;
    esac
done

if [[ "$do_uninstall" -eq 1 ]]; then
    uninstall
    exit 0
fi

if [[ "$theme" == "$DEFAULT_THEME" ]]; then
    install_whitesur
else
    # Custom theme: configure only, but sanity-check that it exists somewhere.
    if [[ ! -d "$ICON_DIR/$theme" && ! -d "$HOME/.icons/$theme" && ! -d "/usr/share/icons/$theme" ]]; then
        warn "icon theme '$theme' not found in $ICON_DIR, ~/.icons or /usr/share/icons"
        warn "writing the settings anyway — install the theme if icons stay missing"
    fi
fi

write_settings_ini "$HOME/.config/gtk-3.0"
write_settings_ini "$HOME/.config/gtk-4.0"
print_env_instructions
