import QtQuick
import "../../common"

// The clickable heading of a group ("Display", "Sound"). In macOS this is the
// affordance that pushes the group's detail page, so it hovers like a row.
PanelItem {
    id: root

    property alias text: label.text

    implicitHeight: label.implicitHeight + Theme.space1
    radius: Theme.radiusControl

    StyledText {
        id: label
        anchors.left: parent.left
        anchors.leftMargin: Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        role: "headline"
    }
}
