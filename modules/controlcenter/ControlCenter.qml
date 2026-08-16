import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../../common"

// macOS Sonoma Control Center.
//
// A popover under the right side of the menu bar, built as a stack of rounded
// translucent GROUPS (CcGroup) holding tiles (CcTile) and sliders. Clicking a
// group's label pushes a detail page (CcDetail) with a slide+fade transition,
// exactly like macOS.
//
// Backends, in order of preference (DESIGN.md: service > subprocess):
//   Wi-Fi      Quickshell.Networking      (NetworkManager)
//   Bluetooth  Quickshell.Bluetooth       (BlueZ)
//   Sound      Quickshell.Services.Pipewire
//   Media      Quickshell.Services.Mpris  (see NowPlaying.qml)
//   Brightness brightnessctl              (the only subprocess; async + polled)
//
// Anything without a backend on this machine hides its group or dims its tile;
// a broken control is never shown.
Scope {
    id: root

    // ------------------------------------------------------------ page stack
    // "" = the root page; otherwise the id of the pushed detail page.
    property string page: ""
    // The last detail that was shown. Kept after `page` goes back to "" so the
    // outgoing page still has content to render while it slides away.
    property string detailPage: ""

    onPageChanged: if (page !== "") detailPage = page

    // ------------------------------------------------------------- lifecycle
    // The popover is created on demand, but is kept alive for the length of the
    // closing animation so it can play (LazyLoader would otherwise destroy the
    // window the instant the flag flips).
    property bool ccOpen: ShellState.controlCenterOpen
    property bool windowAlive: false

    onCcOpenChanged: {
        if (ccOpen) {
            closeTimer.stop();
            root.page = "";
            root.pollState();
            windowAlive = true;
        } else {
            closeTimer.restart();
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.durFast + 60
        onTriggered: root.windowAlive = false
    }

    // --------------------------------------------------------------- Wi-Fi
    // Networking.devices is an ObjectModel, so the live list is `.values`.
    readonly property var wifiDevice: {
        if (!Networking.devices)
            return null;
        const devices = Networking.devices.values;
        for (const d of devices)
            if (d.type === DeviceType.Wifi)
                return d;
        return null;
    }
    readonly property bool wifiSupported: Networking.backend !== NetworkBackendType.None && root.wifiDevice !== null
    readonly property bool wifiOn: root.wifiSupported && Networking.wifiEnabled
    readonly property var wifiNetworks: {
        if (!root.wifiDevice || !root.wifiDevice.networks)
            return [];
        // Strongest first, which is the order macOS lists them in.
        return root.wifiDevice.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength);
    }
    readonly property var wifiActive: {
        for (const n of root.wifiNetworks)
            if (n.connected)
                return n;
        return null;
    }
    readonly property string wifiStatus: {
        if (!root.wifiSupported)
            return "Not Available";
        if (!root.wifiOn)
            return "Off";
        return root.wifiActive ? root.wifiActive.name : "Not Connected";
    }

    function toggleWifi() {
        if (root.wifiSupported)
            Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ------------------------------------------------------------- Ethernet
    // A machine with no wireless card would otherwise show nothing but a dead
    // "Wi-Fi — Not Available" tile, so the cable takes that slot instead.
    readonly property var wiredDevice: {
        if (!Networking.devices)
            return null;
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired && d.connected)
                return d;
        return null;
    }
    readonly property bool wiredConnected: root.wiredDevice !== null
    readonly property string wiredStatus: {
        if (!root.wiredConnected)
            return "Not Connected";
        const net = root.wiredDevice.network;
        const name = net ? String(net.name ?? "") : "";
        return name.length > 0 ? name : String(root.wiredDevice.name ?? "Connected");
    }
    // True when the tile should be about the cable rather than the radio.
    readonly property bool showWired: !root.wifiSupported && root.wiredConnected

    // ----------------------------------------------------------- Bluetooth
    readonly property BluetoothAdapter btAdapter: Bluetooth.defaultAdapter
    readonly property bool btSupported: root.btAdapter !== null
    readonly property bool btOn: root.btSupported && root.btAdapter.enabled
    readonly property var btDevices: (root.btSupported && root.btAdapter.devices) ? root.btAdapter.devices.values : []
    readonly property string btStatus: {
        if (!root.btSupported)
            return "Not Available";
        if (!root.btOn)
            return "Off";
        for (const d of root.btDevices)
            if (d.connected)
                return d.name;
        return "On";
    }

    function toggleBluetooth() {
        if (root.btSupported)
            root.btAdapter.enabled = !root.btAdapter.enabled;
    }

    // ---------------------------------------------------------------- Focus
    readonly property bool focusOn: ShellState.doNotDisturb
    property string focusMode: "dnd" // which mode the Focus detail has selected
    readonly property string focusStatus: {
        if (!root.focusOn)
            return "Off";
        switch (root.focusMode) {
        case "personal":
            return "Personal";
        case "work":
            return "Work";
        default:
            return "Do Not Disturb";
        }
    }

    property bool nightShiftOn: false

    // ----------------------------------------------------------- brightness
    // brightnessctl is the one subprocess here. `-m` is its machine-readable
    // CSV (device,class,current,percent,max) and `-c backlight` restricts it to
    // real display backlights — without it, it happily reports keyboard LEDs.
    property bool brightnessAvailable: false
    property real brightness: 0.5

    Process {
        id: brightPoll
        command: ["sh", "-c", "brightnessctl -m -c backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0] || "";
                const fields = line.split(",");
                const pct = fields.length >= 5 ? parseFloat(fields[3]) : NaN;
                if (isNaN(pct)) {
                    root.brightnessAvailable = false;
                    return;
                }
                root.brightnessAvailable = true;
                root.brightness = Math.max(0, Math.min(1, pct / 100));
            }
        }
    }

    Process {
        id: brightSet
    }

    function setBrightness(v) {
        if (!root.brightnessAvailable)
            return;
        const clamped = Math.max(0, Math.min(1, v));
        brightSet.command = ["brightnessctl", "-q", "-c", "backlight", "set", Math.round(clamped * 100) + "%"];
        brightSet.running = true;
        root.brightness = clamped; // optimistic; the next poll confirms
    }

    // ---------------------------------------------------------------- sound
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool volumeAvailable: root.sink !== null && !!root.sink.audio
    readonly property real volume: root.volumeAvailable ? Math.max(0, Math.min(1, root.sink.audio.volume)) : 0
    readonly property bool muted: root.volumeAvailable && root.sink.audio.muted

    // Pipewire node properties are only valid while the node is bound.
    PwObjectTracker {
        objects: {
            const objs = [];
            if (root.sink)
                objs.push(root.sink);
            if (root.source)
                objs.push(root.source);
            return objs;
        }
    }

    readonly property var sinks: {
        if (!Pipewire.nodes)
            return [];
        return Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio);
    }
    readonly property var sources: {
        if (!Pipewire.nodes)
            return [];
        return Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio);
    }

    function nodeLabel(n) {
        if (!n)
            return "";
        return n.description || n.nickname || n.name;
    }

    function setVolume(v) {
        if (root.volumeAvailable)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // -------------------------------------------------------------- polling
    // Everything that cannot push (brightnessctl) is polled asynchronously,
    // every 3s while the popover is open plus once whenever it opens. One probe
    // at startup so a group's visibility is settled before the first open.
    function pollState() {
        if (!brightPoll.running)
            brightPoll.running = true;
    }

    Component.onCompleted: root.pollState()

    Timer {
        interval: 3000
        repeat: true
        running: root.ccOpen
        onTriggered: root.pollState()
    }

    // ------------------------------------------------------------- surface
    LazyLoader {
        active: root.windowAlive

        PanelWindow {
            id: win

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            // Floats over everything, reserves no space and never takes the
            // keyboard: click-away is the only dismissal, so focus would only
            // blank the menu bar's app name (see DESIGN.md > Keyboard focus).
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "macos-shell-controlcenter"
            color: "transparent"

            // The compositor blurs what is behind the popover; the region has to
            // match the card's geometry AND its corner radius.
            BackgroundEffect.blurRegion: Region {
                item: card
                radius: card.radius
            }

            // Set after construction so the popover plays its scale+fade in
            // rather than appearing already open.
            property bool entered: false
            Component.onCompleted: win.entered = true

            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.closeAll()
            }

            Popover {
                id: card

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + 6
                anchors.rightMargin: 8

                screenRef: win.screen
                material: "popover"
                radius: Theme.radiusPopover
                origin: "top"
                shown: win.entered && ShellState.controlCenterOpen
                contentPadding: Theme.space3
                width: 340
                // The card follows the page stack, which is what animates, so
                // the popover grows/shrinks smoothly on a push or a pop.
                height: pages.height + card.contentPadding * 2

                // Both pages live here at once; the container clips so the one
                // sliding out is cut off at the card edge.
                Item {
                    id: pages
                    width: parent.width
                    height: root.page === "" ? mainCol.implicitHeight : (detailLoader.item ? detailLoader.item.implicitHeight : 0)
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: Theme.durFast
                            easing.type: Theme.easingType
                            easing.bezierCurve: Theme.easeStandard
                        }
                    }

                    // ------------------------------------------- root page
                    ColumnLayout {
                        id: mainCol
                        width: parent.width
                        spacing: Theme.space2

                        x: root.page === "" ? 0 : -pages.width * 0.28
                        opacity: root.page === "" ? 1 : 0
                        visible: opacity > 0.01

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.durFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easeStandard
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easeStandard
                            }
                        }

                        // ---- connectivity ----
                        CcGroup {
                            Layout.fillWidth: true
                            spacing: 0

                            CcTile {
                                Layout.fillWidth: true
                                glyph: root.showWired ? "ethernet" : (root.wifiOn ? "wifi" : "wifi.slash")
                                title: root.showWired ? "Ethernet" : "Wi-Fi"
                                subtitle: root.showWired ? root.wiredStatus : root.wifiStatus
                                active: root.showWired ? true : root.wifiOn
                                available: root.showWired ? true : root.wifiSupported
                                hasDetail: !root.showWired
                                onToggled: root.toggleWifi()
                                onDetailRequested: root.page = "wifi"
                            }

                            CcTile {
                                Layout.fillWidth: true
                                glyph: "bluetooth"
                                title: "Bluetooth"
                                subtitle: root.btStatus
                                active: root.btOn
                                available: root.btSupported
                                hasDetail: true
                                onToggled: root.toggleBluetooth()
                                onDetailRequested: root.page = "bluetooth"
                            }
                        }

                        // ---- Focus ----
                        CcGroup {
                            Layout.fillWidth: true

                            CcTile {
                                Layout.fillWidth: true
                                glyph: "moon"
                                title: root.focusOn ? root.focusStatus : "Focus"
                                active: root.focusOn
                                hasDetail: true
                                onToggled: ShellState.doNotDisturb = !ShellState.doNotDisturb
                                onDetailRequested: root.page = "focus"
                            }
                        }

                        // ---- Screen Mirroring ----
                        CcGroup {
                            Layout.fillWidth: true

                            CcTile {
                                Layout.fillWidth: true
                                glyph: "display"
                                title: "Screen Mirroring"
                                onToggled: {}
                            }
                        }

                        // ---- Display ----
                        CcGroup {
                            Layout.fillWidth: true
                            visible: root.brightnessAvailable
                            padding: Theme.space3
                            spacing: Theme.space2

                            CcGroupLabel {
                                Layout.fillWidth: true
                                text: "Display"
                                onClicked: root.page = "display"
                            }

                            MacSlider {
                                Layout.fillWidth: true
                                style: "capsule"
                                glyph: "sun.max"
                                minimum: 0.05
                                value: root.brightness
                                // brightnessctl spawns a process, so only write
                                // on release; the capsule follows the drag live.
                                onCommitted: v => root.setBrightness(v)
                            }
                        }

                        // ---- Sound ----
                        CcGroup {
                            Layout.fillWidth: true
                            visible: root.volumeAvailable
                            padding: Theme.space3
                            spacing: Theme.space2

                            CcGroupLabel {
                                Layout.fillWidth: true
                                text: "Sound"
                                onClicked: root.page = "sound"
                            }

                            MacSlider {
                                Layout.fillWidth: true
                                style: "capsule"
                                glyph: "speaker"
                                glyphLevelCount: 3
                                value: root.muted ? 0 : root.volume
                                // Pipewire writes are cheap: follow the drag.
                                onMoved: v => root.setVolume(v)
                                onCommitted: v => root.setVolume(v)
                            }
                        }

                        // ---- Now Playing ----
                        NowPlaying {
                            Layout.fillWidth: true
                        }
                    }

                    // ----------------------------------------- detail page
                    Loader {
                        id: detailLoader
                        width: parent.width

                        x: root.page === "" ? pages.width * 0.28 : 0
                        opacity: root.page === "" ? 0 : 1
                        visible: opacity > 0.01

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.durFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easeStandard
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durFast
                                easing.type: Theme.easingType
                                easing.bezierCurve: Theme.easeStandard
                            }
                        }

                        sourceComponent: {
                            switch (root.detailPage) {
                            case "wifi":
                                return wifiDetail;
                            case "bluetooth":
                                return btDetail;
                            case "focus":
                                return focusDetail;
                            case "display":
                                return displayDetail;
                            case "sound":
                                return soundDetail;
                            default:
                                return null;
                            }
                        }
                    }
                }

                // ------------------------------------------------ details
                Component {
                    id: wifiDetail

                    CcDetail {
                        title: "Wi-Fi"
                        onBack: root.page = ""

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space2

                            CcSwitchRow {
                                Layout.fillWidth: true
                                label: "Wi-Fi"
                                checked: root.wifiOn
                                interactive: root.wifiSupported
                                onToggled: root.toggleWifi()
                            }
                        }

                        CcSectionLabel {
                            Layout.fillWidth: true
                            text: "Known Networks"
                            visible: root.wifiOn && root.wifiNetworks.length > 0
                        }

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space1
                            visible: root.wifiOn && root.wifiNetworks.length > 0

                            Repeater {
                                model: root.wifiNetworks.slice(0, 6)

                                CcRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.name
                                    glyph: "wifi"
                                    checked: modelData.connected
                                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.space2
                            visible: !root.wifiSupported
                            role: "caption"
                            color: Theme.secondaryLabel
                            text: "No Wi-Fi hardware was found on this Mac."
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Component {
                    id: btDetail

                    CcDetail {
                        title: "Bluetooth"
                        onBack: root.page = ""

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space2

                            CcSwitchRow {
                                Layout.fillWidth: true
                                label: "Bluetooth"
                                checked: root.btOn
                                interactive: root.btSupported
                                onToggled: root.toggleBluetooth()
                            }
                        }

                        CcSectionLabel {
                            Layout.fillWidth: true
                            text: "Devices"
                            visible: root.btOn && root.btDevices.length > 0
                        }

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space1
                            visible: root.btOn && root.btDevices.length > 0

                            Repeater {
                                model: root.btDevices

                                CcRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.name
                                    checked: modelData.connected
                                    status: modelData.connected ? "Connected" : ""
                                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.space2
                            visible: !root.btSupported
                            role: "caption"
                            color: Theme.secondaryLabel
                            text: "No Bluetooth adapter was found."
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Component {
                    id: focusDetail

                    CcDetail {
                        title: "Focus"
                        onBack: root.page = ""

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space1

                            Repeater {
                                model: [
                                    {
                                        id: "dnd",
                                        name: "Do Not Disturb",
                                        glyph: "moon"
                                    },
                                    {
                                        id: "personal",
                                        name: "Personal",
                                        glyph: "person.crop.circle"
                                    },
                                    {
                                        id: "work",
                                        name: "Work",
                                        glyph: "folder"
                                    }
                                ]

                                CcRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: modelData.name
                                    glyph: modelData.glyph
                                    checked: root.focusOn && root.focusMode === modelData.id
                                    onClicked: {
                                        // Clicking the active mode turns Focus
                                        // off, like the macOS menu does.
                                        if (root.focusOn && root.focusMode === modelData.id) {
                                            ShellState.doNotDisturb = false;
                                        } else {
                                            root.focusMode = modelData.id;
                                            ShellState.doNotDisturb = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Component {
                    id: displayDetail

                    CcDetail {
                        title: "Display"
                        onBack: root.page = ""

                        MacSlider {
                            Layout.fillWidth: true
                            style: "capsule"
                            glyph: "sun.max"
                            minimum: 0.05
                            value: root.brightness
                            onCommitted: v => root.setBrightness(v)
                        }

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space2
                            spacing: Theme.space2

                            CcSwitchRow {
                                Layout.fillWidth: true
                                label: "Dark Mode"
                                checked: Theme.dark
                                onToggled: Settings.toggleAppearance()
                            }

                            CcSwitchRow {
                                Layout.fillWidth: true
                                label: "Night Shift"
                                checked: root.nightShiftOn
                                onToggled: value => root.nightShiftOn = value
                            }
                        }
                    }
                }

                Component {
                    id: soundDetail

                    CcDetail {
                        title: "Sound"
                        onBack: root.page = ""

                        MacSlider {
                            Layout.fillWidth: true
                            style: "capsule"
                            glyph: "speaker"
                            glyphLevelCount: 3
                            value: root.muted ? 0 : root.volume
                            onMoved: v => root.setVolume(v)
                            onCommitted: v => root.setVolume(v)
                        }

                        CcSectionLabel {
                            Layout.fillWidth: true
                            text: "Output"
                        }

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space1

                            Repeater {
                                model: root.sinks

                                CcRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: root.nodeLabel(modelData)
                                    checked: root.sink === modelData
                                    // Writing preferredDefaultAudioSink is the
                                    // service's "make this the default" call.
                                    onClicked: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }

                        CcSectionLabel {
                            Layout.fillWidth: true
                            text: "Input"
                            visible: root.sources.length > 0
                        }

                        CcGroup {
                            Layout.fillWidth: true
                            padding: Theme.space1
                            visible: root.sources.length > 0

                            Repeater {
                                model: root.sources

                                CcRow {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    label: root.nodeLabel(modelData)
                                    checked: root.source === modelData
                                    onClicked: Pipewire.preferredDefaultAudioSource = modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
