pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../common"

// Small module-local helpers shared by the bar, its menus and its extras.
// (Quickshell registers `pragma Singleton` files found through a directory
// import, so no qmldir entry is needed.)
Singleton {
    id: root

    // "System Settings…" opens the shell's OWN settings window (see
    // modules/settings/SystemSettings.qml) — that is where everything this
    // shell can be configured with lives, and it is always available.
    readonly property bool settingsAvailable: true

    function openSettings(pane) {
        ShellState.openSettings(pane === undefined ? "" : pane);
    }

    // The distribution's control panel, for the things the shell does not own
    // (network credentials, printers, users...). Absent on a bare session.
    readonly property var osSettingsCandidates: ["org.gnome.Settings", "gnome-control-center", "systemsettings", "org.kde.systemsettings", "xfce4-settings-manager", "cinnamon-settings", "budgie-control-center"]

    function osSettingsEntry() {
        for (const id of osSettingsCandidates) {
            const e = Apps.entryFor(id);
            if (e)
                return e;
        }
        return null;
    }

    readonly property bool osSettingsAvailable: osSettingsEntry() !== null

    function openOsSettings() {
        const e = osSettingsEntry();
        if (e)
            launch(e);
        else
            console.warn("macos-shell: no distribution settings application found");
    }

    // Network credentials are the compositor-agnostic example of "not ours":
    // prefer NetworkManager's own editor, then the desktop control panel.
    function openSystemNetworkSettings() {
        for (const id of ["nm-connection-editor", "gnome-control-center", "org.gnome.Settings", "systemsettings", "org.kde.plasma-nm"]) {
            const e = Apps.entryFor(id);
            if (e) {
                launch(e);
                return;
            }
        }
        openOsSettings();
    }

    // Launch a DesktopEntry detached from the shell process.
    function launch(entry) {
        Apps.launchEntry(entry);
    }

    function launchById(id) {
        Apps.launchKey(id);
    }

    // The App Store has no Linux equivalent; use whatever software centre the
    // distribution ships.
    readonly property var storeCandidates: ["org.gnome.Software", "gnome-software", "org.kde.discover", "discover", "io.snapcraft.Store", "pamac-manager"]

    function storeEntry() {
        for (const id of storeCandidates) {
            const e = Apps.entryFor(id);
            if (e)
                return e;
        }
        return null;
    }

    function openStore() {
        const e = storeEntry();
        if (e)
            launch(e);
    }

    // Close whichever window the compositor currently reports as focused.
    function closeFocusedWindow() {
        const w = Compositor.windows.find(win => win.focused);
        if (w)
            Compositor.closeWindow(w.id);
    }

    // ---------------------------------------------------------- recent items
    // macOS's "Recent Items" submenu. There is no system-wide recent-app list
    // on Linux, so build a small MRU from the apps the compositor focuses.
    property var recentApps: []

    readonly property string focusedApp: ShellState.focusedAppName

    onFocusedAppChanged: {
        const name = focusedApp;
        if (name === "" || name === "Desktop")
            return;
        const next = [name].concat(recentApps.filter(a => a !== name));
        recentApps = next.slice(0, 8);
    }

    function clearRecents() {
        recentApps = [];
    }

    // ---------------------------------------------------------- Edit actions
    // The menu bar's Edit menu has to act on whatever window is focused, but
    // this shell has no in-process access to a Linux app's edit commands —
    // unlike a real macOS app, which implements the Edit menu itself. The
    // only thing that reaches across processes is a synthesized key combo, so
    // Cut/Copy/Paste etc. shell out to wtype (the wlr virtual-keyboard
    // protocol; it always types into whatever surface the compositor
    // currently considers focused, so there is no window to target).
    readonly property bool wtypeAvailable: _wtypeCheck.available

    QtObject {
        id: _wtypeCheck
        property bool available: false
    }

    Process {
        command: ["sh", "-c", "command -v wtype >/dev/null 2>&1 && echo yes || echo no"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: _wtypeCheck.available = text.trim() === "yes"
        }
    }

    // Clicking an Edit item closes the menu first (ShellState.openMenu = ""),
    // which destroys the menu's focus-grabbing popup and asks the compositor
    // to hand keyboard focus back to the window that was focused before the
    // menu opened — an async round trip (see Compositor._publishAppName's
    // identical race). Firing wtype in the same tick would often still land
    // on the popup instead of the app, so it waits one beat first.
    Timer {
        id: editActionDelay
        interval: 220
        property var pendingArgs: []
        onTriggered: Quickshell.execDetached(pendingArgs)
    }

    function _sendKeyCombo(mods, key) {
        if (!root.wtypeAvailable)
            return;
        const args = ["wtype"];
        for (const m of mods)
            args.push("-M", m);
        args.push("-k", key);
        for (let i = mods.length - 1; i >= 0; i--)
            args.push("-m", mods[i]);
        editActionDelay.pendingArgs = args;
        editActionDelay.restart();
    }

    function editUndo() {
        _sendKeyCombo(["ctrl"], "z");
    }
    function editRedo() {
        _sendKeyCombo(["ctrl", "shift"], "z");
    }
    function editCut() {
        _sendKeyCombo(["ctrl"], "x");
    }
    function editCopy() {
        _sendKeyCombo(["ctrl"], "c");
    }
    function editPaste() {
        _sendKeyCombo(["ctrl"], "v");
    }
    function editSelectAll() {
        _sendKeyCombo(["ctrl"], "a");
    }
}
