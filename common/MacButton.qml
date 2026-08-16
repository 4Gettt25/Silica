import QtQuick

// A macOS push button.
//
//   variant: "default"  filled with the accent color (the return-key action)
//            "plain"    the standard bordered control
//            "text"     borderless, accent-colored label
//            "destructive"
Item {
    id: root

    property string text: ""
    property string glyph: ""
    property string variant: "plain"
    property bool interactive: true
    signal clicked

    readonly property bool _filled: variant === "default" || variant === "destructive"
    readonly property color _fillColor: variant === "destructive" ? Theme.red : Theme.accent
    readonly property color _ink: _filled ? Theme.onAccent : (variant === "text" ? Theme.accent : Theme.label)

    implicitHeight: 24
    implicitWidth: content.implicitWidth + 26
    opacity: interactive ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        antialiasing: true
        color: {
            if (root.variant === "text")
                return mouse.containsMouse ? Theme.hover : "transparent";
            if (root._filled)
                return mouse.pressed ? Qt.darker(root._fillColor, 1.15) : root._fillColor;
            return mouse.pressed ? Theme.pressed : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.85));
        }
        border.width: root.variant === "plain" ? 1 : 0
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durInstant
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.glyph !== ""
            name: root.glyph
            size: 14
            color: root._ink
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root._ink
            font.weight: root._filled ? Theme.wMedium : Theme.wRegular
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        onClicked: root.clicked()
    }
}
