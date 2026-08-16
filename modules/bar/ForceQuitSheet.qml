import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../common"

// "Force Quit Applications": the small window listing open windows, with the
// selected one closed through the compositor abstraction.
Scope {
    id: root

    property bool open: false
    property var screen: null

    property int selectedIndex: 0

    readonly property var windowList: Compositor.windows

    onOpenChanged: if (open) selectedIndex = 0

    function prettify(win) {
        if (!win)
            return "";
        let s = String(win.appId || "");
        if (s === "")
            return win.title || "Untitled";
        if (s.indexOf(".") >= 0)
            s = s.split(".").pop();
        s = s.replace(/[-_]+/g, " ").trim();
        return s.charAt(0).toUpperCase() + s.slice(1);
    }

    function quitSelected() {
        const w = windowList[selectedIndex];
        if (w)
            Compositor.closeWindow(w.id);
        // The list refreshes from the compositor event stream; keep the sheet
        // open so several apps can be quit in a row, like macOS.
        selectedIndex = 0;
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win
            screen: root.screen

            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            BackgroundEffect.blurRegion: Region {
                item: sheet
                radius: Theme.radiusWindow
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.open = false
                Keys.onUpPressed: root.selectedIndex = Math.max(0, root.selectedIndex - 1)
                Keys.onDownPressed: root.selectedIndex = Math.min(root.windowList.length - 1, root.selectedIndex + 1)
                Keys.onReturnPressed: root.quitSelected()

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Popover {
                id: sheet
                screenRef: win.screen
                material: "sheet"
                radius: Theme.radiusWindow
                origin: "center"
                anchors.centerIn: parent
                width: 320
                height: column.implicitHeight + Theme.space4 * 2

                ColumnLayout {
                    id: column
                    x: Theme.space4
                    y: Theme.space4
                    width: sheet.width - Theme.space4 * 2
                    spacing: Theme.space3

                    StyledText {
                        Layout.fillWidth: true
                        role: "headline"
                        horizontalAlignment: Text.AlignHCenter
                        text: "Force Quit Applications"
                    }

                    StyledText {
                        Layout.fillWidth: true
                        role: "footnote"
                        color: Theme.secondaryLabel
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: root.windowList.length === 0 ? "No applications are open." : "If an app doesn't respond, select it and click Force Quit."
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(200, Math.max(28, listColumn.implicitHeight + 8))
                        radius: Theme.radiusControl
                        color: Theme.tertiaryFill
                        border.width: 1
                        border.color: Theme.separator
                        clip: true

                        Flickable {
                            anchors.fill: parent
                            anchors.margins: 4
                            contentHeight: listColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: listColumn
                                width: parent.width

                                Repeater {
                                    model: root.windowList

                                    delegate: PanelItem {
                                        required property var modelData
                                        required property int index

                                        width: listColumn.width
                                        implicitHeight: 24
                                        radius: 4
                                        selected: root.selectedIndex === index

                                        StyledText {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Theme.space2
                                            width: parent.width - Theme.space2 * 2
                                            text: root.prettify(parent.modelData)
                                            color: parent.selected ? Theme.onSelection : Theme.label
                                            elide: Text.ElideRight
                                        }

                                        onClicked: root.selectedIndex = index
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2

                        Item {
                            Layout.fillWidth: true
                        }

                        MacButton {
                            text: "Cancel"
                            onClicked: root.open = false
                        }

                        MacButton {
                            text: "Force Quit"
                            variant: "destructive"
                            interactive: root.windowList.length > 0
                            onClicked: root.quitSelected()
                        }
                    }
                }
            }
        }
    }
}
