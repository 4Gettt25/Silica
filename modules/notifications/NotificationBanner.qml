import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../common"

// A macOS "alert": one notification card that slides in from the right, waits,
// and leaves again — with hover-to-pause and swipe-right-to-dismiss.
//
// The delegate root keeps its slot in the stack; only `card` moves, so the
// Column above it can animate repositioning independently of the slide.
Item {
    id: root

    property var entry: null
    // Exposed so the owning window can put a blur region exactly on the card.
    readonly property Item cardItem: card

    property bool closing: false
    readonly property bool critical: root.entry && root.entry.urgency === NotificationUrgency.Critical

    // Distance that takes the card fully off the right screen edge.
    readonly property real slideDistance: width + Theme.space2

    // `userAction` separates "the user got rid of it" (macOS also drops it
    // from Notification Center) from "it simply timed out" (it stays there).
    signal dismissed(int id, bool userAction)
    signal activated(int id)

    width: NotifMetrics.bannerWidth
    height: card.height

    // ------------------------------------------------------------ motion
    property real baseX: root.closing || !root.shown ? root.slideDistance : 0
    property real dragOffset: 0
    property bool shown: false

    // Behaviors sit on the two inputs of `card.x` rather than on x itself, so
    // dragging stays 1:1 with the pointer while the entry/exit still eases.
    Behavior on baseX {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    Behavior on dragOffset {
        enabled: !card.pressing
        NumberAnimation {
            duration: Theme.durFast
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    // The initial value is applied as a binding, then flipping it here (after
    // the Behavior exists) plays the entry animation.
    Component.onCompleted: root.shown = true

    property bool _userAction: false

    function close(userAction) {
        if (root.closing)
            return;
        root._userAction = userAction === true;
        root.closing = true;
        exitTimer.restart();
    }

    Timer {
        id: exitTimer
        interval: Theme.durBase + 20
        onTriggered: root.dismissed(root.entry ? root.entry.id : 0, root._userAction)
    }

    // --------------------------------------------------------- auto-expire
    // expire_timeout: -1 = server default, 0 = never expire. Critical alerts
    // stay until the user deals with them, as in macOS.
    readonly property int lifetime: {
        if (!root.entry)
            return NotifMetrics.defaultTimeout;
        if (root.critical)
            return 0;
        const t = root.entry.n ? root.entry.n.expireTimeout : -1;
        if (t === 0)
            return 0;
        return t > 0 ? t : NotifMetrics.defaultTimeout;
    }

    Timer {
        id: lifeTimer
        interval: Math.max(1, root.lifetime)
        running: root.lifetime > 0 && !root.closing && !card.hovered && !card.pressing
        onTriggered: root.close(false)
    }

    NotificationCard {
        id: card

        y: 0
        x: root.baseX + root.dragOffset
        width: parent.width
        showShadow: true
        showActions: true
        opacity: (root.shown && !root.closing) ? Math.max(0, 1 - Math.abs(root.dragOffset) / root.width) : 0
        entry: root.entry

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durBase
                easing.type: Theme.easingType
                easing.bezierCurve: Theme.easeOut
            }
        }

        onCloseRequested: root.close(true)
        onActivated: root.activated(root.entry ? root.entry.id : 0)

        // Swipe right to dismiss. The card reports the drag from the MouseArea
        // beneath its content, so `card.x` stays a binding on
        // baseX + dragOffset and the action buttons keep their clicks.
        onDragged: dx => root.dragOffset = Math.max(0, dx)
        onDragReleased: (dx, moved) => {
            if (moved && root.dragOffset > root.width * 0.25)
                root.close(true);
            root.dragOffset = 0;
        }
    }
}
