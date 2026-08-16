import QtQuick

// The macOS toggle switch: a 38x22 capsule whose knob slides and whose track
// fills with the accent color when on.
Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal toggled(bool value)

    implicitWidth: 38
    implicitHeight: 22
    opacity: interactive ? 1 : 0.45

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        antialiasing: true
        color: root.checked ? Theme.accent : Theme.fill
        border.width: root.checked ? 0 : 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durFast
            }
        }
    }

    Rectangle {
        id: knob
        y: 2
        width: parent.height - 4
        height: width
        radius: width / 2
        antialiasing: true
        x: root.checked ? parent.width - width - 2 : 2
        color: "#FFFFFF"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.10)

        Behavior on x {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
