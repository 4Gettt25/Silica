import QtQuick
import Quickshell.Widgets
import "../../common"

// One tile of the Mission Control spaces bar: a miniature of the desktop.
//
// Wayland gives no way to capture a workspace that is not on screen, so the
// tile shows the desktop picture scaled into the thumb — which is what a macOS
// space with no full-screen app looks like anyway.
Item {
    id: root

    property int index: 1
    property bool active: false
    property url wallpaper: Wallpaper.current

    signal activated

    // ClippingRectangle (Quickshell.Widgets) is the only cheap way to clip an
    // Image to ROUNDED corners — Item.clip is always rectangular.
    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.radiusTile
        antialiasing: true
        color: Theme.scrim

        Image {
            anchors.fill: parent
            source: root.wallpaper
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        // Inactive spaces are dimmed, as in macOS.
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: root.active ? 0 : 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFast
                    easing.type: Theme.easingType
                    easing.bezierCurve: Theme.easeOut
                }
            }
        }
    }

    // Hairline, replaced by a bright outline on the active space.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusTile
        antialiasing: true
        color: "transparent"
        border.width: 1
        border.color: Theme.materialBorder
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: Theme.radiusTile + 2
        antialiasing: true
        color: "transparent"
        visible: root.active
        border.width: 2
        border.color: Theme.alwaysLight
    }

    StyledText {
        anchors.centerIn: parent
        text: String(root.index)
        role: "title2"
        color: Theme.alwaysLight
        opacity: root.active ? 1 : 0.75
    }

    scale: hover.containsMouse ? 1.04 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}
