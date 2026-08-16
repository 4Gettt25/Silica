import QtQuick

// The macOS pop-up button: a small rounded control showing the current choice
// with the double-chevron indicator, which opens a menu on click.
//
// The menu is drawn into `overlay` — pass an Item that covers the whole window
// (typically the window's root content item) so the menu can escape whatever
// clipped layout the button sits in.
//
//   MacPopupButton {
//       options: ["Bottom", "Left", "Right"]
//       currentIndex: 0
//       overlay: windowRoot
//       onSelected: i => ...
//   }
Item {
    id: root

    property var options: []
    property int currentIndex: 0
    property Item overlay: null
    property bool interactive: true
    signal selected(int index)

    readonly property string currentText: (currentIndex >= 0 && currentIndex < options.length) ? options[currentIndex] : ""
    property bool menuOpen: false

    implicitHeight: 22
    // macOS sizes a pop-up button to its WIDEST choice, so the control does
    // not resize as the user picks different values.
    implicitWidth: widestOption + 46

    property int widestOption: 40

    function _measure() {
        let w = 0;
        for (const o of options) {
            optionMetrics.text = o;
            w = Math.max(w, Math.ceil(optionMetrics.advanceWidth));
        }
        widestOption = w;
    }
    onOptionsChanged: _measure()
    Component.onCompleted: _measure()

    TextMetrics {
        id: optionMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsBody
    }
    opacity: interactive ? 1 : 0.45

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: mouse.pressed ? Theme.pressed : (Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : "#FFFFFF")
        border.width: 1
        border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)

        Behavior on color {
            ColorAnimation {
                duration: Theme.durInstant
            }
        }
    }

    StyledText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 9
        text: root.currentText
        color: Theme.label
    }

    // macOS marks a pop-up button with a small accent-filled chevron block.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 3
        width: 16
        height: 16
        radius: 4
        color: Theme.accent

        Glyph {
            anchors.centerIn: parent
            size: 13
            name: "chevron.up.chevron.down"
            color: Theme.onAccent
            weight: 2.0
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive
        onClicked: root.menuOpen = !root.menuOpen
    }

    // ---- the menu, hosted in the overlay so it is never clipped ----
    Loader {
        id: menuLoader
        active: root.menuOpen && root.overlay !== null
        parent: root.overlay

        sourceComponent: Item {
            anchors.fill: parent

            // Click-away layer.
            MouseArea {
                anchors.fill: parent
                onClicked: root.menuOpen = false
            }

            MenuCard {
                id: card
                // Positioned under the button, in overlay coordinates, and
                // clamped so it never runs off the window.
                readonly property point origin: root.mapToItem(root.overlay, 0, root.height + 4)
                x: Math.max(6, Math.min(origin.x, root.overlay.width - width - 6))
                y: Math.max(6, Math.min(origin.y, root.overlay.height - height - 6))
                minWidth: Math.max(120, root.width)
                items: root.options.map((o, i) => ({
                            text: o,
                            checked: i === root.currentIndex
                        }))
                onActivated: entry => {
                    const i = root.options.indexOf(entry.text);
                    root.menuOpen = false;
                    if (i >= 0) {
                        root.currentIndex = i;
                        root.selected(i);
                    }
                }
            }
        }
    }
}
