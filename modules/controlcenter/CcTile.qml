import QtQuick
import "../../common"

// A Control Center tile: the round glyph button macOS uses to switch a feature
// on or off, with its title (and optional status line) beside it.
//
// The button and the label are separate hit targets, exactly like macOS: the
// round button toggles, the label area pushes a detail page.
Item {
    id: root

    property string glyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    // false = the feature has no backend on this machine: dim it, ignore clicks.
    property bool available: true
    // true = the label area pushes a detail page instead of toggling.
    property bool hasDetail: false
    property real buttonSize: 32

    signal toggled
    signal detailRequested

    implicitHeight: Math.max(root.buttonSize, labels.implicitHeight) + Theme.space2
    implicitWidth: root.buttonSize + Theme.space2 + labels.implicitWidth + Theme.space2
    opacity: root.available ? 1 : 0.4

    Rectangle {
        id: button
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.buttonSize
        height: root.buttonSize
        radius: width / 2
        antialiasing: true
        color: root.active ? Theme.accent : (buttonArea.containsMouse ? Theme.pressed : Theme.fill)
        scale: buttonArea.pressed ? 0.92 : 1.0

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durInstant
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.glyph
            size: Math.round(root.buttonSize * 0.53)
            color: root.active ? Theme.onAccent : Theme.label
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.available
            onClicked: root.toggled()
        }
    }

    // The label block is its own hoverable row so a click on it can push the
    // detail page while the button beside it keeps toggling.
    PanelItem {
        id: labels
        anchors.left: button.right
        anchors.leftMargin: Theme.space2
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitHeight: labelCol.implicitHeight + Theme.space1 * 2
        implicitWidth: labelCol.implicitWidth + Theme.space2
        radius: Theme.radiusControl
        interactive: root.available
        hoverColor: root.hasDetail ? Theme.hover : "transparent"
        onClicked: {
            if (root.hasDetail)
                root.detailRequested();
            else
                root.toggled();
        }

        Column {
            id: labelCol
            anchors.left: parent.left
            anchors.leftMargin: Theme.space1
            anchors.right: parent.right
            anchors.rightMargin: Theme.space1
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                role: "headline"
                text: root.title
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
                maximumLineCount: 2
            }

            StyledText {
                width: parent.width
                visible: root.subtitle !== ""
                role: "caption"
                color: Theme.secondaryLabel
                text: root.subtitle
                elide: Text.ElideRight
            }
        }
    }
}
