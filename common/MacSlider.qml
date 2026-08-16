import QtQuick

// macOS sliders, in the two shapes the system uses:
//
//   style: "capsule"  Control Center / Sound & Display — a tall rounded track
//                     that fills with white, with the symbol riding inside it.
//   style: "linear"   the classic thin track with a round knob.
//
// Emits `moved` continuously while dragging and `committed` on release, so a
// caller can update the UI live but only write to a device on release.
Item {
    id: root

    property real value: 0.5              // 0..1
    property string style: "capsule"
    property string glyph: ""             // symbol drawn inside a capsule slider
    property int glyphLevelCount: 0       // >0: glyph.level follows the value
    property bool interactive: true
    property real minimum: 0.0            // clamp (e.g. never fully dark)

    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: Math.max(0, Math.min(1, dragging ? dragValue : value))

    signal moved(real v)
    signal committed(real v)

    implicitHeight: style === "capsule" ? 28 : 20
    implicitWidth: 200
    opacity: interactive ? 1 : 0.45

    function _clamp(v) {
        return Math.max(minimum, Math.min(1, v));
    }

    // ------------------------------------------------------------- capsule
    Item {
        anchors.fill: parent
        visible: root.style === "capsule"

        Rectangle {
            id: capsuleTrack
            anchors.fill: parent
            radius: height / 2
            antialiasing: true
            color: Theme.fill
            border.width: 1
            border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
            clip: true

            Rectangle {
                id: capsuleFill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                // Never narrower than the cap so the rounded end stays round.
                width: Math.max(parent.height, parent.width * root.shown)
                radius: parent.radius
                antialiasing: true
                color: Theme.dark ? "#E8E8EA" : "#FFFFFF"
                Behavior on width {
                    enabled: !root.dragging
                    NumberAnimation {
                        duration: Theme.durInstant
                    }
                }
            }
        }

        // The symbol is drawn twice: once in the "empty track" ink, once in
        // the "on white fill" ink clipped to the filled part, so it inverts
        // exactly at the fill edge like macOS does.
        Glyph {
            id: emptyGlyph
            visible: root.glyph !== ""
            anchors.verticalCenter: parent.verticalCenter
            x: Math.round((parent.height - size) / 2)
            size: Math.round(root.height * 0.58)
            name: root.glyph
            level: root.glyphLevelCount > 0 ? Math.max(0, Math.ceil(root.shown * root.glyphLevelCount)) : 3
            color: Theme.secondaryLabel
        }

        Item {
            anchors.fill: parent
            visible: root.glyph !== ""
            clip: true

            Item {
                width: capsuleFill.width
                height: parent.height
                clip: true

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    x: emptyGlyph.x
                    size: emptyGlyph.size
                    name: root.glyph
                    level: emptyGlyph.level
                    color: "#1D1D1F"
                }
            }
        }
    }

    // -------------------------------------------------------------- linear
    Item {
        anchors.fill: parent
        visible: root.style === "linear"

        Rectangle {
            id: linearTrack
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            radius: 2
            color: Theme.fill

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.shown
                radius: 2
                color: Theme.accent
            }
        }

        Rectangle {
            id: knob
            width: 16
            height: 16
            radius: 8
            antialiasing: true
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.shown - width / 2))
            color: "#FFFFFF"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.14)
            scale: dragArea.pressed ? 1.08 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: Theme.durInstant
                }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.interactive
        preventStealing: true

        function apply(mx) {
            root.dragValue = root._clamp(mx / Math.max(1, width));
            root.moved(root.dragValue);
        }

        onPressed: mouse => {
            root.dragging = true;
            apply(mouse.x);
        }
        onPositionChanged: mouse => {
            if (root.dragging)
                apply(mouse.x);
        }
        onReleased: mouse => {
            apply(mouse.x);
            root.dragging = false;
            root.committed(root.dragValue);
        }
        onCanceled: root.dragging = false
    }
}
