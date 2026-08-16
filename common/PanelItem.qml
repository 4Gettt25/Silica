import QtQuick

// Hoverable rounded rectangle: the base of menu bar items, menu rows and
// plain buttons. Exposes `hovered`, `pressed` and `clicked(mouse)`.
//
// `selected` paints the macOS accent fill used by an open menu bar title or a
// highlighted menu row; set `selectedColor` to override it.
Rectangle {
    id: root

    property bool hovered: mouseArea.containsMouse
    readonly property bool pressed: mouseArea.pressed
    property bool selected: false
    property color selectedColor: Theme.selection
    property color hoverColor: Theme.hover
    property bool interactive: true
    property int acceptedButtons: Qt.LeftButton

    signal clicked(var mouse)
    signal rightClicked(var mouse)
    signal entered
    signal exited

    radius: Theme.radiusControl
    antialiasing: true
    implicitWidth: 24
    implicitHeight: 22
    color: selected ? selectedColor : (hovered && interactive ? (mouseArea.pressed ? Theme.pressed : hoverColor) : "transparent")

    Behavior on color {
        ColorAnimation {
            duration: Theme.durInstant
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        acceptedButtons: root.acceptedButtons | Qt.RightButton
        onEntered: root.entered()
        onExited: root.exited()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked(mouse);
            else
                root.clicked(mouse);
        }
    }
}
