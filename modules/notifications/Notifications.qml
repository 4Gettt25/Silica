import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../../common"

// The freedesktop notification server plus the macOS "alert" layer.
//
// Public entry point: `Notifications {}` in shell.qml. History lives in the
// NotificationStore singleton, which the Notification Center reads.
Scope {
    id: root

    // Test-only: pushes a couple of fake alerts (and seeds the store) a moment
    // after startup so the banner stack can be designed without a live client.
    property bool demoMode: false

    // ---------------------------------------------------------- the server
    // If another daemon already owns org.freedesktop.Notifications on the
    // session bus, Quickshell logs a warning and this object simply never
    // emits — nothing here crashes or blocks.
    NotificationServer {
        id: server

        keepOnReload: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            // Without this the object is discarded when the handler returns.
            notification.tracked = true;
            const entry = NotificationStore.add(notification);
            root.present(entry);
        }
    }

    // --------------------------------------------------------- banner stack
    // A ListModel (not a JS array) so the Column can animate insertions and
    // repositioning: replacing an array model resets every delegate.
    ListModel {
        id: bannerModel
        dynamicRoles: true // lets a role hold the entry object as-is
    }

    function present(entry) {
        if (!entry)
            return;
        // Do Not Disturb: straight to Notification Center, except for
        // critical urgency, which always breaks through.
        if (ShellState.doNotDisturb && entry.urgency !== NotificationUrgency.Critical)
            return;
        // No point alerting over the open list the notification is already in.
        if (ShellState.notificationCenterOpen)
            return;

        bannerModel.insert(0, {
            entry: entry
        });
        while (bannerModel.count > NotifMetrics.maxBanners)
            bannerModel.remove(bannerModel.count - 1);
    }

    function _indexOf(id) {
        for (let i = 0; i < bannerModel.count; i++)
            if (bannerModel.get(i).entry.id === id)
                return i;
        return -1;
    }

    function hide(id, userAction) {
        const i = root._indexOf(id);
        if (i < 0)
            return;
        const entry = bannerModel.get(i).entry;
        bannerModel.remove(i);
        // The X / a swipe removes it everywhere, as macOS does; a timeout
        // leaves it in Notification Center. Transient notifications are never
        // kept (freedesktop "transient" hint).
        if (userAction || entry.transient)
            NotificationStore.remove(id);
    }

    // Opening Notification Center clears the alerts on screen.
    Connections {
        target: ShellState

        function onNotificationCenterOpenChanged() {
            if (ShellState.notificationCenterOpen)
                bannerModel.clear();
        }
    }

    // ------------------------------------------------------------- window
    LazyLoader {
        // Only exists while something is on screen.
        active: bannerModel.count > 0

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "macos-shell-notifications"
            // Alerts must never take focus: that would blank the menu bar's
            // app name and steal keys from the user's window.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // The window covers the screen (so a card can slide out past the
            // right edge) but only the stack accepts input.
            mask: Region {
                item: hitbox
            }

            // Per-card blur regions. The list has to be static — a Region tree
            // cannot be built by a Repeater — so four slots are bound to the
            // delegates by index; `rep.count` is what re-evaluates them.
            BackgroundEffect.blurRegion: Region {
                Region {
                    item: win.cardAt(0)
                    radius: NotifMetrics.cardRadius
                }
                Region {
                    item: win.cardAt(1)
                    radius: NotifMetrics.cardRadius
                }
                Region {
                    item: win.cardAt(2)
                    radius: NotifMetrics.cardRadius
                }
                Region {
                    item: win.cardAt(3)
                    radius: NotifMetrics.cardRadius
                }
            }

            function cardAt(i) {
                if (i >= rep.count)
                    return null;
                const delegate = rep.itemAt(i);
                return delegate ? delegate.cardItem : null;
            }

            Item {
                id: hitbox
                anchors.fill: stack
                anchors.margins: -Theme.space2
            }

            Column {
                id: stack

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Theme.barHeight + Theme.space2
                anchors.rightMargin: Theme.space2
                width: NotifMetrics.bannerWidth
                spacing: Theme.space2

                // Cards slide up into a freed slot.
                move: Transition {
                    NumberAnimation {
                        properties: "y"
                        duration: Theme.durBase
                        easing.type: Theme.easingType
                        easing.bezierCurve: Theme.easeOut
                    }
                }

                Repeater {
                    id: rep
                    model: bannerModel

                    delegate: NotificationBanner {
                        // `model` carries the row; NotificationBanner already
                        // declares `entry`, so the role is assigned, not
                        // redeclared as a required property.
                        required property var model
                        required property int index

                        entry: model.entry
                        z: rep.count - index // newest on top of its neighbour

                        onDismissed: (id, userAction) => root.hide(id, userAction)
                        onActivated: id => {
                            const e = NotificationStore.entries.find(x => x.id === id);
                            if (e)
                                NotificationStore.activate(e);
                            root.hide(id, false);
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- demo
    Timer {
        running: root.demoMode
        interval: 900
        onTriggered: {
            NotificationStore.demoMode = true;
            const a = NotificationStore.addFake("Mail", "mail-unread", "Nina Fischer", "Hi there — lunch at 12? There is a new ramen place across the street.", 0, [
                {
                    identifier: "reply",
                    text: "Reply"
                },
                {
                    identifier: "archive",
                    text: "Archive"
                }
            ]);
            root.present(a);
            const b = NotificationStore.addFake("Messages", "internet-mail", "Tobias Krüger", "Sent you the notification mockups 👀", 0);
            root.present(b);
        }
    }
}
