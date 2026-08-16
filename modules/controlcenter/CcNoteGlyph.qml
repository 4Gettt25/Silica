import QtQuick

// A beamed-eighth-note symbol ("music.note" in SF Symbols), drawn here rather
// than in common/Glyph.qml because that file is owned by the design system and
// has no music symbol. Same 24x24 design grid and API shape as Glyph, so it can
// be swapped for `Glyph { name: "music.note" }` if one is ever added there.
Canvas {
    id: g

    property real size: 16
    property color color: "#FFFFFF"

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onColorChanged: requestPaint()
    onSizeChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        const s = Math.min(width, height) / 24;
        ctx.save();
        ctx.scale(s, s);
        ctx.fillStyle = "rgba(" + Math.round(g.color.r * 255) + "," + Math.round(g.color.g * 255) + "," + Math.round(g.color.b * 255) + "," + g.color.a + ")";

        // Two stems joined by a beam.
        ctx.beginPath();
        ctx.moveTo(9.4, 17.2);
        ctx.lineTo(9.4, 5.6);
        ctx.lineTo(19.4, 3.2);
        ctx.lineTo(19.4, 14.8);
        ctx.lineTo(17.6, 14.8);
        ctx.lineTo(17.6, 6.0);
        ctx.lineTo(11.2, 7.5);
        ctx.lineTo(11.2, 17.2);
        ctx.closePath();
        ctx.fill();

        // The two note heads, drawn as squashed ellipses.
        function head(cx, cy) {
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(-0.18);
            ctx.scale(1.0, 0.74);
            ctx.beginPath();
            ctx.arc(0, 0, 3.1, 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
        }
        head(7.0, 17.6);
        head(17.0, 15.2);

        ctx.restore();
    }
}
