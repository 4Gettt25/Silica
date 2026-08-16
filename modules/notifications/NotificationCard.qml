import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../common"

// One notification card: the material tile with icon, app name, relative time,
// summary, body and (optionally) action buttons — shared by the banner layer
// and the Notification Center so both stay identical.
//
// The card only renders and reports intent; who dismisses what is decided by
// the owner (banner stack / notification centre).
Item {
    id: root

    property var entry: null
    property bool showShadow: false
    property bool showActions: true
    property bool showClose: true
    property real radius: NotifMetrics.cardRadius
    // Set by the owner while a group is collapsed, so the front card can leave
    // room for the "N more" line.
    property string footnote: ""

    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool pressing: hoverArea.pressed
    readonly property bool critical: root.entry && root.entry.urgency === NotificationUrgency.Critical
    readonly property var actionList: root.showActions && root.entry ? NotificationStore.actionsOf(root.entry) : []

    signal activated
    signal closeRequested
    // Horizontal drag on the card body, reported so a banner can implement
    // swipe-to-dismiss without covering the action buttons with its own
    // MouseArea (this one sits UNDER the content).
    signal dragged(real dx)
    signal dragReleased(real dx, bool moved)

    implicitHeight: layout.implicitHeight + NotifMetrics.cardPadding * 2

    Shadow {
        anchors.fill: parent
        radius: root.radius
        visible: root.showShadow
    }

    Vibrancy {
        anchors.fill: parent
        material: "popover"
        radius: root.radius
    }

    // Declared before the content so the action buttons (later siblings) win
    // the hit test; this one only catches clicks on the card background.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true

        property real pressX: 0
        property bool moved: false

        onPressed: mouse => {
            pressX = mouse.x;
            moved = false;
        }
        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const dx = mouse.x - pressX;
            if (Math.abs(dx) > 4)
                moved = true;
            root.dragged(dx);
        }
        onReleased: mouse => root.dragReleased(mouse.x - pressX, moved)
        onClicked: if (!moved)
            root.activated()
    }

    Column {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: NotifMetrics.cardPadding
        spacing: Theme.space1

        Row {
            width: parent.width
            spacing: Theme.space2 + 2

            AppIcon {
                id: icon
                appName: root.entry ? root.entry.appName : ""
                iconName: root.entry ? root.entry.appIcon : ""
                imagePath: root.entry ? root.entry.image : ""
            }

            Column {
                width: parent.width - icon.width - parent.spacing
                spacing: 1

                Item {
                    width: parent.width
                    height: appLine.implicitHeight

                    StyledText {
                        id: appLine
                        anchors.left: parent.left
                        anchors.right: stamp.left
                        anchors.rightMargin: Theme.space2
                        role: "caption"
                        color: root.critical ? Theme.red : Theme.secondaryLabel
                        elide: Text.ElideRight
                        text: root.entry ? root.entry.appName : ""
                    }

                    StyledText {
                        id: stamp
                        anchors.right: parent.right
                        anchors.baseline: appLine.baseline
                        role: "caption"
                        color: Theme.tertiaryLabel
                        // Reads Time.now inside relative(), so the label keeps
                        // itself current as the clock ticks.
                        text: root.entry ? Time.relative(root.entry.time) : ""
                    }
                }

                StyledText {
                    width: parent.width
                    role: "headline"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                    text: root.entry ? root.entry.summary : ""
                }

                StyledText {
                    width: parent.width
                    role: "body"
                    color: Theme.secondaryLabel
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    visible: text.length > 0
                    // The server advertises body markup, so clients may send
                    // the small HTML subset the spec allows.
                    textFormat: Text.StyledText
                    text: root.entry ? root.entry.body : ""
                }

                StyledText {
                    width: parent.width
                    role: "caption"
                    color: Theme.tertiaryLabel
                    visible: root.footnote.length > 0
                    topPadding: Theme.space1
                    text: root.footnote
                }
            }
        }

        Item {
            width: parent.width
            height: actions.implicitHeight + Theme.space1
            visible: root.actionList.length > 0

            Row {
                id: actions
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.space2

                Repeater {
                    model: root.actionList

                    delegate: MacButton {
                        required property var modelData
                        required property int index

                        text: modelData.text && modelData.text.length > 0 ? modelData.text : modelData.identifier
                        variant: index === 0 ? "default" : "plain"
                        onClicked: NotificationStore.invoke(root.entry, modelData)
                    }
                }
            }
        }
    }

    // macOS reveals a close button in the top-left corner on hover.
    Item {
        id: closeButton
        width: 18
        height: 18
        x: -width / 3
        y: -height / 3
        visible: root.showClose
        opacity: (root.hovered || closeArea.containsMouse) ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }

        // The glyph knocks the cross out of the filled circle, so a solid
        // backing disc is needed for it to read on a translucent material.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 4
            height: width
            radius: width / 2
            color: Theme.dark ? Qt.rgba(0.32, 0.32, 0.34, 1) : Qt.rgba(0.78, 0.78, 0.80, 1)
        }

        Glyph {
            // Glyph binds its own width/height to `size`; anchoring it would
            // fight those bindings, so it is only centred.
            anchors.centerIn: parent
            name: "xmark.circle.fill"
            size: parent.width
            color: closeArea.containsMouse ? Theme.label : Theme.secondaryLabel
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            anchors.margins: -Theme.space1
            hoverEnabled: true
            onClicked: root.closeRequested()
        }
    }
}
