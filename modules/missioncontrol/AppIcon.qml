import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../common"

// The icon of an application, resolved from its wayland app id.
//
// `DesktopEntries.heuristicLookup()` handles the usual mismatches between an
// app id and a .desktop file id (case, reverse-DNS prefixes, StartupWMClass);
// `Quickshell.iconPath(name, true)` returns "" instead of a fallback pixmap
// when the icon theme has nothing, which drives the initial-tile fallback used
// everywhere else in this shell (see modules/dock/DockIcon.qml).
Item {
    id: root

    property string appId: ""
    property string label: ""
    property real iconSize: 24

    implicitWidth: iconSize
    implicitHeight: iconSize
    width: iconSize
    height: iconSize

    readonly property string resolved: {
        const id = appId || "";
        if (id.length === 0)
            return "";
        let name = id;
        const entry = DesktopEntries.heuristicLookup(id);
        if (entry && entry.icon)
            name = entry.icon;
        let path = Quickshell.iconPath(name, true);
        if (path.length === 0)
            path = Quickshell.iconPath(id.toLowerCase(), true);
        return path;
    }

    readonly property string initial: {
        const s = label.length > 0 ? label : appId;
        return s.length > 0 ? s.charAt(0).toUpperCase() : "?";
    }

    // Deterministic per-app tile colour, same idiom as DockIcon.
    readonly property color tileColor: {
        const s = label.length > 0 ? label : appId;
        var h = 0;
        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360.0, 0.55, 0.5, 1.0);
    }

    IconImage {
        anchors.fill: parent
        visible: root.resolved.length > 0
        source: root.resolved
        implicitSize: Math.round(root.iconSize)
        mipmap: true
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        visible: root.resolved.length === 0
        radius: Theme.iconRadius(root.iconSize)
        antialiasing: true
        color: root.tileColor

        StyledText {
            anchors.centerIn: parent
            text: root.initial
            color: Theme.alwaysLight
            font.pixelSize: Math.round(root.iconSize * 0.46)
            font.weight: Theme.wSemibold
        }
    }
}
