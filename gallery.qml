// Design-system gallery. Not part of the shell — run it on its own to check
// the glyph set, the materials and the controls after changing common/:
//
//   qs -p ~/.config/quickshell/macos-shell/dev
//
// Esc or clicking the backdrop quits.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "common"

ShellRoot {
    PanelWindow {
        id: win
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        BackgroundEffect.blurRegion: Region {
            Region {
                item: card
                radius: Theme.radiusWindow
            }
            Region {
                item: menuSample
                radius: Theme.radiusMenu
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Qt.quit()

            MouseArea {
                anchors.fill: parent
                onClicked: Qt.quit()
            }

            readonly property var glyphNames: ["apple", "wifi", "wifi.slash", "bluetooth", "airdrop", "network", "antenna", "battery", "bolt", "power", "restart", "moon", "moon.zzz", "lock", "lock.open", "speaker", "speaker.slash", "headphones", "mic", "play.fill", "pause.fill", "forward.fill", "backward.fill", "sun.max", "sun.min", "display", "airplay", "keyboard", "magnifyingglass", "controlcenter", "square.grid.3x3", "rectangle.3.group", "bell", "bell.slash", "gear", "checkmark", "xmark", "xmark.circle.fill", "plus", "minus", "chevron.right", "chevron.left", "chevron.down", "chevron.up", "chevron.up.chevron.down", "ellipsis", "circle.fill", "circle", "info.circle", "exclamationmark.triangle", "arrow.up.left.and.arrow.down.right", "arrow.right", "arrow.down", "folder", "trash", "clock", "calendar", "person.crop.circle", "eye", "camera", "star.fill", "sidebar", "stage", "hand.raised"]

            Shadow {
                anchors.fill: card
                radius: Theme.radiusWindow
            }

            Vibrancy {
                id: card
                anchors.centerIn: parent
                width: 980
                height: 640
                material: "window"
                radius: Theme.radiusWindow
            }

            ColumnLayout {
                anchors.fill: card
                anchors.margins: 22
                spacing: 16

                StyledText {
                    role: "title2"
                    text: "macos-shell design system"
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: parent.parent.parent.glyphNames

                        delegate: Rectangle {
                            required property string modelData
                            width: 58
                            height: 54
                            radius: Theme.radiusTile
                            color: Theme.secondaryFill

                            Glyph {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8
                                name: parent.modelData
                                size: 22
                                color: Theme.label
                            }

                            StyledText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                width: parent.width - 4
                                horizontalAlignment: Text.AlignHCenter
                                role: "caption"
                                font.pixelSize: 7
                                color: Theme.tertiaryLabel
                                text: parent.modelData
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    ColumnLayout {
                        Layout.preferredWidth: 320
                        spacing: 12

                        MacSlider {
                            Layout.fillWidth: true
                            glyph: "sun.max"
                            value: 0.65
                        }
                        MacSlider {
                            Layout.fillWidth: true
                            glyph: "speaker"
                            glyphLevelCount: 3
                            value: 0.35
                        }
                        MacSlider {
                            Layout.fillWidth: true
                            style: "linear"
                            value: 0.5
                        }

                        RowLayout {
                            spacing: 12
                            MacSwitch {
                                checked: true
                            }
                            MacSwitch {}
                            MacButton {
                                text: "Cancel"
                            }
                            MacButton {
                                text: "Open"
                                variant: "default"
                            }
                            MacButton {
                                text: "Delete"
                                variant: "destructive"
                            }
                        }

                        SearchField {
                            Layout.fillWidth: true
                            fieldSize: 16
                            showBackground: true
                            placeholder: "Spotlight Search"
                        }
                    }

                    MenuCard {
                        id: menuSample
                        Layout.alignment: Qt.AlignTop
                        items: [
                            {
                                text: "About This Mac",
                                icon: "apple"
                            },
                            {
                                separator: true
                            },
                            {
                                text: "System Settings…",
                                icon: "gear",
                                shortcut: "⌘,"
                            },
                            {
                                text: "Dark Mode",
                                checked: true
                            },
                            {
                                text: "Recent Items",
                                submenu: []
                            },
                            {
                                separator: true
                            },
                            {
                                text: "Disabled Item",
                                enabled: false
                            },
                            {
                                text: "Shut Down…",
                                destructive: true
                            }
                        ]
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        StyledText {
                            role: "largeTitle"
                            text: "Large Title"
                        }
                        StyledText {
                            role: "title1"
                            text: "Title 1"
                        }
                        StyledText {
                            role: "title3"
                            text: "Title 3"
                        }
                        StyledText {
                            role: "headline"
                            text: "Headline"
                        }
                        StyledText {
                            role: "body"
                            text: "Body — the quick brown fox"
                        }
                        StyledText {
                            role: "callout"
                            color: Theme.secondaryLabel
                            text: "Callout secondary"
                        }
                        StyledText {
                            role: "footnote"
                            color: Theme.tertiaryLabel
                            text: "Footnote tertiary"
                        }

                        Row {
                            spacing: 6
                            Repeater {
                                model: [Theme.blue, Theme.green, Theme.yellow, Theme.orange, Theme.red, Theme.pink, Theme.purple, Theme.indigo, Theme.teal, Theme.mint, Theme.gray]
                                Rectangle {
                                    required property color modelData
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
