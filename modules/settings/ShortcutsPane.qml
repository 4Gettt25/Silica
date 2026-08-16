import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../common"

// System Settings > Shortcuts.
//
// Global keyboard shortcuts belong to the compositor, not to a shell: niri has
// no protocol that would let Quickshell grab a key, so this pane cannot bind
// anything itself. What it can do is be honest and useful — list every action
// the shell exposes over IPC, show which key is bound to it in the compositor
// config right now, and hand over the exact line to paste for the ones that
// are not bound yet.
ColumnLayout {
    id: root

    spacing: 18

    // Everything the shell can be driven with. `target`/`fn` are the IPC
    // coordinates; see the IpcHandler blocks across the modules.
    readonly property var actions: [
        {
            label: "Spotlight",
            target: "launcher",
            fn: "toggle",
            suggested: "Mod+Space"
        },
        {
            label: "Launchpad",
            target: "launchpad",
            fn: "toggle",
            suggested: "Mod+Shift+Space"
        },
        {
            label: "Mission Control",
            target: "missioncontrol",
            fn: "toggle",
            suggested: "Mod+Shift+M"
        },
        {
            label: "Control Centre",
            target: "shell",
            fn: "toggleControlCenter",
            suggested: "Mod+Shift+C"
        },
        {
            label: "Notification Centre",
            target: "shell",
            fn: "toggleNotificationCenter",
            suggested: "Mod+Shift+N"
        },
        {
            label: "Menu bar logo menu",
            target: "shell",
            fn: "toggleAppleMenu",
            suggested: "Mod+Shift+A"
        },
        {
            label: "System Settings",
            target: "shell",
            fn: "openSettings",
            suggested: "Mod+Comma"
        },
        {
            label: "Switch appearance",
            target: "shell",
            fn: "toggleAppearance",
            suggested: "Mod+Shift+D"
        },
        {
            label: "Do Not Disturb",
            target: "shell",
            fn: "toggleDoNotDisturb",
            suggested: "Mod+Shift+Z"
        },
        {
            label: "Lock Screen",
            target: "shell",
            fn: "lock",
            suggested: "Mod+Ctrl+Q"
        },
        {
            label: "Close all overlays",
            target: "shell",
            fn: "close",
            suggested: "Mod+Escape"
        }
    ]

    readonly property bool niri: Compositor.compositor === "niri"
    readonly property bool hyprland: Compositor.compositor === "hyprland"

    readonly property string configPath: {
        const home = Quickshell.env("HOME") ?? "";
        if (niri)
            return home + "/.config/niri/config.kdl";
        if (hyprland)
            return home + "/.config/hypr/hyprland.conf";
        return "";
    }

    // Both compositors let their config `include`/`source` other files in the
    // same directory (niri's config.kdl commonly splits out a binds.kdl), so
    // the bound-key scan has to cover the whole directory, not just the entry
    // file, or every action here would wrongly show "Not bound".
    readonly property string configDir: {
        const home = Quickshell.env("HOME") ?? "";
        if (niri)
            return home + "/.config/niri";
        if (hyprland)
            return home + "/.config/hypr";
        return "";
    }

    // ---- what is bound right now, read straight from the compositor config ----
    // { "launcher.toggle": "Mod+Space", ... }
    property var boundKeys: ({})

    function bindLine(action) {
        if (niri)
            return action.suggested + " { spawn \"qs\" \"ipc\" \"call\" \"" + action.target + "\" \"" + action.fn + "\"; }";
        if (hyprland)
            return "bind = " + action.suggested.replace(/\+([^+]*)$/, ", $1").replace("Mod", "SUPER") + ", exec, qs ipc call " + action.target + " " + action.fn;
        return "qs ipc call " + action.target + " " + action.fn;
    }

    function keyFor(action) {
        const k = boundKeys[action.target + "." + action.fn];
        return k === undefined ? "" : k;
    }

    Process {
        id: scan
        running: root.configDir !== ""
        // Every line of the config that spawns a `qs ipc call`, with the key
        // combo it is bound to. Quoting differs between the two config
        // formats, so the strings are simply stripped of quotes and commas.
        // Recurses through the whole config directory (-r) since the binds
        // are frequently kept in a file the entry config only `include`s.
        command: ["sh", "-c", "grep -rhE 'ipc' " + JSON.stringify(root.configDir) + " 2>/dev/null | grep -E 'qs|quickshell' || true"]

        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const raw of this.text.split("\n")) {
                    const line = raw.trim();
                    if (line.length === 0 || line.charAt(0) === "/" || line.charAt(0) === "#")
                        continue;
                    // The two words after "call" are the target and the
                    // function, whatever quoting style got them there.
                    const words = line.replace(/["',;{}]/g, " ").split(/\s+/).filter(w => w.length > 0);
                    const c = words.indexOf("call");
                    if (c < 0 || words.length < c + 3)
                        continue;

                    // niri puts the key combo first on the line; Hyprland
                    // writes "bind = MOD, KEY, exec, ...".
                    let key = "";
                    if (root.hyprland) {
                        const head = line.split("exec")[0].replace("bind", "").replace("=", "");
                        key = head.split(",").map(s => s.trim()).filter(s => s.length > 0).join("+");
                    } else {
                        key = words[0];
                    }
                    map[words[c + 1] + "." + words[c + 2]] = key.trim();
                }
                root.boundKeys = map;
            }
        }
    }

    // ------------------------------------------------------------------ UI
    SettingsGroup {
        title: "Shell Actions"

        Repeater {
            model: root.actions

            delegate: SettingsRow {
                id: row
                required property var modelData
                required property int index

                readonly property string bound: root.keyFor(modelData)

                label: modelData.label
                detail: "qs ipc call " + modelData.target + " " + modelData.fn
                showSeparator: index < root.actions.length - 1

                Row {
                    spacing: 8

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.bound !== "" ? row.bound : "Not bound"
                        color: row.bound !== "" ? Theme.label : Theme.tertiaryLabel
                        font.family: row.bound !== "" ? Theme.monoFamily : Theme.fontFamily
                    }

                    MacButton {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Copy bind"
                        onClicked: Quickshell.clipboardText = root.bindLine(row.modelData)
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: "Binding Them"

        SettingsRow {
            label: root.configPath === "" ? "No supported compositor detected" : "Compositor configuration"
            detail: {
                if (root.configPath === "")
                    return "Run the commands above however your compositor binds keys.";
                return "Keyboard shortcuts are owned by the compositor, so the shell cannot set them itself. " + "Copy the lines into " + root.configPath + " — “Copy all” uses the suggested keys for everything that is not bound yet.";
            }
            showSeparator: false

            Row {
                spacing: 8

                MacButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Copy all"
                    variant: "default"
                    interactive: root.configPath !== ""
                    onClicked: {
                        const lines = [];
                        for (const a of root.actions)
                            if (root.keyFor(a) === "")
                                lines.push(root.bindLine(a));
                        Quickshell.clipboardText = lines.join("\n");
                    }
                }

                MacButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Rescan"
                    onClicked: scan.running = true
                }
            }
        }
    }

    SettingsGroup {
        title: "Hot Corners and the Mouse"

        SettingsRow {
            label: "Hot corners"
            detail: "Each screen corner can run one of these actions — see Desktop & Dock."
            showSeparator: false

            MacButton {
                text: "Open Desktop & Dock"
                onClicked: ShellState.settingsPane = "desktop"
            }
        }
    }
}
