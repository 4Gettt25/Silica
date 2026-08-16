import QtQuick
import "../../common"

// Symbols Spotlight needs that common/Glyph.qml does not ship.
//
// common/Glyph.qml is off limits for this module, so the three extra symbols
// are drawn here on the same 24x24 SF-Symbols design grid, with the same
// `name` / `size` / `color` / `weight` API, so call sites read identically:
//
//   LauncherGlyph { name: "terminal"; size: 20; color: Theme.label }
//
// Names: "terminal", "equal" (calculator), "return" (the ↵ key cap arrow).
Canvas {
    id: g

    property string name: ""
    property real size: 16
    property color color: Theme.label
    property real weight: 1.8

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWeightChanged: requestPaint()
    onSizeChanged: requestPaint()

    function _css(c) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + c.a + ")";
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        if (name === "")
            return;

        // Authored on a 24x24 grid, then scaled — identical to common/Glyph.
        const s = Math.min(width, height) / 24;
        ctx.save();
        ctx.scale(s, s);
        ctx.lineWidth = weight;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = _css(color);
        ctx.fillStyle = _css(color);

        // Rounded rectangle path (Canvas has no roundRect in Qt's 2D context).
        function rrect(x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.arcTo(x + w, y, x + w, y + r, r);
            ctx.lineTo(x + w, y + h - r);
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
            ctx.lineTo(x + r, y + h);
            ctx.arcTo(x, y + h, x, y + h - r, r);
            ctx.lineTo(x, y + r);
            ctx.arcTo(x, y, x + r, y, r);
            ctx.closePath();
        }

        switch (name) {
        case "terminal":
            {
                // Rounded window with a prompt caret and a command line.
                rrect(3, 5, 18, 14, 3);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(7, 10);
                ctx.lineTo(10, 12);
                ctx.lineTo(7, 14);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(12.5, 15);
                ctx.lineTo(17, 15);
                ctx.stroke();
                break;
            }
        case "equal":
            {
                ctx.beginPath();
                ctx.moveTo(5, 10);
                ctx.lineTo(19, 10);
                ctx.moveTo(5, 15);
                ctx.lineTo(19, 15);
                ctx.stroke();
                break;
            }
        case "return":
            {
                // ↵ : a line coming down from the right, turning left into an
                // arrow head.
                ctx.beginPath();
                ctx.moveTo(19, 7);
                ctx.lineTo(19, 14);
                ctx.lineTo(6, 14);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(10, 10);
                ctx.lineTo(6, 14);
                ctx.lineTo(10, 18);
                ctx.stroke();
                break;
            }
        default:
            break;
        }

        ctx.restore();
    }
}
