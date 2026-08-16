#!/usr/bin/env bash
#
# fix-cursors.sh — diagnose the "two overlapping mouse cursors" issue and
# print the exact compositor config lines that fix it.
#
# Why two cursors: the compositor draws its SOFTWARE cursor on top of a
# HARDWARE (KMS/DRM) cursor plane. Common in VMs (virtio-gpu/vmware) and when
# the configured hyprcursor/XCursor theme is missing so the fallback is drawn
# twice. macos-shell cannot fix this — it is compositor-side — so this script
# only DETECTS and PRINTS. With --apply it appends the Hyprland lines to
# hyprland.conf, and only after an interactive confirmation.
#
# Usage:
#   ./scripts/fix-cursors.sh            # detect + print recommended config
#   ./scripts/fix-cursors.sh --apply    # also append to hyprland.conf (asks first)
#
set -euo pipefail

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

do_apply=0
[[ "${1:-}" == "--apply" ]] && do_apply=1
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# --- detect compositor via the session's environment ----------------------
compositor="unknown"
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    compositor="hyprland"
elif [[ -n "${NIRI_SOCKET:-}" ]]; then
    compositor="niri"
fi
# Fallback when run outside the session (e.g. from a TTY): look at processes.
if [[ "$compositor" == "unknown" ]]; then
    if pgrep -x Hyprland >/dev/null 2>&1; then
        compositor="hyprland"
        warn "env vars not visible from here; detected Hyprland via process list"
    elif pgrep -x niri >/dev/null 2>&1; then
        compositor="niri"
        warn "env vars not visible from here; detected niri via process list"
    fi
fi
log "detected compositor: $compositor"

# --- guess a usable installed cursor theme --------------------------------
cursor_theme=""
for dir in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do
    [[ -d "$dir" ]] || continue
    for candidate in Bibata-Modern-Classic Bibata-Modern-Ice Adwaita breeze_cursors Vanilla-DMZ; do
        if [[ -d "$dir/$candidate/cursors" || -f "$dir/$candidate/cursor.theme" || -f "$dir/$candidate/index.theme" ]]; then
            cursor_theme="$candidate"
            break 2
        fi
    done
done
if [[ -n "$cursor_theme" ]]; then
    log "found installed cursor theme: $cursor_theme"
else
    warn "no known cursor theme found (checked Bibata/Adwaita/breeze/Vanilla-DMZ)"
    warn "install one, e.g.: sudo pacman -S bibata-cursor-theme  |  sudo apt install bibata-cursor-theme"
    cursor_theme="Bibata-Modern-Classic"   # print a sensible suggestion anyway
fi

case "$compositor" in
    hyprland)
        cat <<EOF

Add these lines to ~/.config/hypr/hyprland.conf, then reload (Super+Ctrl+R or
'hyprctl reload'):

    # 1) Stop drawing the hardware cursor plane (kills the double cursor).
    #    On Hyprland <= 0.41 this was an env var instead:
    #    env = WLR_NO_HARDWARE_CURSORS,1
    cursor {
        no_hardware_cursors = true
    }

    # 2) Make sure a real cursor theme is configured (a missing theme also
    #    shows a fallback box / double cursor):
    env = XCURSOR_THEME,$cursor_theme
    env = XCURSOR_SIZE,24
    # Hyprland's own hyprcursor (optional, if installed):
    # env = HYPRCURSOR_THEME,$cursor_theme
    # env = HYPRCURSOR_SIZE,24
EOF
        ;;
    niri)
        cat <<EOF

Add this block to ~/.config/niri/config.kdl, then restart niri:

    cursor {
        xcursor-theme "$cursor_theme"
        xcursor-size 24
    }

Note: niri has no no_hardware_cursors toggle; on virtio-gpu/VMs the duplicate
cursor comes from the kernel driver and disappears once a proper xcursor
theme is set (niri then hides the hardware plane). If it persists, run niri
with the WLR_NO_HARDWARE_CURSORS=1 environment variable set.
EOF
        ;;
    *)
        cat <<EOF

Could not detect Hyprland or niri (looked for \$HYPRLAND_INSTANCE_SIGNATURE,
\$NIRI_SOCKET, and running processes). Re-run this script from a terminal
INSIDE your Wayland session. Manual fixes:

    Hyprland:  cursor { no_hardware_cursors = true }   # or env = WLR_NO_HARDWARE_CURSORS,1
               env = XCURSOR_THEME,$cursor_theme
               env = XCURSOR_SIZE,24
    niri:      cursor { xcursor-theme "$cursor_theme"  xcursor-size 24 } in config.kdl
EOF
        ;;
esac

# --- optional apply (hyprland only, always confirmed) ---------------------
if [[ "$do_apply" -eq 1 ]]; then
    [[ "$compositor" == "hyprland" ]] || die "--apply only supports hyprland.conf; apply the printed niri lines by hand"
    conf="${HYPRLAND_CONF:-$HOME/.config/hypr/hyprland.conf}"
    [[ -f "$conf" ]] || die "hyprland.conf not found at $conf"
    echo
    echo "About to append to $conf:"
    printf '    cursor { no_hardware_cursors = true }\n    env = XCURSOR_THEME,%s\n    env = XCURSOR_SIZE,24\n' "$cursor_theme"
    read -r -p "Proceed? [y/N] " reply
    case "$reply" in
        y|Y|yes|YES)
            {
                printf '\n# macos-shell fix-cursors.sh: fix double cursor + set cursor theme\n'
                printf 'cursor {\n    no_hardware_cursors = true\n}\n'
                printf 'env = XCURSOR_THEME,%s\n' "$cursor_theme"
                printf 'env = XCURSOR_SIZE,24\n'
            } >> "$conf"
            log "appended cursor fix to $conf — run 'hyprctl reload' to apply"
            ;;
        *)
            log "aborted; nothing was written"
            ;;
    esac
fi
