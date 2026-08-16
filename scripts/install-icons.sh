#!/usr/bin/env bash
#
# install-icons.sh — make sure the shell's icon theme is installed.
#
# The shell draws its dock/launcher icons AND (since common/SymbolIcons.qml)
# its UI symbols from an XDG icon theme. WhiteSur is the one it is tuned for:
#
#     https://github.com/vinceliuice/WhiteSur-icon-theme
#
# Quickshell resolves themed icons through QIcon::fromTheme, which asks the Qt
# platform theme for the current icon theme. A bare Wayland session (niri,
# Hyprland) configures no platform theme, so that lookup finds nothing — hence
# scripts/launch-with-icon-theme.sh, which exports QS_ICON_THEME before qs
# starts. It calls this script first, so a fresh machine installs the theme on
# its own the first time the session comes up.
#
# The theme is installed from a local checkout when there is one — see
# WHITESUR_SRC below — so the icons the session shows are the ones in the tree
# you actually edit, and a reinstall is a file copy rather than a clone.
#
# Everything here is idempotent and safe to run at every login: with the theme
# already in place it does no network access and finishes in milliseconds.
#
# Usage:
#   ./scripts/install-icons.sh              # install if missing, then configure GTK
#   ./scripts/install-icons.sh --check      # exit 0 if installed, 1 if not; prints nothing
#   ./scripts/install-icons.sh --force      # reinstall even if present
#   ./scripts/install-icons.sh --theme WhiteSur  # only point GTK/GNOME at a theme
#   ./scripts/install-icons.sh --source DIR # install from this checkout
#   ./scripts/install-icons.sh --uninstall
#
set -euo pipefail

readonly WHITESUR_REPO="https://github.com/vinceliuice/WhiteSur-icon-theme"
# A working copy of the theme, preferred over cloning. Keeping the session on
# the same tree the icons are edited in is the whole point: `--force` then
# republishes local changes instead of fetching over them.
WHITESUR_SRC="${WHITESUR_SRC:-$HOME/.github/WhiteSur-icon-theme}"
readonly ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
# What install.sh lays down with no arguments.
readonly WHITESUR_THEMES=(WhiteSur WhiteSur-light WhiteSur-dark)
# The theme GTK/Qt are pointed at, and the one the shell prefers.
readonly DEFAULT_THEME="WhiteSur-dark"
# Present in every complete install; its absence means a half-written theme.
readonly PROBE_ICON="status/symbolic/network-wireless-signal-good-symbolic.svg"

theme="$DEFAULT_THEME"
mode="ensure"     # ensure | check | force | configure | uninstall
quiet=0
write_gtk=1

