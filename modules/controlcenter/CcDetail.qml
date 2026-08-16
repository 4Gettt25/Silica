import QtQuick
import QtQuick.Layouts
import "../../common"

// A Control Center detail page — what macOS pushes in when you click a group's
// label. Back chevron + page title at the top, the page's own content below.
Item {
    id: root

    property string title: ""
    default property alias content: col.data

    signal back

    implicitHeight: header.height + Theme.space2 + col.implicitHeight

    PanelItem {
        id: header
        anchors.left: parent.left
        anchors.top: parent.top
        height: 26
        width: backChevron.width + titleText.implicitWidth + Theme.space3
        radius: Theme.radiusControl
        onClicked: root.back()

        Glyph {
            id: backChevron
            anchors.left: parent.left
            anchors.leftMargin: Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron.left"
            size: 14
            color: Theme.label
        }

        StyledText {
            id: titleText
            anchors.left: backChevron.right
            anchors.leftMargin: Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            role: "title3"
            text: root.title
        }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.topMargin: Theme.space2
        spacing: Theme.space2
    }
}
