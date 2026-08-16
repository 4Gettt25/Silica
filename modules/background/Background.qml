import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../common"

// The desktop picture, one layer-shell window per screen.
//
// Any change of `Wallpaper.current` — switching appearance, or picking a new
// picture in the desktop menu — crossfades between two Image layers rather
// than swapping the source underneath the viewer. A gradient in the macOS
// palette stays behind them so a missing or still-loading file never shows a
// black desktop.
Scope {
    id: root

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bgWindow

            required property var modelData // a ShellScreen
            screen: modelData

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            // Bottom-most layer. NOTE: PanelWindow.aboveWindows is deliberately
            // NOT set — on Wayland it writes the same property as
            // WlrLayershell.layer and the two would fight.
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "macos-shell-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            focusable: false
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            // Which of the two Image layers is currently on top.
            property bool showA: true
            property url currentSource: Wallpaper.current

            onCurrentSourceChanged: {
                // Load the new picture into the hidden layer, then crossfade.
                if (showA)
                    imageB.source = currentSource;
                else
                    imageA.source = currentSource;
            }

            Component.onCompleted: imageA.source = currentSource

            Item {
                anchors.fill: parent

                // Fallback gradient, always underneath: low-saturation macOS
                // sky tones, crossfaded with the appearance.
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#A7C7E7"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#E8DFF5"
                        }
                    }
                    opacity: Theme.dark ? 0 : 1
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durWallpaper
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: "#0B1D3A"
                        }
                        GradientStop {
                            position: 1.0
                            color: "#1B0F2E"
                        }
                    }
                    opacity: Theme.dark ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durWallpaper
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                Image {
                    id: imageA
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    // Only fade in once the file actually decoded, so a broken
                    // path leaves the gradient visible instead of a black hole.
                    opacity: (bgWindow.showA && status === Image.Ready) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durWallpaper
                            easing.type: Easing.InOutQuad
                        }
                    }
                    onStatusChanged: if (status === Image.Ready && source == bgWindow.currentSource)
                        bgWindow.showA = true
                }

                Image {
                    id: imageB
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    opacity: (!bgWindow.showA && status === Image.Ready) ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.durWallpaper
                            easing.type: Easing.InOutQuad
                        }
                    }
                    onStatusChanged: if (status === Image.Ready && source == bgWindow.currentSource)
                        bgWindow.showA = false
                }
            }
        }
    }
}
