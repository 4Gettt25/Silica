import QtQuick
import "../../common"

// The three window buttons macOS puts in the top-left of every window.
// Their symbols appear while the pointer is over them or anywhere over the
// window's title area (`hoveredExternally`).
Item {
    id: root

    property bool hoveredExternally: false
    readonly property bool hovered: hoveredExternally || hoverArea.containsMouse
    signal closeClicked
    signal minimizeClicked
    signal zoomClicked

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    component Light: Rectangle {
        id: light
        property color fill: "#FF5F57"
        property string symbol: "xmark"
        signal clicked

        width: 12
        height: 12
        radius: 6
        antialiasing: true
        color: fill
        border.width: 1
        border.color: Qt.darker(fill, 1.25)

        Glyph {
            anchors.centerIn: parent
            size: 9
            name: light.symbol
            color: Qt.darker(light.fill, 2.6)
            weight: 3.2
            opacity: root.hovered ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durInstant
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: light.clicked()
        }
    }

    Row {
        id: row
        spacing: 8

        Light {
            fill: Theme.trafficClose
            symbol: "xmark"
            onClicked: root.closeClicked()
        }

        Light {
            fill: Theme.trafficMinimize
            symbol: "minus"
            onClicked: root.minimizeClicked()
        }

        Light {
            fill: Theme.trafficZoom
            symbol: "arrow.up.left.and.arrow.down.right"
            onClicked: root.zoomClicked()
        }
    }

    // Hover halo: keeps the symbols visible while the pointer is near the
    // buttons, without stealing their clicks.
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: -1
    }
}
