import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../../../common"
import ".."

// Battery indicator, backed by the UPower service.
//
// `UPower.displayDevice` is UPower's own composite "what should the panel
// show" device. On a desktop it still exists, but reports isPresent == false
// and a type other than Battery — which is what hides this whole item, so a
// machine running off the wall never shows a battery it does not have.
StatusItem {
    id: root

    extraId: "battery"
    popoverWidth: 260

    readonly property var device: UPower.displayDevice
    // `isLaptopBattery` is UPower's own "this is the machine's battery" test;
    // a desktop's display device fails it, as does a mouse or a headset.
    readonly property bool present: device !== null && device.ready && device.isLaptopBattery && device.isPresent

    // UPower reports a percentage; Quickshell normalises it to 0..1, but be
    // tolerant of a 0..100 value so the bar never shows "6200%".
    readonly property real fraction: {
        if (!present)
            return 0;
        const p = device.percentage;
        return Math.max(0, Math.min(1, p > 1 ? p / 100 : p));
    }
    readonly property int percent: Math.round(fraction * 100)
    readonly property bool charging: present && device.state === UPowerDeviceState.Charging
    readonly property bool full: present && device.state === UPowerDeviceState.FullyCharged
    readonly property bool onAdapter: !UPower.onBattery

    // Below 20% and unplugged macOS turns the battery red.
    readonly property color batteryColor: (!charging && !onAdapter && fraction <= 0.2) ? Theme.red : Theme.label

    visible: present
    implicitWidth: batteryRow.implicitWidth + Theme.barItemPadding * 2

    // "1:23 remaining" / "1:05 until full"; empty while UPower is still
    // estimating (it reports 0 until it has a rate).
    function _hm(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return h + ":" + (m < 10 ? "0" : "") + m;
    }

    readonly property string timeLabel: {
        if (!present)
            return "";
        if (full)
            return "Fully Charged";
        if (charging) {
            const t = _hm(device.timeToFull);
            return t === "" ? "Calculating…" : t + " Until Full";
        }
        const t = _hm(device.timeToEmpty);
        return t === "" ? "Calculating…" : t + " Remaining";
    }

    Row {
        id: batteryRow
        anchors.centerIn: parent
        spacing: Theme.space1

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            role: "bar"
            text: root.percent + "%"
            color: root.batteryColor
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: "battery"
            size: Theme.barGlyphSize + 2
            value: root.fraction
            charging: root.charging
            color: root.batteryColor
        }
    }

    popover: ColumnLayout {
        spacing: Theme.space2

        StyledText {
            role: "headline"
            text: "Battery"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Glyph {
                name: "battery"
                size: 26
                value: root.fraction
                charging: root.charging
                color: root.batteryColor
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    role: "title3"
                    text: root.percent + "%"
                }

                StyledText {
                    role: "footnote"
                    color: Theme.secondaryLabel
                    text: root.timeLabel
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        RowLayout {
            Layout.fillWidth: true

            StyledText {
                role: "callout"
                color: Theme.secondaryLabel
                text: "Power Source"
            }

            Item {
                Layout.fillWidth: true
            }

            StyledText {
                role: "callout"
                text: root.onAdapter ? "Power Adapter" : "Battery"
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        PopoverRow {
            Layout.fillWidth: true
            label: "Battery Settings…"
            onClicked: {
                ShellState.openMenu = "";
                BarActions.openSettings("");
            }
        }
    }
}
