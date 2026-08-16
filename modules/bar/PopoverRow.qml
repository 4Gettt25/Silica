import QtQuick
import "../../common"

// One row inside a menu-bar-extra popover: an optional checkmark gutter, a
// label, an optional right-aligned detail string and the two trailing symbols
// the Wi-Fi list needs (a lock for secured networks, a signal strength glyph).
//
// Deliberately NOT a slot-based container: redeclaring `default property` on a
// Rectangle subclass would also swallow this file's own children.
PanelItem {
    id: root

    property string label: ""
    property string detail: ""
    // Reserve the checkmark gutter even when unchecked so labels line up.
    property bool gutter: false
    property bool checked: false
    property bool emphasised: false
    property color labelColor: Theme.label
    // Trailing symbols; -1 / false hides them.
    property int signalLevel: -1
    property bool secured: false

    implicitHeight: 24
    implicitWidth: 100
    radius: 5

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.space1
        size: 12
        weight: 2.4
        name: root.checked ? "checkmark" : ""
        color: Theme.label
        visible: root.gutter
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        x: root.gutter ? Theme.space1 + 16 : Theme.space2
        width: parent.width - x - trailingRow.width - Theme.space2 * 2
        text: root.label
        color: root.labelColor
        font.weight: root.emphasised ? Theme.wSemibold : Theme.wRegular
        elide: Text.ElideRight
    }

    Row {
        id: trailingRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.space2
        spacing: Theme.space1

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.detail !== ""
            text: root.detail
            color: Theme.secondaryLabel
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.secured
            name: "lock"
            size: 11
            color: Theme.secondaryLabel
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.signalLevel >= 0
            name: "wifi"
            level: root.signalLevel
            size: 14
            color: Theme.label
        }
    }
}
