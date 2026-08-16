import QtQuick
import "../../common"

// One hot corner: a few pixels of hover target that runs `action` after the
// pointer has rested in it. It re-arms only once the pointer has left, so
// parking the mouse in a corner does not trigger the action over and over.
MouseArea {
    id: corner

    // An action name ShellState.runAction() understands; "" disables it.
    property string action: ""
    property int dwellMs: 180

    width: 6
    height: 6
    hoverEnabled: true
    // A corner is inert while a full-screen overlay is up — otherwise moving
    // the pointer back out of Mission Control would immediately reopen it.
    enabled: action !== "" && !ShellState.anyOverlayOpen
    // Hover only: a click in the corner belongs to whatever is underneath.
    acceptedButtons: Qt.NoButton

    onEntered: dwell.restart()
    onExited: dwell.stop()

    Timer {
        id: dwell
        interval: corner.dwellMs
        onTriggered: {
            if (corner.containsMouse)
                ShellState.runAction(corner.action);
        }
    }
}
