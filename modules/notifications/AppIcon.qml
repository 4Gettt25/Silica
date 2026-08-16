import QtQuick
import Quickshell
import "../../common"

// The app icon on a notification card.
//
// Resolution order matches macOS/freedesktop practice: the image the client
// attached, then its themed app icon, then a colored tile with the app's
// initial so a card is never blank.
Item {
    id: root

    property string appName: ""
    property string iconName: ""
    property string imagePath: ""
    property real size: NotifMetrics.iconSize

    implicitWidth: size
    implicitHeight: size

    function _url(s) {
        if (!s || s.length === 0)
            return "";
        if (s.startsWith("/"))
            return "file://" + s;
        if (s.startsWith("file:") || s.startsWith("image:") || s.startsWith("qrc:"))
            return s;
        // A themed icon name: iconPath(name, check) returns "" when missing,
        // so the fallback tile below takes over instead of a broken image.
        return Quickshell.iconPath(s, true);
    }

    readonly property string source: {
        const img = root._url(root.imagePath);
        if (img.length > 0)
            return img;
        return root._url(root.iconName);
    }

    readonly property bool usingFallback: root.source.length === 0 || image.status === Image.Error

    // Stable per-app tile color, picked from the system palette.
    readonly property color tileColor: {
        const palette = [Theme.blue, Theme.indigo, Theme.purple, Theme.pink, Theme.red, Theme.orange, Theme.green, Theme.teal, Theme.brown, Theme.gray];
        let h = 0;
        for (let i = 0; i < root.appName.length; i++)
            h = (h * 31 + root.appName.charCodeAt(i)) % 100000;
        return palette[h % palette.length];
    }

    Rectangle {
        anchors.fill: parent
        visible: root.usingFallback
        radius: Theme.iconRadius(root.size)
        antialiasing: true
        color: root.tileColor

        StyledText {
            anchors.centerIn: parent
            role: "title3"
            color: Theme.alwaysLight
            text: root.appName.length > 0 ? root.appName.charAt(0).toUpperCase() : "?"
        }
    }

    Image {
        id: image
        anchors.fill: parent
        visible: !root.usingFallback
        source: root.source
        // App icons carry their own shape, so they are not clipped further.
        fillMode: Image.PreserveAspectFit
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        asynchronous: true
        smooth: true
        cache: true
    }
}
