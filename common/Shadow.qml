import QtQuick
import QtQuick.Effects

// The drop shadow macOS puts under every floating surface (menus, popovers,
// the dock, HUDs). Place it as a sibling BEHIND the surface and give it the
// same geometry and corner radius:
//
//   Shadow { anchors.fill: panel; radius: panel.radius }
//   Rectangle { id: panel; ... }
//
// Only the part of the shadow OUTSIDE the shape is drawn (the shape itself is
// masked out), so it works under translucent materials without darkening them.
Item {
    id: root

    property real radius: Theme.radiusPopover
    property color shadowColor: Theme.shadowColor
    property real blur: Theme.shadowBlur
    property real offsetY: Theme.shadowOffset
    property real offsetX: 0
    // Room for the shadow to spread outside the shape.
    readonly property int pad: Math.ceil(blur + Math.abs(offsetY) + 8)

    Item {
        id: shape
        anchors.fill: parent
        anchors.margins: -root.pad
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            x: root.pad
            y: root.pad
            width: Math.max(0, root.width)
            height: Math.max(0, root.height)
            radius: root.radius
            color: "white"
            antialiasing: true
        }
    }

    MultiEffect {
        anchors.fill: shape
        source: shape
        autoPaddingEnabled: false
        shadowEnabled: true
        shadowColor: root.shadowColor
        shadowBlur: 1.0
        blurMax: Math.round(root.blur)
        shadowVerticalOffset: root.offsetY
        shadowHorizontalOffset: root.offsetX
        // Keep only what falls outside the shape, so a translucent material
        // laid on top is not tinted by the shadow's own silhouette.
        maskEnabled: true
        maskSource: shape
        maskInverted: true
    }
}
