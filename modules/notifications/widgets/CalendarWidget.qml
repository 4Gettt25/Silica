import QtQuick
import Quickshell
import "../../../common"
import ".."

// The macOS Calendar widget: current month, weekday headers, today circled.
Popover {
    id: root

    radius: Theme.radiusPopover
    contentPadding: Theme.space3
    // Children live inside Popover's padded content item, so both paddings
    // have to be added back to get the card height.
    implicitHeight: grid.y + grid.implicitHeight + contentPadding * 2

    readonly property date today: Time.now
    readonly property int year: root.today.getFullYear()
    readonly property int month: root.today.getMonth()
    readonly property int todayDate: root.today.getDate()

    // Locale decides whether the week starts on Sunday or Monday.
    // (Locale.Sunday === 0, matching Date.getDay().)
    readonly property int weekStart: Qt.locale().firstDayOfWeek

    readonly property var cells: {
        const first = new Date(root.year, root.month, 1);
        const lead = (first.getDay() - root.weekStart + 7) % 7;
        const days = new Date(root.year, root.month + 1, 0).getDate();
        const out = [];
        for (let i = 0; i < lead; i++)
            out.push({
                day: 0,
                weekend: false,
                today: false
            });
        for (let d = 1; d <= days; d++) {
            const dow = new Date(root.year, root.month, d).getDay();
            out.push({
                day: d,
                weekend: dow === 0 || dow === 6,
                today: d === root.todayDate
            });
        }
        // Pad the last week so the grid keeps a rectangular footprint.
        while (out.length % 7 !== 0)
            out.push({
                day: 0,
                weekend: false,
                today: false
            });
        return out;
    }

    readonly property real cellWidth: (width - contentPadding * 2) / 7

    StyledText {
        id: title
        x: 0
        y: 0
        role: "title3"
        color: Theme.red
        text: Qt.formatDateTime(root.today, "MMMM yyyy")
    }

    Row {
        id: weekdays
        y: title.height + Theme.space2

        Repeater {
            model: 7

            delegate: StyledText {
                required property int index

                width: root.cellWidth
                horizontalAlignment: Text.AlignHCenter
                role: "caption"
                color: Theme.tertiaryLabel
                text: Qt.locale().dayName((root.weekStart + index) % 7, Locale.NarrowFormat)
            }
        }
    }

    Grid {
        id: grid
        y: weekdays.y + weekdays.height + Theme.space1
        columns: 7

        Repeater {
            model: root.cells

            delegate: Item {
                required property var modelData

                width: root.cellWidth
                height: root.cellWidth * 0.78

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 2
                    height: width
                    radius: width / 2
                    antialiasing: true
                    visible: parent.modelData.today
                    color: Theme.red
                }

                StyledText {
                    anchors.centerIn: parent
                    role: "callout"
                    font.weight: parent.modelData.today ? Theme.wSemibold : Theme.wRegular
                    color: parent.modelData.today ? Theme.alwaysLight : (parent.modelData.weekend ? Theme.tertiaryLabel : Theme.label)
                    text: parent.modelData.day > 0 ? parent.modelData.day : ""
                }
            }
        }
    }
}
