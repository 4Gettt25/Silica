import QtQuick
import QtQuick.Layouts
import "../../../common"
import ".."

// The Focus (Do Not Disturb) moon, shown only while a Focus is on — exactly
// like macOS, where the icon appears in the bar the moment DND is enabled.
StatusItem {
    id: root

    extraId: "focus"
    visible: ShellState.doNotDisturb
    implicitWidth: Theme.barGlyphSize + Theme.space2
    popoverWidth: 240

    Glyph {
        anchors.centerIn: parent
        name: "moon"
        size: Theme.barGlyphSize - 2
        color: Theme.label
    }

    popover: ColumnLayout {
        spacing: Theme.space2

        StyledText {
            role: "headline"
            text: "Focus"
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            Glyph {
                name: "moon"
                size: 16
                color: Theme.label
            }

            StyledText {
                Layout.fillWidth: true
                text: "Do Not Disturb"
            }

            MacSwitch {
                checked: ShellState.doNotDisturb
                onToggled: v => ShellState.doNotDisturb = v
            }
        }

        StyledText {
            Layout.fillWidth: true
            role: "footnote"
            color: Theme.secondaryLabel
            wrapMode: Text.WordWrap
            text: "Notifications are silenced while Do Not Disturb is on."
        }
    }
}
