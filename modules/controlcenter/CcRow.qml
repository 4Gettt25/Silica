import QtQuick
import "../../common"

// A row inside a detail page: optional leading glyph, a label, an optional
// trailing status string, and the macOS accent checkmark when it is the
// current choice.
PanelItem {
    id: root

    property string label: ""
    property string glyph: ""
    property string status: ""
    property bool checked: false

    implicitHeight: 28
    radius: Theme.radiusControl

    Glyph {
        id: leading
        visible: root.glyph !== ""
        anchors.left: parent.left
        anchors.leftMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        name: root.glyph
        size: 15
        color: Theme.label
    }

    StyledText {
        id: labelText
        anchors.left: root.glyph === "" ? parent.left : leading.right
        anchors.leftMargin: Theme.space2
        anchors.right: statusText.visible ? statusText.left : check.left
        anchors.rightMargin: Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        role: "body"
        text: root.label
        elide: Text.ElideRight
    }

    StyledText {
        id: statusText
        visible: root.status !== ""
        anchors.right: check.left
        anchors.rightMargin: Theme.space1
        anchors.verticalCenter: parent.verticalCenter
        role: "caption"
        color: Theme.secondaryLabel
        text: root.status
    }

    Glyph {
        id: check
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        anchors.verticalCenter: parent.verticalCenter
        // Reserve the checkmark's slot even when unchecked so labels in a list
        // do not shift as the selection moves.
        width: 14
        name: root.checked ? "checkmark" : ""
        size: 14
        color: Theme.accent
    }
}
