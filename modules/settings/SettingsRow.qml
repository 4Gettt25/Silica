import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../common"

// A single System Settings row: label (with optional secondary line) on the
// left, one control on the right, and the inset hairline macOS draws between
// rows of the same group.
//
// A row can also carry a leading icon (`iconSource`, an icon path or url, with
// `iconGlyph` as the drawn fallback), which is what the Dock's application
// list uses.
Item {
    id: root

    property string label: ""
    property string detail: ""
    property bool showSeparator: true
    property string iconSource: ""
    property string iconGlyph: ""
    readonly property bool hasIcon: iconSource !== "" || iconGlyph !== ""
    // Put the control here; it is right-aligned and vertically centred.
    default property alias control: controlHolder.data

    Layout.fillWidth: true
    implicitHeight: Math.max(38, textCol.implicitHeight + 16, controlHolder.childrenRect.height + 14)

    Item {
        id: iconHolder
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: root.hasIcon ? 24 : 0
        height: 24

        IconImage {
            anchors.fill: parent
            visible: root.iconSource !== ""
            source: root.iconSource
            asynchronous: true
        }

        Rectangle {
            anchors.fill: parent
            visible: root.iconSource === "" && root.iconGlyph !== ""
            radius: Theme.iconRadius(width)
            color: Theme.gray

            Glyph {
                anchors.centerIn: parent
                name: root.iconGlyph
                size: 14
                color: Theme.alwaysLight
            }
        }
    }

    ColumnLayout {
        id: textCol
        anchors.left: iconHolder.right
        anchors.leftMargin: root.hasIcon ? 10 : 12
        anchors.right: controlHolder.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        StyledText {
            Layout.fillWidth: true
            text: root.label
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.detail !== ""
            text: root.detail
            role: "footnote"
            color: Theme.secondaryLabel
            wrapMode: Text.WordWrap
        }
    }

    Item {
        id: controlHolder
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 12
        height: 1
        color: Theme.separator
        // The last row in a group draws no line.
        visible: root.showSeparator
    }
}
