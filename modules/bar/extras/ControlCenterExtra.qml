import QtQuick
import "../../../common"
import ".."

// Control Center toggle. The panel itself lives in modules/controlcenter.
StatusItem {
    id: root

    extraId: "controlcenter"
    implicitWidth: Theme.barGlyphSize + Theme.space2 + 2

    onActivated: ShellState.controlCenterOpen = !ShellState.controlCenterOpen

    Glyph {
        anchors.centerIn: parent
        name: "controlcenter"
        size: Theme.barGlyphSize
        color: Theme.label
    }
}
