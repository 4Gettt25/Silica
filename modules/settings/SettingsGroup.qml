import QtQuick
import QtQuick.Layouts
import "../../common"

// One of the rounded cards that System Settings groups its rows into, with an
// optional caption above it. Rows are separated by inset hairlines, as in
// macOS Ventura and later.
ColumnLayout {
    id: root

    property string title: ""
    default property alias rows: rowColumn.data

    spacing: 6
    Layout.fillWidth: true

    StyledText {
        visible: root.title !== ""
        text: root.title
        role: "headline"
        Layout.leftMargin: 4
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: rowColumn.implicitHeight
        radius: Theme.radiusTile
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.6)
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.05)

        ColumnLayout {
            id: rowColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0
        }
    }
}
