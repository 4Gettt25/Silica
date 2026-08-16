import QtQuick
import "../../common"

// A labelled MacSwitch row, as used in the Display detail page
// (Dark Mode / Night Shift).
Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool interactive: true

    signal toggled(bool value)

    implicitHeight: Math.max(sw.implicitHeight, text.implicitHeight)

    StyledText {
        id: text
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.right: sw.left
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        role: "body"
        text: root.label
        elide: Text.ElideRight
    }

    MacSwitch {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        interactive: root.interactive
        checked: root.checked
        onToggled: value => root.toggled(value)
    }
}
