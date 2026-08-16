import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import "../../../common"
import ".."

// StatusNotifierItem tray icons. Left-click activates the item; right-click
// renders its DBusMenu into the shell's own MenuCard so tray menus match the
// rest of the design system instead of using Qt's native popup.
Row {
    id: root

    property var screen: null

    spacing: Theme.barItemSpacing
    visible: SystemTray.items.values.length > 0
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
        model: SystemTray.items

        delegate: PanelItem {
            id: trayItem
            required property var modelData

            implicitWidth: Theme.barGlyphSize + Theme.space2
            implicitHeight: Theme.barHeight - 6
            radius: 4
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            acceptedButtons: Qt.LeftButton

            readonly property string menuKey: "extra:tray-" + modelData.id
            readonly property bool menuOpen: ShellState.openMenu === menuKey

            color: (menuOpen || hovered) ? Theme.hover : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.barGlyphSize
                source: trayItem.modelData.icon
                asynchronous: true
            }

            onClicked: {
                // Items that only offer a menu have no useful activate().
                if (trayItem.modelData.onlyMenu && trayItem.modelData.hasMenu)
                    ShellState.openMenu = trayItem.menuOpen ? "" : trayItem.menuKey;
                else
                    trayItem.modelData.activate();
            }

            onRightClicked: {
                if (trayItem.modelData.hasMenu)
                    ShellState.openMenu = trayItem.menuOpen ? "" : trayItem.menuKey;
            }

            // QsMenuOpener keeps a live DBusMenu subscription open; its
            // `children` are QsMenuEntry objects which we map onto MenuCard's
            // plain-object model.
            QsMenuOpener {
                id: opener
                menu: trayItem.modelData.menu
            }

            readonly property var menuModel: {
                const out = [];
                if (!opener.children)
                    return out;
                for (const entry of opener.children.values) {
                    if (entry.isSeparator) {
                        out.push({
                            separator: true
                        });
                        continue;
                    }
                    out.push({
                        text: entry.text,
                        enabled: entry.enabled,
                        checked: entry.buttonType === QsMenuButtonType.None ? undefined : entry.checkState === Qt.Checked,
                        // `triggered` is a signal the client emits to activate
                        // the remote menu entry.
                        action: () => entry.triggered()
                    });
                }
                return out;
            }

            LazyLoader {
                active: trayItem.menuOpen

                PanelWindow {
                    id: popup
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

                    mask: Region {
                        item: catcher
                    }

                    BackgroundEffect.blurRegion: Region {
                        item: card
                        radius: Theme.radiusMenu
                    }

                    Item {
                        id: catcher
                        anchors.fill: parent
                        anchors.topMargin: Theme.barHeight
                        focus: true
                        Keys.onEscapePressed: ShellState.openMenu = ""

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: ShellState.openMenu = ""
                        }
                    }

                    MenuCard {
                        id: card
                        screenRef: popup.screen
                        items: trayItem.menuModel
                        // Right-aligned with the icon, clamped to the screen.
                        readonly property real anchorRight: trayItem.mapToItem(null, trayItem.width, 0).x
                        x: Math.round(Math.max(4, Math.min(anchorRight - width, popup.width - width - 4)))
                        y: Theme.barHeight + 2

                        onActivated: entry => {
                            ShellState.openMenu = "";
                            if (entry.action)
                                entry.action();
                        }
                    }
                }
            }
        }
    }
}
