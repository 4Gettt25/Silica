import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

// "About This Mac": a centred sheet with the Apple mark, the shell name and a
// spec table, laid out like the real thing (label column right-aligned, value
// column left-aligned).
//
// The facts come from one short-lived `sh -c` that reads /proc and asks the
// installed tools for their versions — run once per open, never polled.
Scope {
    id: root

    property bool open: false
    property var screen: null

    // ------------------------------------------------------------- facts
    property string cpu: ""
    property string memory: ""
    property string quickshellVersion: ""
    property string compositorVersion: ""
    property string qtVersion: ""
    property string kernel: ""
    property string host: ""

    onOpenChanged: if (open) probe.running = true

    // "Quickshell 0.3.0 (revision , distributed by …)" -> "Quickshell 0.3.0".
    function trimBuild(s) {
        const i = s.indexOf("(");
        return (i > 0 ? s.slice(0, i) : s).trim();
    }

    Process {
        id: probe
        // A JS template literal keeps both quote styles usable in the script.
        command: ["sh", "-c", `
cpu=$(awk -F: '/^model name/{sub(/^ +/,"",$2);print $2;exit}' /proc/cpuinfo)
[ -z "$cpu" ] && cpu=$(awk -F: '/^Model/{sub(/^ +/,"",$2);print $2;exit}' /proc/cpuinfo)
mem=$(awk '/^MemTotal/{printf "%.0f", ($2+524288)/1048576}' /proc/meminfo)
qsv=$(qs --version 2>/dev/null | head -1)
comp=$(niri --version 2>/dev/null | head -1)
[ -z "$comp" ] && comp=$(Hyprland --version 2>/dev/null | head -1)
qtv=$(qmake6 -query QT_VERSION 2>/dev/null)
[ -z "$qtv" ] && qtv=$(basename "$(ls -1 /usr/lib/libQt6Core.so.6.* 2>/dev/null | head -1)" | sed 's/^libQt6Core.so.//')
printf 'cpu\t%s\nmem\t%s\nqs\t%s\ncomp\t%s\nqt\t%s\nkernel\t%s\nhost\t%s\n' "$cpu" "$mem" "$qsv" "$comp" "$qtv" "$(uname -r)" "$(uname -n)"
`]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const key = line.slice(0, tab);
                    const value = line.slice(tab + 1).trim();
                    switch (key) {
                    case "cpu":
                        root.cpu = value;
                        break;
                    case "mem":
                        root.memory = (value === "" || value === "0") ? "" : value + " GB";
                        break;
                    case "qs":
                        root.quickshellVersion = root.trimBuild(value);
                        break;
                    case "comp":
                        root.compositorVersion = root.trimBuild(value);
                        break;
                    case "qt":
                        root.qtVersion = value === "" ? "" : "Qt " + value;
                        break;
                    case "kernel":
                        root.kernel = value === "" ? "" : "Linux " + value;
                        break;
                    case "host":
                        root.host = value;
                        break;
                    default:
                        break;
                    }
                }
            }
        }
    }

    // A fact we could not read simply drops out of the table.
    readonly property var specRows: [
        {
            k: "Compositor",
            v: root.compositorVersion
        },
        {
            k: "Chip",
            v: root.cpu
        },
        {
            k: "Memory",
            v: root.memory
        },
        {
            k: "Shell",
            v: root.quickshellVersion
        },
        {
            k: "Toolkit",
            v: root.qtVersion
        },
        {
            k: "Kernel",
            v: root.kernel
        }
    ].filter(r => r.v !== "")

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: root.screen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            // Focus only while the sheet exists, so Esc closes it (DESIGN.md).
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            BackgroundEffect.blurRegion: Region {
                item: sheet
                radius: Theme.radiusWindow
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.open = false

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Popover {
                id: sheet
                screenRef: win.screen
                material: "sheet"
                radius: Theme.radiusWindow
                origin: "center"
                anchors.centerIn: parent
                width: 380
                height: column.implicitHeight + Theme.space6 * 2

                ColumnLayout {
                    id: column
                    x: Theme.space6
                    y: Theme.space6
                    width: sheet.width - Theme.space6 * 2
                    spacing: Theme.space2

                    Glyph {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Theme.space1
                        name: "apple"
                        size: 56
                        color: Theme.label
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        role: "title1"
                        text: "macos-shell"
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: Theme.space2
                        role: "callout"
                        color: Theme.secondaryLabel
                        text: root.host === "" ? "Quickshell desktop" : root.host
                    }

                    Repeater {
                        model: root.specRows

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.space2

                            StyledText {
                                Layout.preferredWidth: 96
                                horizontalAlignment: Text.AlignRight
                                role: "callout"
                                color: Theme.secondaryLabel
                                text: modelData.k
                            }

                            StyledText {
                                Layout.fillWidth: true
                                role: "callout"
                                text: modelData.v
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MacButton {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: Theme.space3
                        text: "Close"
                        variant: "default"
                        onClicked: root.open = false
                    }
                }
            }
        }
    }
}
