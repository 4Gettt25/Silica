import QtQuick
import Quickshell
import Quickshell.Io
import "../../common"

// Spotlight.
//
// Bind a key to toggle it:
//   qs -c macos-shell ipc call launcher toggle
//   hyprland:  bind = SUPER, SPACE, exec, qs -c macos-shell ipc call launcher toggle
//   niri:      Super+Space { spawn "qs" "-c" "macos-shell" "ipc" "call" "launcher" "toggle"; }
Scope {
    id: root

    // ShellState enforces "at most one modal surface" itself (see its
    // onLauncherOpenChanged), so setting the flag is all a module ever does.
    function open() {
        ShellState.launcherOpen = true;
    }

    function close() {
        ShellState.launcherOpen = false;
    }

    // Open with the field pre-filled (used by "search this" callers and by the
    // dev harness, which cannot type into the nested compositor).
    function searchFor(query) {
        seed = query;
        ShellState.launcherOpen = true;
    }

    // Seed text handed to the window when it is created, or while it is open.
    property string seed: ""

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            ShellState.launcherOpen = !ShellState.launcherOpen;
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function search(query: string): void {
            root.searchFor(query);
        }
    }

    // The window must not outlive the surface being open (keyboard focus), but
    // it does have to outlive the flag for as long as the closing transition
    // runs — hence the short grace period below.
    property bool closing: false

    Timer {
        id: graceTimer
        interval: Theme.durFast + 30
        onTriggered: root.closing = false
    }

    Connections {
        target: ShellState

        function onLauncherOpenChanged() {
            if (ShellState.launcherOpen) {
                root.closing = false;
                graceTimer.stop();
            } else if (loader.active) {
                root.closing = true;
                graceTimer.restart();
            }
        }
    }

    LazyLoader {
        id: loader
        active: ShellState.launcherOpen || root.closing

        SpotlightWindow {
            seed: root.seed
        }
    }
}
