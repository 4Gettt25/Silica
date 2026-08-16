import QtQuick
import QtQuick.Layouts
import "../../common"

// One Control Center "group": the rounded translucent slab a set of tiles or a
// slider sits in. macOS stacks these vertically with a small gap between them,
// each one a fill on top of the popover material (never its own material).
//
//   CcGroup {
//       Layout.fillWidth: true
//       CcTile { Layout.fillWidth: true; ... }
//   }
Rectangle {
    id: root

    // Inset from the slab edge to its contents.
    property real padding: Theme.space2
    property alias spacing: col.spacing
    // Children go into the internal column, not onto the Rectangle itself.
    default property alias content: col.data

    color: Theme.tertiaryFill
    radius: Theme.radiusTile
    antialiasing: true
    implicitHeight: col.implicitHeight + root.padding * 2
    implicitWidth: col.implicitWidth + root.padding * 2

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Theme.space1
    }
}
