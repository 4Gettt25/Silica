import QtQuick

// A floating macOS surface: material + hairline + drop shadow + the standard
// appear/disappear transition (scale up from 94% while fading in, anchored to
// the edge it springs from).
//
// Children are placed inside the card; size it explicitly or let it wrap its
// content by leaving width/height bound to implicit sizes.
//
//   Popover {
//       screenRef: win.screen
//       shown: ShellState.controlCenterOpen
//       width: 340; height: content.implicitHeight + 24
//       Column { id: content; ... }
//   }
Item {
    id: root

    property string material: "popover"
    property real radius: Theme.radiusPopover
    property var screenRef: null
    // Drives the transition; set false to play the closing animation.
    property bool shown: true
    // Which edge the popover grows from: "top" | "bottom" | "left" | "right" | "center"
    property string origin: "top"
    property bool showShadow: true
    property real contentPadding: 0

    default property alias content: contentItem.data

    // The owning window must register this item for compositor blur:
    //   BackgroundEffect.blurRegion: Region { item: myPopover; radius: myPopover.radius }

    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.94
    visible: opacity > 0.01

    transformOrigin: {
        switch (origin) {
        case "bottom":
            return Item.Bottom;
        case "left":
            return Item.Left;
        case "right":
            return Item.Right;
        case "center":
            return Item.Center;
        default:
            return Item.Top;
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    Shadow {
        anchors.fill: parent
        radius: root.radius
        visible: root.showShadow
    }

    Vibrancy {
        anchors.fill: parent
        material: root.material
        radius: root.radius
    }

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: root.contentPadding
    }

    // Swallow clicks so they never reach a click-away dismiss layer behind.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
    }
}
