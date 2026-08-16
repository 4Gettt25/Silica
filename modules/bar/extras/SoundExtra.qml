import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../../common"
import ".."

// Sound. macOS only keeps this in the bar when it is worth keeping — muted,
// or while something is playing — so it hides itself the rest of the time.
StatusItem {
    id: root

    extraId: "sound"
    popoverWidth: 300
    implicitWidth: Theme.barGlyphSize + Theme.space2

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted
    readonly property real volume: ready ? Math.max(0, Math.min(1, sink.audio.volume)) : 0

    // Any MPRIS player currently playing.
    readonly property bool playing: {
        for (const p of Mpris.players.values) {
            if (p.isPlaying)
                return true;
        }
        return false;
    }

    visible: true

    // Output devices: real sinks, not per-application streams.
    readonly property var sinks: {
        const out = [];
        for (const n of Pipewire.nodes.values) {
            if (n.isSink && !n.isStream)
                out.push(n);
        }
        return out;
    }

    // A PwNode's properties are only populated while it is tracked.
    PwObjectTracker {
        objects: root.sinks
    }

    function setVolume(v) {
        if (root.ready)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    Glyph {
        anchors.centerIn: parent
        name: root.muted ? "speaker.slash" : "speaker"
        level: Math.max(0, Math.ceil(root.volume * 3))
        size: Theme.barGlyphSize - 1
        color: Theme.label
    }

    popover: ColumnLayout {
        spacing: Theme.space2

        StyledText {
            role: "headline"
            text: "Sound"
        }

        MacSlider {
            Layout.fillWidth: true
            glyph: "speaker"
            glyphLevelCount: 3
            value: root.muted ? 0 : root.volume
            onMoved: v => root.setVolume(v)
            onCommitted: v => {
                root.setVolume(v);
                if (root.ready && v > 0)
                    root.sink.audio.muted = false;
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            role: "caption"
            color: Theme.tertiaryLabel
            text: "Output"
        }

        Repeater {
            model: root.sinks

            delegate: PopoverRow {
                required property var modelData
                Layout.fillWidth: true
                gutter: true
                checked: Pipewire.defaultAudioSink === modelData
                label: modelData.description !== "" ? modelData.description : modelData.name
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }
}
