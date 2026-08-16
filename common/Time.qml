pragma Singleton

import QtQuick
import Quickshell

// The clock. macOS shows "Sat 15 Aug 18:32" in the menu bar and drives the
// Notification Center's date header from the same source.
Singleton {
    id: root

    property date now: new Date()

    // Menu bar string, following the user's clock preferences.
    readonly property string clock: {
        let fmt = Settings.clockShowDate ? "ddd d MMM  " : "";
        fmt += Settings.clock24h ? "HH:mm" : "h:mm";
        if (Settings.clockShowSeconds)
            fmt += ":ss";
        if (!Settings.clock24h)
            fmt += " AP";
        return Qt.formatDateTime(now, fmt);
    }

    readonly property string timeOnly: Qt.formatDateTime(now, Settings.clock24h ? "HH:mm" : "h:mm AP")
    readonly property string dayName: Qt.formatDateTime(now, "dddd")
    readonly property string monthDay: Qt.formatDateTime(now, "d")
    readonly property string monthName: Qt.formatDateTime(now, "MMMM")
    readonly property string longDate: Qt.formatDateTime(now, "dddd, d MMMM")

    // Relative "3m ago" used by notifications.
    function relative(when) {
        const d = (when instanceof Date) ? when : new Date(when);
        const secs = Math.max(0, Math.floor((now.getTime() - d.getTime()) / 1000));
        if (secs < 60)
            return "now";
        const mins = Math.floor(secs / 60);
        if (mins < 60)
            return mins + "m ago";
        const hours = Math.floor(mins / 60);
        if (hours < 24)
            return hours + "h ago";
        return Math.floor(hours / 24) + "d ago";
    }

    Timer {
        // 1s only when seconds are displayed; otherwise 10s is plenty and
        // keeps the shell idle.
        interval: Settings.clockShowSeconds ? 1000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }
}
