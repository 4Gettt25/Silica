pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../common"

// Notification history.
//
// The freedesktop server hands out `Notification` QObjects that live only as
// long as they are `tracked`; Notification Center needs them to survive the
// banner, so every incoming notification is tracked and wrapped in a plain JS
// entry that also carries the things DBus does not give us (arrival time,
// read state, a stable id) plus a snapshot of the text, so a card can still
// render after the client destroyed the object.
//
// `entries` is newest-first and is always REPLACED, never mutated in place —
// that is what makes the derived properties and the views update.
Singleton {
    id: root

    readonly property int historyCap: 100

    // [{ id, n, appName, appIcon, image, summary, body, urgency, transient,
    //    time, read, actions }]  — newest first. `n` is null for demo entries.
    property var entries: []

    property int _nextId: 1

    // Seeds fake history so the panel can be designed/screenshotted without a
    // live DBus server. Never set from the real code path.
    property bool demoMode: false

    signal added(var entry)

    readonly property int unreadCount: {
        let n = 0;
        for (const e of root.entries)
            if (!e.read)
                n++;
        return n;
    }

    readonly property bool empty: root.entries.length === 0

    // Notifications grouped by app, groups ordered by their newest member.
    readonly property var groups: {
        const index = {};
        const out = [];
        for (const e of root.entries) {
            const key = e.appName;
            if (index[key] === undefined) {
                index[key] = out.length;
                out.push({
                    appName: key,
                    entries: [e]
                });
            } else {
                out[index[key]].entries.push(e);
            }
        }
        return out;
    }

    // The menu bar / Control Center read the badge from ShellState.
    Binding {
        target: ShellState
        property: "notificationCount"
        value: root.unreadCount
    }

    // ------------------------------------------------------------- ingest
    function add(n) {
        const entry = {
            id: root._nextId++,
            n: n,
            appName: (n.appName && n.appName.length > 0) ? n.appName : "Notification",
            appIcon: n.appIcon || "",
            image: n.image || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            transient: n.transient === true,
            time: new Date(),
            read: false,
            actions: null // live actions come from entry.n.actions
        };

        // The client may close the notification itself (CloseNotification),
        // which destroys the object — drop our entry with it so no view ever
        // dereferences a dangling pointer.
        n.closed.connect(function () {
            root.remove(entry.id);
        });

        root._insert(entry);
        root.added(entry);
        return entry;
    }

    // Demo/history entry with no live DBus object behind it.
    function addFake(appName, icon, summary, body, minutesAgo, actions) {
        const entry = {
            id: root._nextId++,
            n: null,
            appName: appName,
            appIcon: icon || "",
            image: "",
            summary: summary,
            body: body,
            urgency: NotificationUrgency.Normal,
            transient: false,
            time: new Date(Date.now() - (minutesAgo || 0) * 60000),
            read: false,
            actions: actions || []
        };
        root._insert(entry);
        root.added(entry);
        return entry;
    }

    function _insert(entry) {
        let list = [entry].concat(root.entries);
        if (list.length > root.historyCap) {
            const dropped = list.slice(root.historyCap);
            list = list.slice(0, root.historyCap);
            for (const d of dropped)
                root._release(d);
        }
        root.entries = list;
    }

    // Hand the notification back to the server (destroys the object).
    function _release(e) {
        if (e && e.n) {
            try {
                e.n.dismiss();
            } catch (err) {
                // already destroyed by the client
            }
        }
    }

    // ------------------------------------------------------------ mutation
    function remove(id) {
        const list = root.entries.slice();
        let found = null;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id) {
                found = list[i];
                list.splice(i, 1);
                break;
            }
        }
        if (!found)
            return;
        // Drop from the model FIRST so the dismiss()->closed->remove() loop
        // terminates here.
        root.entries = list;
        root._release(found);
    }

    function removeApp(appName) {
        const keep = [];
        const drop = [];
        for (const e of root.entries)
            (e.appName === appName ? drop : keep).push(e);
        root.entries = keep;
        for (const d of drop)
            root._release(d);
    }

    function clearAll() {
        const drop = root.entries;
        root.entries = [];
        for (const d of drop)
            root._release(d);
    }

    function markAllRead() {
        for (const e of root.entries)
            e.read = true;
        root.entries = root.entries.slice(); // same objects, new array => notify
    }

    function markRead(id) {
        for (const e of root.entries) {
            if (e.id === id) {
                e.read = true;
                break;
            }
        }
        root.entries = root.entries.slice();
    }

    // ------------------------------------------------------------- actions
    // Visible action buttons: the freedesktop "default" action is the one the
    // whole card triggers, so it is never drawn as a button.
    function actionsOf(entry) {
        const list = (entry && entry.n) ? entry.n.actions : (entry ? entry.actions : null);
        if (!list)
            return [];
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (list[i].identifier !== "default")
                out.push(list[i]);
        return out;
    }

    function invoke(entry, action) {
        if (action && typeof action.invoke === "function")
            action.invoke();
        root.remove(entry.id);
    }

    // The default action (click on the card). Returns true if one existed.
    function activate(entry) {
        const list = (entry && entry.n) ? entry.n.actions : null;
        if (list) {
            for (let i = 0; i < list.length; i++) {
                if (list[i].identifier === "default") {
                    list[i].invoke();
                    root.remove(entry.id);
                    return true;
                }
            }
        }
        root.remove(entry.id);
        return false;
    }

    // ---------------------------------------------------------- demo seed
    onDemoModeChanged: if (demoMode) root.seedDemo()

    function seedDemo() {
        // Added oldest-first so the newest ends up on top.
        root.addFake("Calendar", "office-calendar", "Design Review", "Today from 15:00 to 16:00 — Meeting Room 2", 96);
        root.addFake("Slack", "slack", "#design", "ana: pushed the new sidebar mock, have a look when you get a sec", 42);
        root.addFake("Mail", "mail-unread", "Jonas Weber", "Re: Q3 roadmap — Looks good to me, let's ship it on Friday.", 24);
        root.addFake("Mail", "mail-unread", "Nina Fischer", "Lunch at 12? There is a new ramen place across the street.", 11, [
            {
                identifier: "reply",
                text: "Reply"
            },
            {
                identifier: "archive",
                text: "Archive"
            }
        ]);
        root.addFake("Slack", "slack", "Tobias Krüger", "Can you review the notification stack before standup?", 3);
        root.addFake("Music", "audio-x-generic", "Now Playing", "Bonobo — Kerala", 0);
    }
}
