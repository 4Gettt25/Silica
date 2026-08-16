import QtQuick
import "../../../common"
import ".."

// Spotlight. Opens the launcher (modules/launcher).
StatusItem {
    id: root

    extraId: "spotlight"
    implicitWidth: Theme.barGlyphSize + Theme.space2

    onActivated: ShellState.launcherOpen = true

    Glyph {
        anchors.centerIn: parent
        name: "magnifyingglass"
        size: Theme.barGlyphSize - 2
        weight: 2.0
        color: Theme.label
    }
}