log()  { [[ "$quiet" -eq 1 ]] || printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ${0##*/} [--check|--force|--configure|--uninstall]
       [--theme <name>] [--source <dir>] [--no-gtk] [--quiet]

  (no args)       Install WhiteSur if it is not already there, then point
                  GTK/GNOME at '$DEFAULT_THEME'. Does nothing expensive when
                  the theme is already installed.
  --check         Exit 0 if the theme is installed and complete, 1 otherwise.
                  Prints nothing; meant for scripts.
  --force         Reinstall even if the theme is present.
  --configure     Install nothing; only point GTK/GNOME at the theme.
  --theme <name>  Which theme name to point GTK/GNOME at (default
                  '$DEFAULT_THEME').
  --source <dir>  Install from this checkout instead of
                  '$WHITESUR_SRC'. Falls back to cloning when neither exists.
  --no-gtk        Skip writing the GTK settings.
  --quiet         Only warnings and errors.
  --uninstall     Remove the WhiteSur directories this script installed and
                  the gtk-icon-theme-name settings it wrote.
EOF
}

# Where an icon theme may live, most specific first.
theme_dir() {
    local name="$1" d
    for d in "$ICON_DIR/$name" "$HOME/.icons/$name" "/usr/share/icons/$name"; do
        [[ -f "$d/index.theme" ]] && { printf '%s\n' "$d"; return 0; }
    done
    return 1
}

# Installed AND complete: an interrupted install leaves index.theme behind
# without the icons, and that is worse than nothing (the shell would think the
# theme is there and fall back to drawn symbols for every single glyph).
theme_installed() {
    local dir
    dir="$(theme_dir "$1")" || return 1
    [[ -f "$dir/$PROBE_ICON" ]]
}

# Write one GTK settings.ini, preserving any unrelated keys already in it.
write_settings_ini() {
    local ini_dir="$1"
    local ini="$ini_dir/settings.ini"
    mkdir -p "$ini_dir"
    if [[ -f "$ini" ]] && grep -q '^\[Settings\]' "$ini"; then
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

clear_settings_ini() {
    local ini="$1/settings.ini"
    [[ -f "$ini" ]] || return 0
    sed -i '/^gtk-icon-theme-name=/d' "$ini"
    log "cleared gtk-icon-theme-name in $ini"
}

configure_gtk() {
    [[ "$write_gtk" -eq 1 ]] || return 0

    # Pointing anything at a theme that is not on disk is worse than leaving it
    # alone: GTK does not fall back to a nice theme, it falls back to hicolor,
    # and you get a desktop of generic paper-sheet icons. (This is exactly what
    # a stale `icon-theme 'Papirus'` did here with no Papirus installed.)
    if ! theme_dir "$theme" >/dev/null; then
        warn "icon theme '$theme' is not installed — leaving the GTK settings alone"
        return 0
    fi

    write_settings_ini "$HOME/.config/gtk-3.0"
    write_settings_ini "$HOME/.config/gtk-4.0"

    # settings.ini is only read by GTK apps that have no settings portal. When
    # xdg-desktop-portal-gtk/-gnome is running — and it is, in this session —
    # GTK asks the portal, and the portal answers from gsettings. So this line,
    # not the files above, is what Nautilus actually obeys, and it applies to
    # already-running apps without a restart.
    if command -v gsettings >/dev/null 2>&1; then
        if gsettings set org.gnome.desktop.interface icon-theme "$theme" 2>/dev/null; then
            log "set org.gnome.desktop.interface icon-theme=$theme"
        else
            warn "could not set the GNOME icon-theme (no dconf/dbus session?)"
        fi
    fi
}

install_whitesur() {
    local src="" tmp=""

    if [[ -x "$WHITESUR_SRC/install.sh" ]]; then
        src="$WHITESUR_SRC"
        log "installing from the local checkout $src ..."
    else
        command -v git >/dev/null 2>&1 || die "git is required to fetch WhiteSur"
        tmp="$(mktemp -d)"
        trap 'rm -rf "$tmp"' EXIT
        log "no checkout at $WHITESUR_SRC — cloning WhiteSur-icon-theme (shallow) ..."
        if [[ "$quiet" -eq 1 ]]; then
            git clone --depth=1 "$WHITESUR_REPO" "$tmp/WhiteSur-icon-theme" >/dev/null 2>&1
        else
            git clone --depth=1 "$WHITESUR_REPO" "$tmp/WhiteSur-icon-theme"
        fi
        src="$tmp/WhiteSur-icon-theme"
    fi

    log "installing into $ICON_DIR ..."
    # install.sh with no arguments installs WhiteSur / -light / -dark for the
    # current user. It resolves its own sources relative to $0, so it has to be
    # run from its own directory.
    if [[ "$quiet" -eq 1 ]]; then
        (cd "$src" && ./install.sh >/dev/null)
    else
        (cd "$src" && ./install.sh)
    fi

    if [[ -n "$tmp" ]]; then
        rm -rf "$tmp"
        trap - EXIT
    fi

    # Qt reads the theme through the on-disk cache when there is one; a stale
    # cache from an older install would hide the new icons.
    if command -v gtk-update-icon-cache >/dev/null 2>&1; then
        local t dir
        for t in "${WHITESUR_THEMES[@]}"; do
            dir="$ICON_DIR/$t"
            [[ -d "$dir" ]] && gtk-update-icon-cache -f -q -t "$dir" 2>/dev/null || true
        done
        log "refreshed the icon caches"
    fi

    theme_installed "$DEFAULT_THEME" || die "install finished but $DEFAULT_THEME is still incomplete"
}

uninstall() {
    log "removing gtk-icon-theme-name from the GTK 3/4 settings"
    clear_settings_ini "$HOME/.config/gtk-3.0"
    clear_settings_ini "$HOME/.config/gtk-4.0"
    local d removed=0
    for d in "$ICON_DIR"/WhiteSur*; do
        [[ -d "$d" ]] || continue
        rm -rf "$d"
        log "removed $d"
        removed=1
    done
    [[ "$removed" -eq 0 ]] && log "no WhiteSur directories found in $ICON_DIR"
    log "done (any QT_QPA_PLATFORMTHEME/QS_ICON_THEME lines in your compositor config were left alone)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check)     mode="check"; quiet=1; write_gtk=0; shift ;;
        --force)     mode="force"; shift ;;
        --uninstall) mode="uninstall"; shift ;;
        --no-gtk)    write_gtk=0; shift ;;
        --quiet)     quiet=1; shift ;;
        --configure) mode="configure"; shift ;;
        --theme)
            [[ $# -ge 2 && "$2" != -* ]] || die "--theme requires a theme name"
            theme="$2"
            shift 2
            ;;
        --source)
            [[ $# -ge 2 && "$2" != -* ]] || die "--source requires a directory"
            WHITESUR_SRC="$2"
            shift 2
            ;;
        -h|--help)   usage; exit 0 ;;
        *)           usage >&2; die "unknown argument: $1" ;;
    esac
done

case "$mode" in
    check)
        theme_installed "$DEFAULT_THEME"
        exit $?
        ;;
    uninstall)
        uninstall
        exit 0
        ;;
    configure)
        configure_gtk
        exit 0
        ;;
    force)
        install_whitesur
        ;;
    ensure)
        if theme_installed "$DEFAULT_THEME"; then
            log "$DEFAULT_THEME is already installed — nothing to do"
        else
            install_whitesur
        fi
        ;;
esac

configure_gtk

[[ "$quiet" -eq 1 ]] || cat <<EOF

The shell picks the theme up through QS_ICON_THEME, which
scripts/launch-with-icon-theme.sh exports for you — that is the wrapper the
niri config starts. To make every other Qt app use it as well, add:

  niri (~/.config/niri/config.kdl):
      environment { QT_QPA_PLATFORMTHEME "gtk3"; }

  Hyprland (~/.config/hypr/hyprland.conf):
      env = QT_QPA_PLATFORMTHEME,gtk3

QS_ICON_THEME is read once at startup, so restart the shell after changing it.
EOF
