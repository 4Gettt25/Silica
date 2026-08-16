import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../../common"

// One Launchpad cell: a big app icon with its name underneath.
//
// Input is handled with pointer handlers rather than a MouseArea so that the
// scroll wheel keeps reaching the paging MouseArea underneath the grid
// (a MouseArea would swallow wheel events even without a handler for them).
Item {
    id: tile

    property var entry: null
    property real iconSize: 96

    signal activated

    readonly property string label: entry ? (entry.name || "") : ""
    // "" when the theme has no icon for this app -> initial-tile fallback.
    readonly property string iconSource: (entry && entry.icon) ? Quickshell.iconPath(entry.icon, true) : ""

    readonly property color tileColor: {
        let h = 0;
        for (let i = 0; i < label.length; i++)
            h = (h * 31 + label.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360.0, 0.55, 0.5, 1.0);
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: Theme.space2

        Item {
            id: iconCell
            width: tile.iconSize
            height: tile.iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            // macOS scales an icon down while the pointer is held on it.
            scale: tap.pressed ? 0.9 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durInstant
                    easing.type: Theme.easingType
                    easing.bezierCurve: Theme.easeOut
                }
            }

            // The shadow source is rendered into a layer and drawn by the
            // MultiEffect below, so the icon keeps macOS's soft drop shadow.
            Item {
                id: iconSource
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                visible: false

                IconImage {
                    anchors.fill: parent
                    anchors.margins: Math.round(tile.iconSize * 0.06)
                    visible: tile.iconSource.length > 0
                    source: tile.iconSource
                    implicitSize: tile.iconSize
                    mipmap: true
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Math.round(tile.iconSize * 0.06)
                    visible: tile.iconSource.length === 0
                    radius: Theme.iconRadius(width)
                    color: tile.tileColor

                    StyledText {
                        anchors.centerIn: parent
                        role: "title1"
                        font.pixelSize: Math.round(parent.width * 0.42)
                        font.weight: Theme.wBold
                        color: Theme.alwaysLight
                        text: tile.label.length > 0 ? tile.label.charAt(0).toUpperCase() : "?"
                    }
                }
            }

            MultiEffect {
                anchors.fill: iconSource
                source: iconSource
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: Theme.shadowColor
                shadowBlur: 1.0
                blurMax: Math.round(Theme.shadowBlur / 2)
                shadowVerticalOffset: Math.round(Theme.shadowOffset / 2)
            }
        }

        StyledText {
            width: parent.width - Theme.space4
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            role: "subheadline"
            // Names sit directly on the blurred wallpaper.
            color: Theme.alwaysLight
            style: Text.Raised
            styleColor: Theme.shadowColor
            text: tile.label
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
    }

    TapHandler {
        id: tap
        onTapped: tile.activated()
    }
}
