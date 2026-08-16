import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../common"

// System Settings — an ordinary application window (not a layer surface), so
// it behaves like a real macOS app: draggable, resizable, minimisable, and
// listed by the compositor.
//
// Layout follows macOS Ventura and later: a vibrant sidebar of panes on the
// left with rounded, colour-coded symbols, and a scrollable content column of
// grouped rows on the right.
Scope {
    id: root

    // Everything the shell can be configured with lives in Settings; this
    // window is just a face for it.
    readonly property var panes: [
        {
            id: "appearance",
            title: "Appearance",
            glyph: "circle.fill",
            tint: Theme.blue
        },
        {
            id: "desktop",
            title: "Desktop & Dock",
            glyph: "square.grid.3x3",
            tint: Theme.indigo
        },
        {
            id: "menubar",
            title: "Menu Bar & Clock",
            glyph: "clock",
            tint: Theme.gray
        },
        {
            id: "shortcuts",
            title: "Shortcuts",
            glyph: "keyboard",
            tint: Theme.orange
        },
        {
            id: "notifications",
            title: "Notifications",
            glyph: "bell",
            tint: Theme.red
        },
        {
            id: "about",
            title: "About",
            glyph: "info.circle",
            tint: Theme.teal
        }
    ]

    // ---- system facts for the About pane (read once, asynchronously) ----
    property string cpuModel: ""
    property string memTotal: ""
    property string compositorVersion: ""

    Process {
        running: true
        command: ["sh", "-c", "printf '%s\\n' \"$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -1)\" \"$(awk '/MemTotal/ {printf \"%.0f GB\", $2/1048576}' /proc/meminfo)\" \"$(niri msg version 2>/dev/null | sed -n 's/^Compositor version:[[:space:]]*//p')\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.cpuModel = (lines[0] || "").trim();
                root.memTotal = (lines[1] || "").trim();
                root.compositorVersion = (lines[2] || "").trim();
            }
        }
    }

    // ---- available desktop pictures, for the Desktop pane ----
    property var wallpaperFiles: []

    Process {
        id: wallpaperScan
        // Bundled desktop pictures first, then the user's own — and never the
        // screenshot folder, which is not a wallpaper library.
        command: ["sh", "-c", "{ find \"$HOME/.config/quickshell/macos-shell/assets/wallpapers\" -maxdepth 1 -type f 2>/dev/null; find \"$HOME/Pictures/Wallpapers\" -maxdepth 2 -type f 2>/dev/null; find \"$HOME/Pictures\" -maxdepth 1 -type f 2>/dev/null; } | grep -iE '\\.(jpg|jpeg|png)$' | head -40"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpaperFiles = text.split("\n").filter(s => s.trim().length > 0)
        }
    }

    LazyLoader {
        active: ShellState.settingsOpen

        FloatingWindow {
            id: win
            title: "System Settings"
            implicitWidth: 780
            implicitHeight: 560
            minimumSize.width: 620
            minimumSize.height: 420
            color: "transparent"

            Component.onCompleted: wallpaperScan.running = true

            // The compositor blurs whatever is behind the window, exactly as
            // it does for the shell's own panels.
            BackgroundEffect.blurRegion: Region {
                item: windowRoot
            }

            Item {
                id: windowRoot
                anchors.fill: parent

                // ---------------- sidebar ----------------
                Vibrancy {
                    id: sidebar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 210
                    material: "sidebar"
                    radius: 0
                    showBorder: false
                    showHighlight: false
                }

                // Dragging anywhere in the sidebar's header area moves the
                // window, like a macOS unified titlebar.
                MouseArea {
                    id: dragArea
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 44
                    hoverEnabled: true
                    onPressed: win.startSystemMove()
                    onDoubleClicked: win.maximized = !win.maximized
                }

                TrafficLights {
                    x: 14
                    y: 14
                    hoveredExternally: dragArea.containsMouse
                    onCloseClicked: ShellState.settingsOpen = false
                    onMinimizeClicked: win.minimized = true
                    onZoomClicked: win.maximized = !win.maximized
                }

                Column {
                    anchors.left: sidebar.left
                    anchors.right: sidebar.right
                    anchors.top: sidebar.top
                    anchors.topMargin: 48
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 1

                    Repeater {
                        model: root.panes

                        delegate: Rectangle {
                            required property var modelData

                            width: parent.width
                            height: 30
                            radius: Theme.radiusControl
                            color: ShellState.settingsPane === modelData.id ? Theme.accent : (paneMouse.containsMouse ? Theme.hover : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.durInstant
                                }
                            }

                            Rectangle {
                                id: paneIcon
                                anchors.verticalCenter: parent.verticalCenter
                                x: 6
                                width: 20
                                height: 20
                                radius: 5
                                color: modelData.tint

                                Glyph {
                                    anchors.centerIn: parent
                                    size: 13
                                    name: modelData.glyph
                                    color: "#FFFFFF"
                                }
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: paneIcon.right
                                anchors.leftMargin: 8
                                text: modelData.title
                                color: ShellState.settingsPane === modelData.id ? Theme.onAccent : Theme.label
                            }

                            MouseArea {
                                id: paneMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: ShellState.settingsPane = modelData.id
                            }
                        }
                    }
                }

                // ---------------- content ----------------
                Vibrancy {
                    id: contentBg
                    anchors.left: sidebar.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    material: "window"
                    radius: 0
                    showBorder: false
                    showHighlight: false
                }

                Rectangle {
                    // Hairline between sidebar and content.
                    anchors.left: sidebar.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.separator
                }

                StyledText {
                    id: paneTitle
                    anchors.left: contentBg.left
                    anchors.leftMargin: 22
                    y: 15
                    role: "title3"
                    text: {
                        const p = root.panes.find(x => x.id === ShellState.settingsPane);
                        return p ? p.title : "";
                    }
                }

                Flickable {
                    id: scroller
                    anchors.left: contentBg.left
                    anchors.right: contentBg.right
                    anchors.top: paneTitle.bottom
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 12
                    clip: true
                    contentHeight: paneLoader.item ? paneLoader.item.implicitHeight + 32 : 0
                    boundsBehavior: Flickable.StopAtBounds

                    Loader {
                        id: paneLoader
                        x: 22
                        width: scroller.width - 44
                        sourceComponent: {
                            switch (ShellState.settingsPane) {
                            case "desktop":
                                return desktopPane;
                            case "menubar":
                                return menuBarPane;
                            case "shortcuts":
                                return shortcutsPane;
                            case "notifications":
                                return notificationsPane;
                            case "about":
                                return aboutPane;
                            default:
                                return appearancePane;
                            }
                        }
                    }
                }
            }

            // ==================== panes ====================

            Component {
                id: appearancePane

                ColumnLayout {
                    spacing: 18

                    SettingsGroup {
                        SettingsRow {
                            label: "Appearance"
                            detail: "Choose a light or dark appearance for the shell."

                            MacSegmented {
                                width: 160
                                options: ["Light", "Dark"]
                                currentIndex: Theme.dark ? 1 : 0
                                onSelected: i => Settings.appearance = (i === 1 ? "dark" : "light")
                            }
                        }

                        SettingsRow {
                            label: "Accent colour"

                            Row {
                                spacing: 8

                                Repeater {
                                    model: ["blue", "purple", "pink", "red", "orange", "yellow", "green", "graphite"]

                                    delegate: Rectangle {
                                        required property string modelData

                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: {
                                            switch (modelData) {
                                            case "purple":
                                                return Theme.purple;
                                            case "pink":
                                                return Theme.pink;
                                            case "red":
                                                return Theme.red;
                                            case "orange":
                                                return Theme.orange;
                                            case "yellow":
                                                return Theme.yellow;
                                            case "green":
                                                return Theme.green;
                                            case "graphite":
                                                return Theme.gray;
                                            default:
                                                return Theme.blue;
                                            }
                                        }
                                        border.width: Settings.accent === modelData ? 2 : 0
                                        border.color: Theme.label

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: Settings.accent = modelData
                                        }
                                    }
                                }
                            }
                        }

                        SettingsRow {
                            label: "Symbols"
                            detail: SymbolIcons.available ? "Take the shell's symbols from the installed icon theme, or draw them." : "No icon theme with symbolic icons was found — run scripts/install-icons.sh."
                            showSeparator: false

                            MacSegmented {
                                width: 180
                                options: ["Icon theme", "Drawn"]
                                currentIndex: Settings.symbolStyle === "drawn" ? 1 : 0
                                onSelected: i => Settings.symbolStyle = (i === 1 ? "drawn" : "theme")
                            }
                        }
                    }

                    SettingsGroup {
                        title: "Accessibility"

                        SettingsRow {
                            label: "Reduce transparency"
                            detail: "Replace the blurred materials with opaque backgrounds."

                            MacSwitch {
                                checked: Settings.reduceTransparency
                                onToggled: v => Settings.reduceTransparency = v
                            }
                        }

                        SettingsRow {
                            label: "Reduce motion"
                            detail: "Skip the shell's animations."
                            showSeparator: false

                            MacSwitch {
                                checked: Settings.reduceMotion
                                onToggled: v => Settings.reduceMotion = v
                            }
                        }
                    }
                }
            }

            Component {
                id: desktopPane

                ColumnLayout {
                    spacing: 18

                    SettingsGroup {
                        title: "Dock"

                        SettingsRow {
                            label: "Size"

                            MacSlider {
                                width: 180
                                style: "linear"
                                value: (Settings.dockSize - 32) / 48
                                onMoved: v => Settings.dockSize = Math.round(32 + v * 48)
                            }
                        }

                        SettingsRow {
                            label: "Magnification"

                            Row {
                                spacing: 12

                                MacSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: Settings.dockMagnification
                                    onToggled: v => Settings.dockMagnification = v
                                }

                                MacSlider {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 140
                                    style: "linear"
                                    interactive: Settings.dockMagnification
                                    value: (Settings.dockMagnificationSize - 48) / 80
                                    onMoved: v => Settings.dockMagnificationSize = Math.round(48 + v * 80)
                                }
                            }
                        }

                        SettingsRow {
                            label: "Position on screen"

                            MacSegmented {
                                width: 200
                                options: ["Left", "Bottom", "Right"]
                                currentIndex: Settings.dockPosition === "left" ? 0 : (Settings.dockPosition === "right" ? 2 : 1)
                                onSelected: i => Settings.dockPosition = ["left", "bottom", "right"][i]
                            }
                        }

                        SettingsRow {
                            label: "Automatically hide and show the Dock"

                            MacSwitch {
                                checked: Settings.dockAutoHide
                                onToggled: v => Settings.dockAutoHide = v
                            }
                        }

                        SettingsRow {
                            label: "Show recent applications in Dock"
                            showSeparator: false

                            MacSwitch {
                                checked: Settings.dockShowRecents
                                onToggled: v => Settings.dockShowRecents = v
                            }
                        }
                    }

                    DockAppsEditor {
                        overlay: windowRoot
                    }

                    SettingsGroup {
                        title: "Hot Corners"

                        Repeater {
                            model: [
                                {
                                    label: "Top left",
                                    key: "hotCornerTopLeft"
                                },
                                {
                                    label: "Top right",
                                    key: "hotCornerTopRight"
                                },
                                {
                                    label: "Bottom left",
                                    key: "hotCornerBottomLeft"
                                },
                                {
                                    label: "Bottom right",
                                    key: "hotCornerBottomRight"
                                }
                            ]

                            delegate: SettingsRow {
                                required property var modelData
                                required property int index

                                label: modelData.label
                                showSeparator: index < 3

                                MacPopupButton {
                                    // Values are the action names ShellState.runAction() understands.
                                    readonly property var actions: ["", "missioncontrol", "launchpad", "spotlight", "notificationcenter", "controlcenter", "lockscreen", "sleep"]
                                    options: ["–", "Mission Control", "Launchpad", "Spotlight", "Notification Centre", "Control Centre", "Lock Screen", "Sleep"]
                                    overlay: windowRoot
                                    currentIndex: Math.max(0, actions.indexOf(Settings[modelData.key]))
                                    onSelected: i => Settings[modelData.key] = actions[i]
                                }
                            }
                        }
                    }

                    SettingsGroup {
                        title: "Desktop Picture"

                        SettingsRow {
                            label: Theme.dark ? "Dark appearance" : "Light appearance"
                            detail: "Click a picture to use it for the current appearance."
                            showSeparator: false
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            Layout.margins: 10
                            contentWidth: wallpaperRow.width
                            flickableDirection: Flickable.HorizontalFlick
                            clip: true

                            Row {
                                id: wallpaperRow
                                spacing: 8

                                Repeater {
                                    model: root.wallpaperFiles

                                    delegate: Rectangle {
                                        required property string modelData

                                        readonly property string asUrl: "file://" + modelData
                                        readonly property bool active: (Theme.dark ? Wallpaper.dark : Wallpaper.light) == asUrl

                                        width: 96
                                        height: 60
                                        radius: 6
                                        clip: true
                                        color: Theme.fill
                                        border.width: active ? 2 : 0
                                        border.color: Theme.accent

                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: parent.active ? 2 : 0
                                            source: parent.asUrl
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 200
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (Theme.dark)
                                                    Settings.wallpaperDark = parent.modelData;
                                                else
                                                    Settings.wallpaperLight = parent.modelData;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: shortcutsPane

                ShortcutsPane {}
            }

            Component {
                id: menuBarPane

                ColumnLayout {
                    spacing: 18

                    SettingsGroup {
                        title: "Menu Bar"

                        SettingsRow {
                            label: "Size"
                            detail: "How tall the menu bar is, and how big its icons and text are."

                            MacSegmented {
                                width: 200
                                options: ["Small", "Medium", "Large"]
                                currentIndex: Settings.menuBarSize === "small" ? 0 : (Settings.menuBarSize === "large" ? 2 : 1)
                                onSelected: i => Settings.menuBarSize = ["small", "medium", "large"][i]
                            }
                        }

                        SettingsRow {
                            label: "Automatically hide and show the menu bar"

                            MacSwitch {
                                checked: Settings.menuBarAutoHide
                                onToggled: v => Settings.menuBarAutoHide = v
                            }
                        }

                        SettingsRow {
                            label: "Menu bar logo"
                            detail: "The leftmost item in the menu bar — the one that opens the shell menu."

                            MacPopupButton {
                                readonly property var values: ["apple", "distro", "custom"]
                                options: ["Apple", OsInfo.name === "" ? "This system" : OsInfo.name, "Custom picture…"]
                                overlay: windowRoot
                                currentIndex: Math.max(0, values.indexOf(Settings.menuBarLogo))
                                onSelected: i => Settings.menuBarLogo = values[i]
                            }
                        }

                        SettingsRow {
                            label: "Custom picture"
                            detail: Settings.menuBarLogoPath === "" ? "Paste the path of a PNG or SVG file." : Settings.menuBarLogoPath
                            showSeparator: false

                            Row {
                                spacing: 8

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 190
                                    height: 22
                                    radius: Theme.radiusControl
                                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : "#FFFFFF"
                                    border.width: 1
                                    border.color: Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)

                                    TextInput {
                                        id: logoPathField
                                        anchors.fill: parent
                                        anchors.leftMargin: 7
                                        anchors.rightMargin: 7
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        color: Theme.label
                                        selectByMouse: true
                                        selectionColor: Theme.accent
                                        text: Settings.menuBarLogoPath
                                        onEditingFinished: {
                                            Settings.menuBarLogoPath = text.trim();
                                            if (text.trim() !== "")
                                                Settings.menuBarLogo = "custom";
                                        }
                                    }
                                }

                                MacButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Clear"
                                    onClicked: {
                                        logoPathField.text = "";
                                        Settings.menuBarLogoPath = "";
                                        if (Settings.menuBarLogo === "custom")
                                            Settings.menuBarLogo = "apple";
                                    }
                                }
                            }
                        }
                    }

                    SettingsGroup {
                        title: "Clock"

                        SettingsRow {
                            label: "Use a 24-hour clock"

                            MacSwitch {
                                checked: Settings.clock24h
                                onToggled: v => Settings.clock24h = v
                            }
                        }

                        SettingsRow {
                            label: "Display the time with seconds"

                            MacSwitch {
                                checked: Settings.clockShowSeconds
                                onToggled: v => Settings.clockShowSeconds = v
                            }
                        }

                        SettingsRow {
                            label: "Show the date"
                            detail: Time.clock
                            showSeparator: false

                            MacSwitch {
                                checked: Settings.clockShowDate
                                onToggled: v => Settings.clockShowDate = v
                            }
                        }
                    }
                }
            }

            Component {
                id: notificationsPane

                ColumnLayout {
                    spacing: 18

                    SettingsGroup {
                        SettingsRow {
                            label: "Do Not Disturb"
                            detail: "New notifications go straight to Notification Centre."

                            MacSwitch {
                                checked: ShellState.doNotDisturb
                                onToggled: v => ShellState.doNotDisturb = v
                            }
                        }

                        SettingsRow {
                            label: "Play sound for notifications"
                            showSeparator: false

                            MacSwitch {
                                checked: Settings.notificationSounds
                                onToggled: v => Settings.notificationSounds = v
                            }
                        }
                    }
                }
            }

            Component {
                id: aboutPane

                ColumnLayout {
                    spacing: 18

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 108

                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            visible: OsInfo.logoSource !== ""
                            source: OsInfo.logoSource
                            width: 64
                            height: 64
                            sourceSize.width: 128
                            sourceSize.height: 128
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                        }

                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            visible: OsInfo.logoSource === ""
                            size: 64
                            name: "apple"
                            color: Theme.label
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            role: "title2"
                            text: OsInfo.prettyName === "" ? "macos-shell" : OsInfo.prettyName
                        }
                    }

                    SettingsGroup {
                        SettingsRow {
                            label: "Shell"

                            StyledText {
                                text: "macos-shell"
                                color: Theme.secondaryLabel
                            }
                        }

                        SettingsRow {
                            label: "Kernel"

                            StyledText {
                                text: OsInfo.kernel
                                color: Theme.secondaryLabel
                            }
                        }

                        SettingsRow {
                            label: "Compositor"

                            StyledText {
                                text: (Compositor.compositor === "niri" ? "niri " : Compositor.compositor + " ") + root.compositorVersion
                                color: Theme.secondaryLabel
                            }
                        }

                        SettingsRow {
                            label: "Processor"

                            StyledText {
                                text: root.cpuModel
                                color: Theme.secondaryLabel
                            }
                        }

                        SettingsRow {
                            label: "Memory"

                            StyledText {
                                text: root.memTotal
                                color: Theme.secondaryLabel
                            }
                        }

                        SettingsRow {
                            label: "Displays"
                            showSeparator: false

                            StyledText {
                                text: Quickshell.screens.length + (Quickshell.screens.length === 1 ? " display" : " displays")
                                color: Theme.secondaryLabel
                            }
                        }
                    }
                }
            }
        }
    }
}
