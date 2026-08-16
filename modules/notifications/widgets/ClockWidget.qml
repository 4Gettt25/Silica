import QtQuick
import Quickshell
import Quickshell.Io
import "../../../common"
import ".."

// The macOS World Clock widget: an analog face with the city and date below.
Popover {
    id: root

    radius: Theme.radiusPopover
    contentPadding: Theme.space3

    // Local time, ticking once a second. Time.now only updates every 10s
    // unless the user shows seconds in the menu bar, so the face keeps its
    // own clock; the widget only exists while the panel is open.
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            face.requestPaint();
        }
    }

    // City from the IANA zone (Europe/Berlin -> Berlin). Short-lived and
    // async; if the file or the tools are missing the abbreviation is used.
    property string city: ""

    Process {
        running: true
        command: ["sh", "-c", "readlink -f /etc/localtime 2>/dev/null | sed -n 's|.*/zoneinfo/||p'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const zone = text.trim();
                if (zone.length === 0)
                    return;
                const parts = zone.split("/");
                root.city = parts[parts.length - 1].replace(/_/g, " ");
            }
        }
    }

    readonly property string cityLabel: root.city.length > 0 ? root.city : Qt.formatDateTime(root.now, "t")

    Canvas {
        id: face
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, parent.height - caption.height - Theme.space2)
        height: width
        antialiasing: true
        renderStrategy: Canvas.Cooperative

        function css(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (c.a * (a === undefined ? 1 : a)) + ")";
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const cx = w / 2, cy = h / 2, r = Math.min(w, h) / 2 - 1;
            if (r <= 0)
                return;

            ctx.clearRect(0, 0, w, h);
            ctx.lineCap = "round";

            // Dial
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.fillStyle = face.css(Theme.dark ? Theme.quaternaryFill : Theme.alwaysLight, Theme.dark ? 1 : 0.75);
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = face.css(Theme.separator);
            ctx.stroke();

            // Ticks: long on the hours, hairline on the minutes.
            for (let i = 0; i < 60; i++) {
                const hour = (i % 5) === 0;
                const a = i * Math.PI / 30;
                const outer = r * 0.93;
                const inner = r * (hour ? 0.80 : 0.87);
                ctx.beginPath();
                ctx.lineWidth = hour ? Math.max(1.2, r * 0.045) : 1;
                ctx.strokeStyle = face.css(hour ? Theme.label : Theme.tertiaryLabel);
                ctx.moveTo(cx + Math.sin(a) * inner, cy - Math.cos(a) * inner);
                ctx.lineTo(cx + Math.sin(a) * outer, cy - Math.cos(a) * outer);
                ctx.stroke();
            }

            const hours = root.now.getHours() % 12;
            const mins = root.now.getMinutes();
            const secs = root.now.getSeconds();

            function hand(angle, length, weight, color) {
                ctx.beginPath();
                ctx.lineWidth = weight;
                ctx.strokeStyle = face.css(color);
                ctx.moveTo(cx - Math.sin(angle) * r * 0.14, cy + Math.cos(angle) * r * 0.14);
                ctx.lineTo(cx + Math.sin(angle) * length, cy - Math.cos(angle) * length);
                ctx.stroke();
            }

            hand((hours + mins / 60) * Math.PI / 6, r * 0.50, Math.max(2, r * 0.075), Theme.label);
            hand((mins + secs / 60) * Math.PI / 30, r * 0.74, Math.max(1.6, r * 0.05), Theme.label);
            hand(secs * Math.PI / 30, r * 0.80, Math.max(1, r * 0.025), Theme.orange);

            // Hub
            ctx.beginPath();
            ctx.arc(cx, cy, Math.max(2, r * 0.055), 0, 2 * Math.PI);
            ctx.fillStyle = face.css(Theme.label);
            ctx.fill();
            ctx.beginPath();
            ctx.arc(cx, cy, Math.max(1, r * 0.025), 0, 2 * Math.PI);
            ctx.fillStyle = face.css(Theme.orange);
            ctx.fill();
        }
    }

    Column {
        id: caption
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "callout"
            font.weight: Theme.wMedium
            elide: Text.ElideRight
            text: root.cityLabel
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "caption"
            color: Theme.secondaryLabel
            text: Qt.formatDateTime(root.now, "ddd d MMM")
        }
    }

    // Repaint when the palette changes underneath the canvas.
    Connections {
        target: Theme

        function onModeChanged() {
            face.requestPaint();
        }
    }
}
