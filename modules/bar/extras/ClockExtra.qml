import QtQuick
import "../../../common"
import ".."

// The menu bar clock. Clicking it opens Notification Center, as in macOS.
StatusItem {
    id: root

    extraId: "clock"
    implicitWidth: clockLabel.implicitWidth + Theme.barItemPadding * 2

    onActivated: ShellState.notificationCenterOpen = !ShellState.notificationCenterOpen

    StyledText {
        id: clockLabel
        anchors.centerIn: parent
        role: "bar"
        text: Time.clock
        color: Theme.label
    }
}
