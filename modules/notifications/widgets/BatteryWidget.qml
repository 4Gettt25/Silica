import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../../../common"
import ".."

// Small system widget: only rendered when UPower reports a real battery.
Popover {
    id: root

    radius: Theme.radiusPopover
    contentPadding: Theme.space3

    readonly property var device: UPower.displayDevice
    // A desktop reports a "display device" too, so check it is a laptop
    // battery and that its properties have arrived.
    readonly property bool available: root.device !== null && root.device.ready && root.device.isLaptopBattery
    readonly property real level: root.available ? Math.max(0, Math.min(1, root.device.percentage)) : 0
    readonly property bool charging: root.available && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.FullyCharged)

    readonly property string statusText: {
        if (!root.available)
            return "";
        if (root.device.state === UPowerDeviceState.FullyCharged)
            return "Fully Charged";
        if (root.charging)
            return "Charging";
        const secs = root.device.timeToEmpty;
        if (secs > 0) {
            const h = Math.floor(secs / 3600);
            const m = Math.round((secs % 3600) / 60);
            return (h > 0 ? h + "h " : "") + m + "m remaining";
        }
        return "On Battery";
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space1

        Glyph {
            name: "battery"
            size: 34
            value: root.level
            charging: root.charging
            color: root.level <= 0.2 && !root.charging ? Theme.red : Theme.label
        }

        StyledText {
            role: "title1"
            text: Math.round(root.level * 100) + "%"
        }

        StyledText {
            width: parent.width
            role: "caption"
            color: Theme.secondaryLabel
            wrapMode: Text.Wrap
            text: root.statusText
        }
    }
}
