import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../common"

// System Settings > Desktop & Dock > "Applications in the Dock".
//
// Edits Settings.dockPinned through the Apps singleton, which is the same list
// the dock itself lays out — so a change here shows up in the dock as soon as
// it is written, with no reload.
//
// Launchpad is deliberately not editable: it is always the dock's first icon.
ColumnLayout {
    id: root

    // An Item covering the whole settings window; the app picker is drawn into
    // it so it is not clipped by the settings scroller.
    property Item overlay: null

    property bool pickerOpen: false

    spacing: 6
    Layout.fillWidth: true

    readonly property var pinned: Apps.pinnedKeys

    SettingsGroup {
        title: "Applications in the Dock"

        Repeater {
            model: root.pinned

            delegate: SettingsRow {
                id: row

                required property string modelData
                required property int index

                readonly property var item: Apps.makeItem(modelData, true)
                readonly property bool fixed: modelData === "@launchpad"

                label: item.name
                detail: {
                    if (row.fixed)
                        return "Always the first icon in the Dock";
                    if (modelData.charAt(0) === "@")
                        return "Built into the shell";
                    return modelData;
                }
                iconSource: item.iconPath
                iconGlyph: item.iconPath === "" ? (item.glyph === "" ? "circle.fill" : item.glyph) : ""
                showSeparator: index < root.pinned.length - 1

                Row {
                    spacing: 6

                    MacButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        glyph: "chevron.up"
                        interactive: row.index > 1
                        onClicked: Apps.movePinned(row.index, row.index - 1)
                    }

                    MacButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        glyph: "chevron.down"
                        interactive: !row.fixed && row.index < root.pinned.length - 1
                        onClicked: Apps.movePinned(row.index, row.index + 1)
                    }

                    MacButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        glyph: "minus"
                        interactive: !row.fixed
                        onClicked: Apps.setPinned(row.modelData, false)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 4
        spacing: 8

        MacButton {
            text: "Add App…"
            variant: "default"
            onClicked: root.pickerOpen = true
        }

        MacButton {
            text: "Reset to Defaults"
            onClicked: Apps.resetPinned()
        }

        Item {
            Layout.fillWidth: true
        }

        StyledText {
            role: "footnote"
            color: Theme.secondaryLabel
            text: "Right-click a Dock icon for “Keep in Dock”."
        }
    }

    // ------------------------------------------------------------- picker
    Loader {
        active: root.pickerOpen && root.overlay !== null
        parent: root.overlay
        // Reparenting does not bring anchors with it, and a Loader with no
        // size would leave the dialog inside it at 0x0.
        width: root.overlay ? root.overlay.width : 0
        height: root.overlay ? root.overlay.height : 0

        sourceComponent: Item {
            anchors.fill: parent

            MouseArea {
                anchors.fill: parent
                onClicked: root.pickerOpen = false
            }

            // The sheet dims what is behind it, as a macOS sheet does.
            Rectangle {
                anchors.fill: parent
                color: Theme.scrim
            }

            Shadow {
                anchors.fill: pickerCard
                radius: Theme.radiusWindow
            }

            Rectangle {
                id: pickerCard

                property string filter: ""

                anchors.centerIn: parent
                width: Math.min(380, parent.width - 60)
                height: Math.min(420, parent.height - 60)
                radius: Theme.radiusWindow
                color: Theme.dark ? "#2A2A2C" : "#F7F7F9"
                border.width: 1
                border.color: Theme.materialBorder

                // Swallow clicks so they do not reach the dismiss layer.
                MouseArea {
                    anchors.fill: parent
                }

                StyledText {
                    id: pickerTitle
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    role: "headline"
                    text: "Add to Dock"
                }

                SearchField {
                    id: search
                    anchors.top: pickerTitle.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    focus: true
                    fieldSize: 14
                    showBackground: true
                    placeholder: "Search applications"
                    onTextChanged: pickerCard.filter = text
                    onCancelled: root.pickerOpen = false
                }

                ListView {
                    anchors.top: search.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    anchors.topMargin: 4
                    clip: true
                    spacing: 1

                    model: {
                        const f = pickerCard.filter.toLowerCase();
                        const out = [];
                        for (const e of Apps.allEntries) {
                            if (Apps.isPinned(e.id))
                                continue;
                            if (f !== "" && String(e.name ?? "").toLowerCase().indexOf(f) < 0)
                                continue;
                            out.push(e);
                        }
                        return out;
                    }

                    delegate: PanelItem {
                        required property var modelData

                        width: ListView.view.width
                        implicitHeight: 30
                        radius: Theme.radiusControl

                        IconImage {
                            id: pickIcon
                            anchors.verticalCenter: parent.verticalCenter
                            x: 6
                            implicitSize: 20
                            source: Apps.resolveIcon([modelData.icon, modelData.id])
                            asynchronous: true
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: pickIcon.right
                            anchors.leftMargin: 8
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            text: modelData.name
                            elide: Text.ElideRight
                        }

                        onClicked: {
                            Apps.setPinned(modelData.id, true);
                            root.pickerOpen = false;
                        }
                    }
                }
            }
        }
    }
}
