import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../common"

// The grid preview a dock "stack" (Downloads) fans out when it is hovered.
//
// `files` is a list of plain file names, newest first, as produced by
// DockApps.downloadFiles; `directory` is what they are relative to. The
// component sizes itself, because DockIcon loads it into a Loader that has no
// geometry of its own.
Item {
    id: root

    property var files: []
    property string directory: ""
    property real tileSize: 44

    readonly property int count: files ? Math.min(files.length, 6) : 0
    readonly property int columns: Math.max(1, Math.min(3, count))
    readonly property int rows: Math.max(1, Math.ceil(count / columns))

    readonly property real labelHeight: Math.round(Theme.fsCaption * 2.2)
    readonly property real cellW: tileSize + Theme.space3
    readonly property real cellH: tileSize + labelHeight

    readonly property real pad: Theme.space3

    implicitWidth: count === 0 ? 160 : Math.round(columns * cellW + pad * 2)
    implicitHeight: Math.round((count === 0 ? Theme.fsBody * 2 : rows * cellH) + pad * 2)
    width: implicitWidth
    height: implicitHeight

    // Mime icon names are the one thing an icon theme is guaranteed to have
    // for a file; extensions are matched conservatively and everything else
    // falls back to the generic document.
    function iconFor(name) {
        const ext = (name.indexOf(".") > 0 ? name.split(".").pop() : "").toLowerCase();
        if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif", "heic"].indexOf(ext) >= 0)
            return "image-x-generic";
        if (["mp4", "mkv", "webm", "mov", "avi", "m4v"].indexOf(ext) >= 0)
            return "video-x-generic";
        if (["mp3", "flac", "ogg", "wav", "opus", "m4a"].indexOf(ext) >= 0)
            return "audio-x-generic";
        if (ext === "pdf")
            return "application-pdf";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(ext) >= 0)
            return "package-x-generic";
        if (ext === "")
            return "folder";
        return "text-x-generic";
    }

    function isImage(name) {
        const ext = (name.indexOf(".") > 0 ? name.split(".").pop() : "").toLowerCase();
        return ["png", "jpg", "jpeg", "gif", "webp", "bmp"].indexOf(ext) >= 0;
    }

    // `ls -t` lists directories as well as files, so a row can be either —
    // Opener.path sorts that out at click time.
    function open(name) {
        Opener.path(root.directory + "/" + name);
    }

    Shadow {
        anchors.fill: parent
        radius: Theme.radiusPopover
    }

    Vibrancy {
        anchors.fill: parent
        material: "popover"
        radius: Theme.radiusPopover
    }

    StyledText {
        anchors.centerIn: parent
        visible: root.count === 0
        role: "callout"
        color: Theme.secondaryLabel
        text: "Empty"
    }

    Grid {
        anchors.centerIn: parent
        columns: root.columns
        visible: root.count > 0

        Repeater {
            model: root.count

            delegate: Item {
                id: fileTile
                required property int index

                readonly property string fileName: String(root.files[fileTile.index] ?? "")

                width: root.cellW
                height: root.cellH

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: Theme.radiusControl
                    color: Theme.hover
                    opacity: hover.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durInstant
                        }
                    }
                }

                // A real thumbnail for pictures, the mime icon for everything
                // else — the same trade-off Finder makes.
                Item {
                    id: art
                    width: root.tileSize
                    height: root.tileSize
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(Theme.space1 / 2)

                    Image {
                        anchors.fill: parent
                        visible: root.isImage(fileTile.fileName) && status === Image.Ready
                        source: root.isImage(fileTile.fileName) ? ("file://" + root.directory + "/" + fileTile.fileName) : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: Math.round(root.tileSize * 2)
                        sourceSize.height: Math.round(root.tileSize * 2)
                        asynchronous: true
                        mipmap: true
                        clip: true
                    }

                    IconImage {
                        anchors.fill: parent
                        visible: !(root.isImage(fileTile.fileName))
                        source: Quickshell.iconPath(root.iconFor(fileTile.fileName), "text-x-generic")
                        implicitSize: Math.round(root.tileSize)
                        asynchronous: true
                    }
                }

                StyledText {
                    anchors.top: art.bottom
                    anchors.topMargin: Theme.space1
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Theme.space2
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"
                    text: fileTile.fileName
                    elide: Text.ElideMiddle
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: root.open(fileTile.fileName)
                }
            }
        }
    }
}
