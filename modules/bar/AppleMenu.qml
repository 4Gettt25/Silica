import QtQuick
import Quickshell
import "../../common"

// The Apple menu — the real macOS structure, wired to real actions where an
// equivalent exists on Linux.
//
// The mark itself is what System Settings > Menu Bar calls the "menu bar
// logo": the drawn Apple by default, this machine's distribution logo, or any
// image the user points at.
BarMenu {
    id: root

    readonly property bool useApple: Settings.menuBarLogo !== "distro" && Settings.menuBarLogo !== "custom"
    readonly property string customLogo: {
        const p = String(Settings.menuBarLogoPath ?? "");
        if (p === "")
            return "";
        return p.indexOf("://") >= 0 ? p : "file://" + p;
    }

    menuId: "apple"
    glyph: "apple"
    iconSource: {
        if (Settings.menuBarLogo === "custom")
            return customLogo;
        if (Settings.menuBarLogo === "distro")
            return OsInfo.logoSource;
        return "";
    }
    glyphSize: Theme.barGlyphSize - 3
    // The Apple mark's optical centre sits slightly below its bounding box.
    glyphOffsetY: -1

    // Recent Items, built from the compositor's focus history (there is no
    // system-wide recent-apps list on Linux).
    readonly property var recentSubmenu: {
        const entries = BarActions.recentApps.map(name => ({
                    text: name,
                    action: () => {
                        const e = DesktopEntries.heuristicLookup(name);
                        if (e)
                            BarActions.launch(e);
                    }
                }));
        if (entries.length === 0)
            return [
                {
                    text: "No Recent Items",
                    enabled: false
                }
            ];
        return entries.concat([
            {
                separator: true
            },
            {
                text: "Clear Menu",
                action: () => BarActions.clearRecents()
            }
        ]);
    }

    items: [
        {
            text: root.useApple ? "About This Mac" : "About This Computer",
            action: () => about.open = true
        },
        {
            separator: true
        },
        {
            text: "System Settings…",
            shortcut: "⌘,",
            action: () => BarActions.openSettings("")
        },
        {
            text: (OsInfo.name === "" ? "Linux" : OsInfo.name) + " Settings…",
            enabled: BarActions.osSettingsAvailable,
            action: () => BarActions.openOsSettings()
        },
        {
            text: "App Store…",
            enabled: BarActions.storeEntry() !== null,
            action: () => BarActions.openStore()
        },
        {
            separator: true
        },
        {
            text: "Recent Items",
            submenu: root.recentSubmenu
        },
        {
            separator: true
        },
        {
            text: "Force Quit…",
            shortcut: "⌥⌘⎋",
            action: () => forceQuit.open = true
        },
        {
            separator: true
        },
        {
            text: "Sleep",
            action: () => Quickshell.execDetached(["systemctl", "suspend"])
        },
        {
            text: "Restart…",
            action: () => Quickshell.execDetached(["systemctl", "reboot"])
        },
        {
            text: "Shut Down…",
            action: () => Quickshell.execDetached(["systemctl", "poweroff"])
        },
        {
            separator: true
        },
        {
            text: "Lock Screen",
            shortcut: "⌃⌘Q",
            action: () => ShellState.lockRequested()
        },
        {
            text: "Log Out…",
            shortcut: "⇧⌘Q",
            action: () => root.logOut()
        }
    ]

    // niri/Hyprland both quit on the compositor's own action; fall back to
    // ending the whole user session if the compositor is unknown.
    function logOut() {
        if (Compositor.compositor === "unknown")
            Quickshell.execDetached(["loginctl", "terminate-user", Quickshell.env("USER") ?? ""]);
        else
            Compositor.dispatch("quit");
    }

    AboutSheet {
        id: about
        screen: root.screen
    }

    ForceQuitSheet {
        id: forceQuit
        screen: root.screen
    }
}
