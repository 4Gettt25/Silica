pragma Singleton

import QtQuick
import Quickshell

// How the shell hands a path to another program.
//
// `xdg-open` alone is not good enough for a *location*: whatever claims the
// inode/directory mime type wins, and that is often a terminal. On this machine
// it is kitty-open.desktop (`kitty +open %U`), which is why clicking Downloads
// in the dock opened terminal windows instead of a file manager.
//
// Which program that should be is a property of the session, not of the shell,
// so it is read from the environment rather than from Settings — the same place
// the session's other choices live. Set it beside them in
// ~/.config/niri/environment.kdl:
//
//     environment {
//         FILE_MANAGER "nautilus"
//     }
//
// niri hands that to everything it spawns, including the shell's launcher, and
// it is picked up at startup. With nothing set, every call here falls back to
// xdg-open, which is still the right answer on a machine whose mime defaults
// point at a file manager.
Singleton {
    id: root

    // The first of these that is actually set. FILE_MANAGER is the name this
    // shell documents; FILEMANAGER is accepted too, because plenty of existing
    // setups already export that spelling.
    readonly property string fileManager: {
        const names = ["FILE_MANAGER", "FILEMANAGER"];
        for (let i = 0; i < names.length; i++) {
            const v = String(Quickshell.env(names[i]) ?? "").trim();
            if (v.length > 0)
                return v;
        }
        return "";
    }

    // Run `fileManager <target>` through a shell, so the variable may carry
    // arguments ("nautilus --new-window", "kitty -e lf"). The target is passed
    // as an argument rather than interpolated, so spaces and quotes in a file
    // name cannot turn into extra words.
    function _spawn(script, target) {
        Quickshell.execDetached(["sh", "-c", script, "sh", target]);
    }

    // A directory, or any URI a file manager understands (trash:///, ...).
    function location(target) {
        if (fileManager.length === 0) {
            Quickshell.execDetached(["xdg-open", target]);
            return;
        }
        _spawn(fileManager + ' "$1"', target);
    }

    // Something that may be either. A folder belongs in the file manager; a
    // document belongs to whatever app owns its type, and routing that through
    // the file manager too would be wrong. QML cannot stat, and the answer can
    // change between opening the stack and clicking a row, so the test is done
    // in the shell at the moment of the click.
    function path(target) {
        if (fileManager.length === 0) {
            Quickshell.execDetached(["xdg-open", target]);
            return;
        }
        _spawn('if [ -d "$1" ]; then exec ' + fileManager + ' "$1"; else exec xdg-open "$1"; fi', target);
    }
}
