import QtQuick

// A macOS search field: leading magnifier, placeholder, trailing clear button.
// Used by Spotlight and Launchpad; `fieldSize` switches between the giant
// Spotlight field and a normal control-sized one.
FocusScope {
    id: root

    property string text: ""
    property string placeholder: "Search"
    property int fieldSize: 22          // font pixel size
    property bool showBackground: false
    property alias input: field

    signal accepted
    signal cancelled
    signal upPressed
    signal downPressed
    signal tabPressed

    implicitHeight: Math.round(fieldSize * 2.1)

    Rectangle {
        anchors.fill: parent
        visible: root.showBackground
        radius: height / 2
        color: Theme.fill
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    }

    Glyph {
        id: magnifier
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(root.fieldSize * 0.6)
        size: Math.round(root.fieldSize * 1.05)
        name: "magnifyingglass"
        color: Theme.tertiaryLabel
        weight: 2.0
    }

    TextInput {
        id: field
        anchors {
            left: magnifier.right
            right: clearButton.left
            verticalCenter: parent.verticalCenter
            leftMargin: Math.round(root.fieldSize * 0.5)
            rightMargin: 6
        }
        focus: true
        color: Theme.label
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.family: Theme.fontFamily
        font.pixelSize: root.fieldSize
        font.letterSpacing: root.fieldSize >= 20 ? -0.5 : 0
        selectByMouse: true
        clip: true
        onTextChanged: root.text = text

        // Keep the two in sync when the caller resets `text`.
        Connections {
            target: root
            function onTextChanged() {
                if (field.text !== root.text)
                    field.text = root.text;
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: field.text.length === 0
            text: root.placeholder
            color: Theme.tertiaryLabel
            font: field.font
        }

        Keys.onEscapePressed: event => {
            event.accepted = true;
            root.cancelled();
        }
        Keys.onUpPressed: event => {
            event.accepted = true;
            root.upPressed();
        }
        Keys.onDownPressed: event => {
            event.accepted = true;
            root.downPressed();
        }
        Keys.onReturnPressed: event => {
            event.accepted = true;
            root.accepted();
        }
        Keys.onEnterPressed: event => {
            event.accepted = true;
            root.accepted();
        }
        Keys.onTabPressed: event => {
            event.accepted = true;
            root.tabPressed();
        }
    }

    Item {
        id: clearButton
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Math.round(root.fieldSize * 0.5)
        width: field.text.length > 0 ? Math.round(root.fieldSize * 0.9) : 0
        height: width
        opacity: field.text.length > 0 ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durInstant
            }
        }

        Glyph {
            anchors.fill: parent
            name: "xmark.circle.fill"
            size: parent.width
            color: clearMouse.containsMouse ? Theme.secondaryLabel : Theme.tertiaryLabel
        }

        MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                field.text = "";
                root.text = "";
                field.forceActiveFocus();
            }
        }
    }

    function clear() {
        field.text = "";
        root.text = "";
    }
    function focusInput() {
        field.forceActiveFocus();
    }
}
