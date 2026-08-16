import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../../common"
import ".."

// Network status + the macOS Wi-Fi menu.
//
// Primary source is Quickshell.Networking (a live NetworkManager binding, no
// polling). If no backend is present — NetworkManager not running, or a
// distro using iwd directly — everything falls back to short-lived `nmcli`
// calls on a timer, and the whole item hides if nmcli is missing too.
//
// The bar item follows what the machine is actually connected THROUGH: a
// desktop on Ethernet gets the LAN mark, a laptop on Wi-Fi gets the arcs at
// the real signal strength, and a machine with no wireless hardware at all
// never shows a Wi-Fi icon.
StatusItem {
    id: root

    extraId: "wifi"
    popoverWidth: 290
    implicitWidth: Theme.barGlyphSize + Theme.space2

    // ------------------------------------------------------------- backend
    readonly property bool serviceBacked: Networking.backend === NetworkBackendType.NetworkManager

    readonly property var wifiDevice: {
        if (!serviceBacked || !Networking.devices)
            return null;
        for (const d of Networking.devices.values) {
            if (d.type === DeviceType.Wifi)
                return d;
        }
        return null;
    }

    // Any wired device with a live link. `connected` is the one that decides
    // the icon; a plugged-but-unconfigured NIC is not "the connection".
    readonly property var wiredDevice: {
        if (!serviceBacked || !Networking.devices)
            return null;
        let candidate = null;
        for (const d of Networking.devices.values) {
            if (d.type !== DeviceType.Wired)
                continue;
            if (d.connected)
                return d;
            if (candidate === null && d.hasLink)
                candidate = d;
        }
        return candidate;
    }

    // ------------------------------------------------------ unified model
    // Both backends produce the same plain-object shape so the UI never has
    // to care which one is live:
    //   { name, level (0..3), secured, known, connected, connecting, obj }
    property var fallbackNetworks: []
    property bool fallbackWifiEnabled: false
    property bool fallbackWifiAvailable: false
    property bool fallbackWiredConnected: false
    property string fallbackWiredName: ""

    function _level(strength) {
        // NetworkManager reports 0..100; be tolerant of a 0..1 fraction.
        const pct = strength <= 1 ? strength * 100 : strength;
        if (pct >= 70)
            return 3;
        if (pct >= 45)
            return 2;
        if (pct >= 20)
            return 1;
        return 0;
    }

    readonly property var networks: {
        if (!serviceBacked)
            return fallbackNetworks;
        const dev = wifiDevice;
        if (!dev || !dev.networks)
            return [];
        const out = [];
        const seen = {};
        for (const n of dev.networks.values) {
            const name = n.name || "";
            if (name === "" || seen[name])
                continue;
            seen[name] = true;
            out.push({
                name: name,
                level: root._level(n.signalStrength),
                secured: n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown,
                known: n.known === true,
                connected: n.connected === true,
                connecting: n.stateChanging === true,
                obj: n
            });
        }
        out.sort((a, b) => b.level - a.level || (a.name < b.name ? -1 : 1));
        return out;
    }

    readonly property var connectedNetwork: networks.find(n => n.connected) ?? null
    readonly property var knownNetworks: networks.filter(n => n.known && !n.connected)
    // Cap the "Other Networks" list — macOS scrolls, we simply show the best.
    readonly property var otherNetworks: networks.filter(n => !n.known && !n.connected).slice(0, 8)

    readonly property bool wifiEnabled: serviceBacked ? Networking.wifiEnabled : fallbackWifiEnabled
    // Only true when the machine actually has wireless hardware.
    readonly property bool wifiAvailable: serviceBacked ? (wifiDevice !== null) : fallbackWifiAvailable

    readonly property bool wiredConnected: serviceBacked ? (wiredDevice !== null && wiredDevice.connected) : fallbackWiredConnected
    // The NetworkManager connection name if there is one ("Wired connection 1"),
    // otherwise just "Ethernet" — the interface name belongs in the detail
    // column, not in the place a network name goes.
    readonly property string wiredName: {
        if (!serviceBacked)
            return fallbackWiredName === "" ? "Ethernet" : fallbackWiredName;
        if (wiredDevice === null)
            return "Ethernet";
        const net = wiredDevice.network;
        const label = net ? String(net.name ?? "") : "";
        return label.length > 0 ? label : "Ethernet";
    }
    readonly property string wiredInterface: {
        if (!serviceBacked || wiredDevice === null)
            return "";
        return String(wiredDevice.name ?? "");
    }

    // A desktop with neither a wireless card nor a cable has nothing to say.
    visible: wifiAvailable || wiredConnected

    function setWifiEnabled(on) {
        if (serviceBacked)
            Networking.wifiEnabled = on;
        else
            Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
    }

    function connectTo(entry) {
        if (!entry)
            return;
        if (entry.obj)
            entry.obj.connect();
        else
            // No password prompt: this succeeds for known/open networks and
            // simply fails (leaving the list unchanged) otherwise.
            Quickshell.execDetached(["nmcli", "device", "wifi", "connect", entry.name]);
    }

    // --------------------------------------------------- nmcli fallback
    // -t = terminal-friendly colon-separated output; escaped colons in SSIDs
    // come through as "\:" which the parser below un-escapes.
    Process {
        id: nmcliProc
        command: ["sh", "-c", "nmcli --escape no -t -f WIFI radio; echo '--'; nmcli --escape no -t -f TYPE,STATE,CONNECTION device; echo '--'; nmcli --escape no -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no"]

        stdout: StdioCollector {
            onStreamFinished: {
                const sections = this.text.split("\n--\n");
                if (sections.length < 3) {
                    root.fallbackWifiAvailable = false;
                    root.fallbackWiredConnected = false;
                    return;
                }

                root.fallbackWifiEnabled = sections[0].trim() === "enabled";

                // devices: TYPE:STATE:CONNECTION
                let wired = false;
                let wiredName = "";
                let hasWifi = false;
                for (const l of sections[1].split("\n")) {
                    const f = l.split(":");
                    if (f.length < 2)
                        continue;
                    const type = f[0];
                    const state = f[1];
                    if (type === "wifi")
                        hasWifi = true;
                    if (type === "ethernet" && state.indexOf("connected") === 0) {
                        wired = true;
                        wiredName = f.slice(2).join(":");
                    }
                }
                root.fallbackWifiAvailable = hasWifi;
                root.fallbackWiredConnected = wired;
                root.fallbackWiredName = wiredName.length > 0 ? wiredName : "Ethernet";

                const out = [];
                const seen = {};
                for (const l of sections[2].split("\n")) {
                    if (l.length === 0)
                        continue;
                    // The SSID is field 1, but an SSID may itself contain ":".
                    // The first and last two fields are unambiguous, so take
                    // everything between them as the name.
                    const f = l.split(":");
                    if (f.length < 4)
                        continue;
                    const name = f.slice(1, f.length - 2).join(":");
                    if (name === "" || seen[name])
                        continue;
                    seen[name] = true;
                    out.push({
                        name: name,
                        level: root._level(parseInt(f[f.length - 2]) || 0),
                        secured: f[f.length - 1].trim() !== "",
                        known: false, // nmcli's list does not say; treated as "other"
                        connected: f[0].indexOf("*") >= 0,
                        connecting: false,
                        obj: null
                    });
                }
                out.sort((a, b) => b.level - a.level || (a.name < b.name ? -1 : 1));
                root.fallbackNetworks = out;
            }
        }
    }

    Timer {
        // Only runs when the Networking service has no backend. Faster while
        // the menu is open so the list feels live.
        interval: root.open ? 4000 : 15000
        running: !root.serviceBacked
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!nmcliProc.running) nmcliProc.running = true
    }

    // The service scans on demand; keep the scanner on only while the menu is
    // open so the radio is not woken up every few seconds for nothing.
    Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.open
        when: root.wifiDevice !== null
    }

    // ------------------------------------------------------------- bar item
    // Ethernet wins: that is the connection actually carrying traffic. With no
    // cable it is the Wi-Fi state, and the slashed mark when the radio is off.
    Glyph {
        anchors.centerIn: parent
        name: root.wiredConnected ? "ethernet" : (root.wifiEnabled ? "wifi" : "wifi.slash")
        level: root.connectedNetwork ? root.connectedNetwork.level : 0
        size: Theme.barGlyphSize
        color: Theme.label
    }

    // ------------------------------------------------------------- popover
    popover: ColumnLayout {
        spacing: Theme.space1

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.space1

            StyledText {
                Layout.fillWidth: true
                role: "headline"
                // Without a radio this popover is only about the cable.
                text: root.wifiAvailable ? "Wi-Fi" : "Network"
            }

            MacSwitch {
                visible: root.wifiAvailable
                checked: root.wifiAvailable && root.wifiEnabled
                onToggled: v => root.setWifiEnabled(v)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        // ---- wired ----
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            visible: root.wiredConnected
            role: "caption"
            color: Theme.tertiaryLabel
            text: "Ethernet"
        }

        PopoverRow {
            Layout.fillWidth: true
            visible: root.wiredConnected
            gutter: true
            checked: true
            emphasised: true
            label: root.wiredName
            detail: root.wiredInterface
        }

        // ---- wireless ----
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            visible: root.wifiEnabled && (root.connectedNetwork !== null || root.knownNetworks.length > 0)
            role: "caption"
            color: Theme.tertiaryLabel
            text: "Known Networks"
        }

        PopoverRow {
            Layout.fillWidth: true
            visible: root.connectedNetwork !== null
            gutter: true
            checked: true
            emphasised: true
            label: root.connectedNetwork ? root.connectedNetwork.name : ""
            secured: root.connectedNetwork ? root.connectedNetwork.secured : false
            signalLevel: root.connectedNetwork ? root.connectedNetwork.level : -1
        }

        Repeater {
            model: root.wifiEnabled ? root.knownNetworks : []

            delegate: PopoverRow {
                required property var modelData
                Layout.fillWidth: true
                gutter: true
                label: modelData.name
                detail: modelData.connecting ? "Connecting…" : ""
                secured: modelData.secured
                signalLevel: modelData.level
                onClicked: root.connectTo(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            visible: root.wifiEnabled && root.otherNetworks.length > 0
            role: "caption"
            color: Theme.tertiaryLabel
            text: "Other Networks"
        }

        Repeater {
            model: root.wifiEnabled ? root.otherNetworks : []

            delegate: PopoverRow {
                required property var modelData
                Layout.fillWidth: true
                gutter: true
                label: modelData.name
                detail: modelData.connecting ? "Connecting…" : ""
                secured: modelData.secured
                signalLevel: modelData.level
                onClicked: root.connectTo(modelData)
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            visible: !root.wifiAvailable
            role: "callout"
            color: Theme.secondaryLabel
            text: root.wiredConnected ? "This computer has no Wi-Fi hardware." : "Not connected."
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            visible: root.wifiAvailable && !root.wifiEnabled
            role: "callout"
            color: Theme.secondaryLabel
            text: "Wi-Fi is off."
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Theme.space1
            implicitHeight: 1
            color: Theme.separator
        }

        PopoverRow {
            Layout.fillWidth: true
            label: "Network Settings…"
            onClicked: {
                ShellState.openMenu = "";
                BarActions.openSystemNetworkSettings();
            }
        }
    }
}
