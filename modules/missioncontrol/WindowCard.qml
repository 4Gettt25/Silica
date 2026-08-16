import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../../common"

// One window in the Mission Control grid: a live capture of the toplevel, the
// app icon overlapping its bottom-left corner and the window title underneath.
Item {
    id: root

    // A Quickshell.Wayland Toplevel handle (Compositor.toplevels).
    property var toplevel: null
    // Position in the entrance stagger.
    property int seq: 0
    // Cell box the thumbnail is fitted into.
    property real cellWidth: 200
    property real cellHeight: 120
    property real labelHeight: Theme.fsBody + Theme.space2
    // Aspect of the screen; used until the capture reports its own size.
    property real fallbackAspect: 16 / 9

    signal activated
    signal closeRequested

    width: cellWidth
    height: cellHeight + labelHeight
    implicitWidth: width
    implicitHeight: height

    readonly property string appId: toplevel ? (toplevel.appId || "") : ""
    readonly property string windowTitle: toplevel ? (toplevel.title || "") : ""

    // True once the compositor has actually delivered a capture frame.
    readonly property bool hasThumbnail: captureLoader.item ? captureLoader.item.hasContent : false

    // Human-readable application name for the no-capture fallback.
    readonly property string appName: {
        if (appId.length === 0)
            return "";
        const entry = DesktopEntries.heuristicLookup(appId);
        if (entry && entry.name)
            return entry.name;
        const seg = appId.split(".").pop().replace(/[-_]+/g, " ");
        return seg.length > 0 ? seg.charAt(0).toUpperCase() + seg.slice(1) : appId;
    }

    // ------------------------------------------------------------- entrance
    // Cards fade up from 0.9 scale, staggered by their position in the grid.
    property bool shown: false
    opacity: shown ? 1 : 0
    scale: (shown ? 1 : 0.9) * (hover.containsMouse ? 1.04 : 1.0)

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    Component.onCompleted: {
        if (!Theme.motion)
            shown = true;      // Reduce Motion: no stagger, no fade
        else
            appearTimer.start();
    }

    Timer {
        id: appearTimer
        interval: Math.min(400, root.seq * 25)
        onTriggered: root.shown = true
    }

    // ------------------------------------------------------------ thumbnail
    Item {
        id: box
        width: root.cellWidth
        height: root.cellHeight

        // The capture keeps the window's own aspect ratio inside the cell box,
        // the way macOS scales windows down into Mission Control.
        readonly property size srcSize: captureLoader.item ? captureLoader.item.sourceSize : Qt.size(0, 0)
        readonly property real srcAspect: (srcSize.width > 0 && srcSize.height > 0) ? (srcSize.width / srcSize.height) : root.fallbackAspect
        readonly property real picWidth: Math.min(width, height * srcAspect)
        readonly property real picHeight: picWidth / srcAspect

        Item {
            id: pic
            anchors.centerIn: parent
            width: box.picWidth
            height: box.picHeight

            Shadow {
                anchors.fill: parent
                radius: Theme.radiusTile
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radiusTile
                antialiasing: true
                color: Theme.windowMaterial

                // Real window thumbnail. Only compositors that implement a
                // per-toplevel capture protocol (Hyprland's
                // hyprland-toplevel-export, ext-image-copy-capture with a
                // foreign-toplevel source) produce frames here; niri 26.04
                // implements neither, so `hasContent` stays false and the card
                // below is what is shown. Created through a Loader so the view
                // is never handed a null capture source.
                Loader {
                    id: captureLoader
                    anchors.fill: parent
                    active: root.toplevel !== null && root.toplevel !== undefined
                    visible: root.hasThumbnail

                    sourceComponent: ScreencopyView {
                        captureSource: root.toplevel
                        live: true
                        paintCursor: false
                    }
                }

                // Fallback: a plain window-material card with the app icon.
                Item {
                    anchors.fill: parent
                    visible: !root.hasThumbnail

                    AppIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -Theme.space3
                        appId: root.appId
                        label: root.windowTitle
                        iconSize: Math.max(24, Math.min(parent.width, parent.height) * 0.34)
                    }

                    // The APP name, not the window title — the title is already
                    // printed under the card and repeating it reads as a bug.
                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: Math.round(parent.height * 0.16)
                        width: parent.width - Theme.space4 * 2
                        horizontalAlignment: Text.AlignHCenter
                        role: "callout"
                        color: Theme.secondaryLabel
                        elide: Text.ElideRight
                        text: root.appName
                    }
                }
            }

            // App icon, overlapping the bottom-left corner.
            AppIcon {
                appId: root.appId
                label: root.windowTitle
                iconSize: 24
                x: -Theme.space1
                y: parent.height - iconSize + Theme.space1
            }

            // Close button, macOS shows it in the top-left on hover.
            Item {
                width: 20
                height: 20
                x: -Theme.space2
                y: -Theme.space2
                opacity: hover.containsMouse ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durInstant
                    }
                }

                // `xmark.circle.fill` knocks the X out of the disc, so the
                // backing decides the X's colour: windowMaterial behind a
                // `label`-coloured disc gives a white-on-dark button in dark
                // mode and a black-on-light one in light mode.
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: width / 2
                    antialiasing: true
                    color: Theme.windowMaterial
                }

                Glyph {
                    anchors.fill: parent
                    name: "xmark.circle.fill"
                    size: 20
                    color: Theme.label
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeRequested()
                }
            }
        }
    }

    // ----------------------------------------------------------- title line
    StyledText {
        anchors.top: box.bottom
        anchors.topMargin: Theme.space1
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.cellWidth
        horizontalAlignment: Text.AlignHCenter
        role: "body"
        color: Theme.alwaysLight
        elide: Text.ElideRight
        text: root.windowTitle
    }

    MouseArea {
        id: hover
        anchors.fill: box
        hoverEnabled: true
        // z below the close button, which is a child of `pic`.
        z: -1
        onClicked: root.activated()
    }
}
