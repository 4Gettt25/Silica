import QtQuick
import Quickshell
import "../../common"

// All notifications of one app in Notification Center.
//
// Collapsed it shows the newest card with up to two cards peeking out from
// behind it and an "N more" line; clicking expands the stack.
Item {
    id: root

    property var group: null // { appName, entries: [] }
    property bool expanded: false

    readonly property int count: root.group ? root.group.entries.length : 0
    readonly property var newest: root.count > 0 ? root.group.entries[0] : null
    readonly property int peeks: Math.min(2, Math.max(0, root.count - 1))
    readonly property real peekStep: Theme.space1 + 1

    implicitHeight: root.expanded ? expandedColumn.implicitHeight : (front.implicitHeight + root.peeks * root.peekStep)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    // ------------------------------------------------------ collapsed stack
    Item {
        id: collapsed
        anchors.fill: parent
        visible: !root.expanded && root.count > 0
        opacity: visible ? 1 : 0

        // The cards behind the front one: just the material, peeking out at
        // the bottom, narrower on each side.
        Repeater {
            model: root.peeks

            delegate: Vibrancy {
                required property int index

                // index 0 is the nearest card behind the front one.
                readonly property int depth: index + 1

                x: depth * Theme.space2 / 2
                y: depth * root.peekStep
                width: collapsed.width - depth * Theme.space2
                height: front.implicitHeight
                z: -depth
                material: "popover"
                radius: NotifMetrics.cardRadius
                opacity: 1 - depth * 0.25
            }
        }

        NotificationCard {
            id: front
            width: parent.width
            entry: root.newest
            showActions: false
            footnote: root.count > 1 ? (root.count - 1) + " more" : ""

            onActivated: {
                if (root.count > 1)
                    root.expanded = true;
                else if (root.newest)
                    NotificationStore.activate(root.newest);
            }
            onCloseRequested: {
                if (root.count > 1)
                    NotificationStore.removeApp(root.group.appName);
                else if (root.newest)
                    NotificationStore.remove(root.newest.id);
            }
        }
    }

    // -------------------------------------------------------- expanded list
    Column {
        id: expandedColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.space2
        visible: root.expanded

        Item {
            width: parent.width
            height: Math.max(header.implicitHeight, showLess.implicitHeight)

            StyledText {
                id: header
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                color: Theme.secondaryLabel
                text: root.group ? root.group.appName : ""
            }

            MacButton {
                id: showLess
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                variant: "text"
                text: "Show Less"
                onClicked: root.expanded = false
            }
        }

        Repeater {
            model: root.expanded && root.group ? root.group.entries : []

            delegate: NotificationCard {
                required property var modelData

                width: expandedColumn.width
                entry: modelData
                onActivated: NotificationStore.activate(modelData)
                onCloseRequested: NotificationStore.remove(modelData.id)
            }
        }
    }
}
