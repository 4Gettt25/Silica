import QtQuick

// The macOS segmented control: a pill-shaped track with the selected segment
// drawn as a raised, lighter capsule that slides between positions.
//
//   MacSegmented {
//       options: ["Light", "Dark", "Auto"]
//       currentIndex: 1
//       onSelected: i => ...
//   }
Item {
    id: root

    property var options: []
    property int currentIndex: 0
    property bool interactive: true
    signal selected(int index)

    readonly property int segmentWidth: options.length > 0 ? Math.floor((width - 4) / options.length) : 0

    implicitHeight: 24
    implicitWidth: Math.max(120, options.length * 74)
    opacity: interactive ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl + 1
        color: Theme.fill
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    }

    // The sliding selection capsule.
    Rectangle {
        y: 2
        height: parent.height - 4
        width: root.segmentWidth
        x: 2 + root.currentIndex * root.segmentWidth
        radius: Theme.radiusControl
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.18) : "#FFFFFF"
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)

        Behavior on x {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 2

        Repeater {
            model: root.options

            delegate: Item {
                required property string modelData
                required property int index

                width: root.segmentWidth
                height: parent.height

                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData
                    role: "body"
                    color: Theme.label
                    font.weight: root.currentIndex === parent.index ? Theme.wMedium : Theme.wRegular
                }

                // Hairline divider between unselected segments, as in macOS.
                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: parent.height - 10
                    visible: parent.index < root.options.length - 1 && root.currentIndex !== parent.index && root.currentIndex !== parent.index + 1
                    color: Theme.separator
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    onClicked: {
                        root.currentIndex = parent.index;
                        root.selected(parent.index);
                    }
                }
            }
        }
    }
}
