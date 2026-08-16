import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../../common"

// The macOS on-screen display (the "HUD").
//
// A very round translucent square that appears low-centre on the screen when
// the volume or the display brightness changes, showing a big symbol over a
// 16-segment bar, then fades away after about a second.
//
// It is an overlay that must never interfere with the desktop: no keyboard
// focus, no exclusive zone, and an EMPTY input mask so clicks pass straight
// through to whatever is underneath.
//
// Triggers, in order of directness:
//   * Pipewire default-sink volume / mute changes (pushed by the service)
//   * brightnessctl, polled every 2s (sysfs backlights have no change signal)
//   * ShellState.showHud(kind, value) from anywhere in the shell
//   * `qs -c macos-shell ipc call hud volume|brightness|show` from a keybind
Scope {
    id: root

    // ------------------------------------------------------------ hud state
    // "volume" | "brightness"
    property string kind: "volume"
    property real level: 0
    property bool muted: false
    property bool shown: false

    // macOS keeps the HUD up for about a second after the last change.
    readonly property int holdMs: 1200

    // Nothing should pop up merely because a value was read for the first time
    // at startup, so the triggers stay disarmed until the shell has settled.
    property bool armed: false

    Timer {
        id: armTimer
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: root.holdMs
        onTriggered: root.shown = false
    }

    function show(kind, value) {
        root.kind = (kind === "mute") ? "volume" : kind;
        if (kind === "mute")
            root.muted = true;
        root.level = Math.max(0, Math.min(1, value));
        root.shown = true;
        hideTimer.restart();
    }

    // ---------------------------------------------------------------- volume
    readonly property PwNode sink: Pipewire.defaultAudioSink
    // Node properties are only readable while the node is bound.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    readonly property bool sinkReady: root.sink !== null && !!root.sink.audio
    readonly property real sinkVolume: root.sinkReady ? Math.max(0, Math.min(1, root.sink.audio.volume)) : 0
    readonly property bool sinkMuted: root.sinkReady && root.sink.audio.muted

    onSinkVolumeChanged: {
        if (!root.armed || !root.sinkReady)
            return;
        root.muted = root.sinkMuted;
        root.show("volume", root.sinkVolume);
    }

    onSinkMutedChanged: {
        if (!root.armed || !root.sinkReady)
            return;
        root.muted = root.sinkMuted;
        root.show("volume", root.sinkVolume);
    }

    // ------------------------------------------------------------ brightness
    // sysfs backlights emit no change notification, so the only option is a
    // cheap poll. `-c backlight` keeps brightnessctl off keyboard LEDs, and the
    // whole trigger disables itself when the machine has no backlight.
    property bool brightnessAvailable: false
    property real brightnessLevel: -1
    // Set by the ipc `brightness()` call so the next reading pops the HUD even
    // if the value did not change.
    property bool forceBrightnessShow: false

    Process {
        id: brightPoll
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || "";
                const fields = line.split(",");
                const pct = fields.length >= 5 ? parseFloat(fields[3]) : NaN;
                if (isNaN(pct)) {
                    root.brightnessAvailable = false;
                    return;
                }
                root.brightnessAvailable = true;

                const v = Math.max(0, Math.min(1, pct / 100));
                const first = root.brightnessLevel < 0;
                const changed = !first && Math.abs(v - root.brightnessLevel) > 0.005;
                root.brightnessLevel = v;

                if (root.forceBrightnessShow) {
                    root.forceBrightnessShow = false;
                    root.show("brightness", v);
                } else if (changed && root.armed) {
                    root.show("brightness", v);
                }
            }
        }
    }

    function pollBrightness() {
        if (!brightPoll.running)
            brightPoll.running = true;
    }

    Component.onCompleted: root.pollBrightness()

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.pollBrightness()
    }

    // ----------------------------------------------------------- other calls
    Connections {
        target: ShellState
        function onHudRequested(kind, value) {
            root.show(kind, value);
        }
    }

    // Compositor keybinds: `qs -c macos-shell ipc call hud volume`.
    IpcHandler {
        target: "hud"

        // Show the current volume (call this after a volume keybind).
        function volume(): void {
            root.muted = root.sinkMuted;
            root.show("volume", root.sinkVolume);
        }

        // Re-read the backlight, then show it.
        function brightness(): void {
            root.forceBrightnessShow = true;
            root.pollBrightness();
        }

        // Show an arbitrary value: kind is "volume" | "mute" | "brightness".
        function show(kind: string, value: real): void {
            root.show(kind, value);
        }
    }

    // ------------------------------------------------------------- surface
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            screen: modelData

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            // Kept mapped only while something is on screen, so the compositor
            // is not asked to blur a region nobody can see.
            visible: hud.opacity > 0.01

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "macos-shell-hud"
            color: "transparent"

            // An empty input region: every click falls through to the desktop.
            mask: Region {}

            BackgroundEffect.blurRegion: Region {
                item: hud
                radius: hud.radius
            }

            Item {
                id: hud

                readonly property real radius: Theme.radiusWindow * 2

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 140
                width: 200
                height: 200

                // macOS snaps the HUD in and lets it linger on the way out.
                opacity: root.shown ? 1 : 0
                scale: root.shown ? 1 : 0.96

                Behavior on opacity {
                    NumberAnimation {
                        duration: root.shown ? Theme.durInstant : Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: root.shown ? Theme.easeOut : Theme.easeIn
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: root.shown ? Theme.durInstant : Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                Shadow {
                    anchors.fill: parent
                    radius: hud.radius
                }

                Vibrancy {
                    anchors.fill: parent
                    material: "hud"
                    radius: hud.radius
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -Theme.space3
                    size: 88
                    name: {
                        if (root.kind === "brightness")
                            return "sun.max";
                        return root.muted ? "speaker.slash" : "speaker";
                    }
                    level: 3
                    color: Theme.label
                }

                // The 16-segment bar macOS draws under the symbol.
                Row {
                    id: segments

                    readonly property int count: 16
                    readonly property int filled: root.muted && root.kind === "volume" ? 0 : Math.round(root.level * count)

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space5
                    spacing: 3

                    Repeater {
                        model: segments.count

                        Rectangle {
                            required property int index
                            width: (160 - segments.spacing * (segments.count - 1)) / segments.count
                            height: 8
                            radius: 1.5
                            antialiasing: true
                            color: index < segments.filled ? Theme.label : Theme.quaternaryLabel

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durInstant
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
