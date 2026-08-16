import QtQuick
import QtQuick.Effects

// A single monochrome symbol.
//
// Usage:  Glyph { name: "wifi"; size: 15; color: Theme.label }
//         Glyph { name: "wifi"; level: 1 }            // 0..3 signal bars
//
// Names deliberately echo SF Symbols so the intent is readable at the call
// site; unknown names draw nothing (never an error box).
//
// Two renderers sit behind that one API:
//
//   * an installed icon theme, when it has a symbolic icon for the name.
//     common/SymbolIcons.qml owns the name mapping; scripts/install-icons.sh
//     installs WhiteSur, whose symbolic set is drawn in the macOS idiom. The
//     SVG is rasterised at exactly the size it is shown at and then tinted to
//     `color`: symbolic icons carry their shape in the alpha channel, so a
//     flat colour masked by that alpha is the icon in the shell's ink;
//   * the Canvas below otherwise — every symbol painted procedurally on a
//     24x24 grid (the grid SF Symbols uses), so the shell still looks right
//     with no icon theme installed, and so the handful of marks that are
//     better hand-drawn than themed (the Apple logo, the Control Center
//     switches, the pop-up button chevrons) keep their exact shapes.
//
// Sharpness of the drawn path. Two things used to make these look soft at
// menu-bar sizes:
//
//   * the canvas was rasterised at exactly one device pixel per point, so a
//     1.2px stroke landed between two pixel rows. The Canvas is now drawn at
//     `ss` times the final size and scaled back down, which supersamples every
//     curve (on a HiDPI screen the backing store is already dense enough, so
//     the factor drops back to 1);
//   * the item itself often ended up on a half pixel — `anchors.centerIn` of a
//     15px glyph in a 24px item gives x = 4.5 — and the whole texture was then
//     resampled off-grid. The Translate below snaps the paint origin back onto
//     whole pixels.
Item {
    id: g

    property string name: ""
    property real size: 16
    property color color: "#FFFFFF"
    // Some glyphs have levels: wifi 0..3, speaker 0..3, battery uses `value`.
    property int level: 3
    // 0..1 fill level, used by "battery".
    property real value: 1.0
    property bool charging: false
    // Stroke weight on the 24x24 grid (SF Symbols "regular" is ~1.7).
    property real weight: 1.8

    // Whole-pixel side length of the finished glyph. Taken from the item's
    // real size, so `size: 15` and `anchors.fill: parent` both work.
    readonly property int px: Math.max(1, Math.round(Math.min(width, height)))
    // Supersampling factor. A HiDPI backing store already has the samples.
    readonly property int ss: Screen.devicePixelRatio >= 2 ? 1 : 2

    // "" when the icon theme has nothing for this name/state, which is what
    // hands the symbol back to the Canvas.
    readonly property string themedSource: SymbolIcons.resolve(name, level, value, charging)
    readonly property bool themed: themedSource !== ""

    implicitWidth: Math.max(1, Math.round(size))
    implicitHeight: Math.max(1, Math.round(size))

    // Paint on whole pixels even when the layout put us on a half one.
    transform: Translate {
        x: Math.round(g.x) - g.x
        y: Math.round(g.y) - g.y
    }

    function requestPaint() {
        canvas.requestPaint();
    }

    // ------------------------------------------------------- themed symbol
    // A flat rectangle of `color`, masked by the icon's alpha channel. Reading
    // only the alpha is deliberate: it makes the shell's ink — and therefore
    // the selected/disabled/accent states — win over whatever grey the theme
    // painted its symbolic icons in, and it works identically in light and
    // dark mode from one set of files.
    Item {
        id: themedLayer

        visible: g.themed
        x: Math.round((g.width - g.px) / 2)
        y: Math.round((g.height - g.px) / 2)
        width: g.px
        height: g.px

        Image {
            id: themedMask

            anchors.fill: parent
            // Only ever the mask for the tint below; never drawn itself.
            // `layer.enabled` is not optional here — MultiEffect can only read
            // a mask that has been rendered to a texture, and a hidden Image
            // on its own never is (the mask then reads as fully opaque and
            // every symbol comes out a solid square).
            visible: false
            layer.enabled: true
            source: g.themedSource
            // Rasterise the SVG at its final pixel size instead of scaling a
            // 16px raster up — this is the whole point of moving to a theme.
            sourceSize.width: g.px * g.ss
            sourceSize.height: g.px * g.ss
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            cache: true
        }

        Rectangle {
            id: themedInk

            anchors.fill: parent
            visible: false
            color: g.color
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: themedInk
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: themedMask
            // The mask ramp runs from `threshold - spread/2` to
            // `threshold + spread/2`, so these two values spread it across the
            // whole 0..1 alpha range. Anything narrower posterises the icon:
            // edges lose their anti-aliasing and the deliberately dimmed parts
            // (the weak arcs of a low Wi-Fi signal, which is the only thing
            // separating one signal-strength icon from the next) jump to full
            // strength. A threshold of 0 with any spread includes alpha 0 too
            // and fills the whole square.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    Canvas {
        id: canvas

        visible: !g.themed
        width: g.px * g.ss
        height: g.px * g.ss
        // Centred, because an item filled by anchors need not be square.
        x: Math.round((g.width - g.px) / 2)
        y: Math.round((g.height - g.px) / 2)
        antialiasing: true
        smooth: true
        renderStrategy: Canvas.Cooperative

        // Draw big, show small.
        transform: Scale {
            xScale: 1 / g.ss
            yScale: 1 / g.ss
        }

        Connections {
            target: g
            function onNameChanged() { canvas.requestPaint(); }
            function onColorChanged() { canvas.requestPaint(); }
            function onLevelChanged() { canvas.requestPaint(); }
            function onValueChanged() { canvas.requestPaint(); }
            function onChargingChanged() { canvas.requestPaint(); }
            function onWeightChanged() { canvas.requestPaint(); }
            function onPxChanged() { canvas.requestPaint(); }
        }

        function _css(c, a) {
            return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (c.a * (a === undefined ? 1 : a)) + ")";
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            if (g.name === "")
                return;

            // Everything below is authored on a 24x24 grid.
            const s = Math.min(width, height) / 24;
            ctx.save();
            ctx.scale(s, s);
            ctx.lineWidth = g.weight;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.strokeStyle = _css(g.color);
            ctx.fillStyle = _css(g.color);

            // ---- small drawing helpers (24-grid units) ----
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
            function line(x1, y1, x2, y2) {
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.stroke();
            }
            function dot(x, y, r) {
                ctx.beginPath();
                ctx.arc(x, y, r, 0, 2 * Math.PI);
                ctx.fill();
            }
            function chevron(cx, cy, dir, len) {
                const l = len === undefined ? 4 : len;
                ctx.beginPath();
                if (dir === "right") {
                    ctx.moveTo(cx - l / 2, cy - l);
                    ctx.lineTo(cx + l / 2, cy);
                    ctx.lineTo(cx - l / 2, cy + l);
                } else if (dir === "left") {
                    ctx.moveTo(cx + l / 2, cy - l);
                    ctx.lineTo(cx - l / 2, cy);
                    ctx.lineTo(cx + l / 2, cy + l);
                } else if (dir === "down") {
                    ctx.moveTo(cx - l, cy - l / 2);
                    ctx.lineTo(cx, cy + l / 2);
                    ctx.lineTo(cx + l, cy - l / 2);
                } else {
                    ctx.moveTo(cx - l, cy + l / 2);
                    ctx.lineTo(cx, cy - l / 2);
                    ctx.lineTo(cx + l, cy + l / 2);
                }
                ctx.stroke();
            }
            function slash() {
                // The SF Symbols "disabled" diagonal, with a knockout behind it.
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                ctx.lineWidth = g.weight + 1.6;
                ctx.strokeStyle = "rgba(0,0,0,1)";
                line(4.5, 3.5, 19.5, 20.5);
                ctx.restore();
                ctx.lineWidth = g.weight;
                ctx.strokeStyle = _css(g.color);
                line(4.5, 4.5, 19.5, 19.5);
            }

            switch (g.name) {

            // ------------------------------------------------ connectivity
            case "wifi":
            case "wifi.slash": {
                const cx = 12, cy = 18.4;
                const arcs = [
                    {
                        r: 4.4,
                        lvl: 1
                    },
                    {
                        r: 8.0,
                        lvl: 2
                    },
                    {
                        r: 11.6,
                        lvl: 3
                    }
                ];
                dot(cx, cy, 1.5);
                for (const a of arcs) {
                    ctx.globalAlpha = (g.level >= a.lvl) ? 1.0 : 0.30;
                    ctx.beginPath();
                    ctx.arc(cx, cy, a.r, Math.PI * 1.22, Math.PI * 1.78);
                    ctx.stroke();
                }
                ctx.globalAlpha = 1.0;
                if (g.name === "wifi.slash")
                    slash();
                break;
            }
            case "bluetooth": {
                const cx = 12;
                ctx.beginPath();
                ctx.moveTo(cx, 3.2);
                ctx.lineTo(cx, 20.8);
                ctx.moveTo(cx, 3.2);
                ctx.lineTo(17.4, 7.6);
                ctx.lineTo(cx, 12);
                ctx.lineTo(17.4, 16.4);
                ctx.lineTo(cx, 20.8);
                ctx.moveTo(6.6, 7.6);
                ctx.lineTo(17.4, 16.4);
                ctx.moveTo(6.6, 16.4);
                ctx.lineTo(17.4, 7.6);
                ctx.stroke();
                break;
            }
            case "airdrop": {
                ctx.beginPath();
                ctx.arc(12, 13, 3.2, Math.PI * 1.15, Math.PI * 1.85);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(12, 13, 6.4, Math.PI * 1.15, Math.PI * 1.85);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(12, 21);
                ctx.lineTo(8.6, 15.6);
                ctx.lineTo(15.4, 15.6);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "network":
            case "globe": {
                ctx.beginPath();
                ctx.arc(12, 12, 8.6, 0, 2 * Math.PI);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(12, 3.4);
                ctx.bezierCurveTo(7.6, 7.6, 7.6, 16.4, 12, 20.6);
                ctx.bezierCurveTo(16.4, 16.4, 16.4, 7.6, 12, 3.4);
                ctx.stroke();
                line(3.6, 12, 20.4, 12);
                break;
            }
            case "ethernet": {
                // Wired network: one node above, two below, joined by a bus. macOS
                // shows a globe for Ethernet, but the LAN mark reads faster here.
                const nodeW = 7.4, nodeH = 5.0, r = 1.4;
                rrect(12 - nodeW / 2, 2.4, nodeW, nodeH, r);
                ctx.stroke();
                rrect(1.8, 16.6, nodeW, nodeH, r);
                ctx.stroke();
                rrect(24 - 1.8 - nodeW, 16.6, nodeW, nodeH, r);
                ctx.stroke();
                const lx = 1.8 + nodeW / 2, rx = 24 - 1.8 - nodeW / 2;
                line(12, 7.4, 12, 12.2);
                line(lx, 12.2, rx, 12.2);
                line(lx, 12.2, lx, 16.6);
                line(rx, 12.2, rx, 16.6);
                break;
            }
            case "antenna": {
                for (let i = 0; i < 4; i++) {
                    const h = 4 + i * 3.6;
                    ctx.globalAlpha = g.level > i ? 1.0 : 0.3;
                    rrect(4 + i * 4.6, 20 - h, 2.6, h, 1.3);
                    ctx.fill();
                }
                ctx.globalAlpha = 1.0;
                break;
            }

            // ------------------------------------------------------- power
            case "battery": {
                rrect(1.6, 7.6, 17.4, 8.8, 3.0);
                ctx.globalAlpha = 0.45;
                ctx.stroke();
                ctx.globalAlpha = 1.0;
                // cap
                ctx.globalAlpha = 0.45;
                ctx.beginPath();
                ctx.arc(20.2, 12, 1.5, -Math.PI / 2.2, Math.PI / 2.2);
                ctx.stroke();
                ctx.globalAlpha = 1.0;
                const w = Math.max(0, Math.min(1, g.value)) * 14.4;
                if (w > 0.6) {
                    rrect(3.1, 9.1, w, 5.8, 1.7);
                    ctx.fill();
                }
                if (g.charging) {
                    // Knock the bolt out of the fill so it reads at any level.
                    ctx.save();
                    ctx.globalCompositeOperation = "destination-out";
                    ctx.beginPath();
                    ctx.moveTo(12.6, 6.4);
                    ctx.lineTo(7.6, 13.2);
                    ctx.lineTo(10.8, 13.2);
                    ctx.lineTo(9.8, 18.6);
                    ctx.lineTo(15.2, 11.2);
                    ctx.lineTo(11.8, 11.2);
                    ctx.closePath();
                    ctx.fill();
                    ctx.restore();
                }
                break;
            }
            case "bolt": {
                ctx.beginPath();
                ctx.moveTo(13.6, 2.4);
                ctx.lineTo(5.4, 13.6);
                ctx.lineTo(10.6, 13.6);
                ctx.lineTo(9.2, 21.6);
                ctx.lineTo(18.2, 10.0);
                ctx.lineTo(12.6, 10.0);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "power": {
                ctx.beginPath();
                ctx.arc(12, 13, 7.4, -Math.PI * 0.36, Math.PI * 1.36);
                ctx.stroke();
                line(12, 3.2, 12, 11.4);
                break;
            }
            case "restart": {
                ctx.beginPath();
                ctx.arc(12, 12, 7.6, Math.PI * 0.42, Math.PI * 2.1);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(12.6, 1.6);
                ctx.lineTo(18.2, 5.0);
                ctx.lineTo(12.6, 8.4);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "moon.zzz":
            case "moon": {
                // Crescent = a disc with a second, offset disc knocked out of it.
                const shrink = (g.name === "moon.zzz") ? 0.82 : 1.0;
                ctx.save();
                ctx.translate(12, 12);
                ctx.scale(shrink, shrink);
                ctx.translate(-12, -12);
                dot(11.0, 12.4, 8.8);
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                dot(16.6, 7.6, 8.6);
                ctx.restore();
                ctx.restore();
                if (g.name === "moon.zzz") {
                    ctx.lineWidth = g.weight * 0.9;
                    ctx.beginPath();
                    ctx.moveTo(16.4, 2.6);
                    ctx.lineTo(21.4, 2.6);
                    ctx.lineTo(16.4, 8.0);
                    ctx.lineTo(21.4, 8.0);
                    ctx.stroke();
                }
                break;
            }
            case "lock":
            case "lock.open": {
                rrect(4.6, 10.4, 14.8, 11.0, 3.2);
                ctx.fill();
                ctx.beginPath();
                if (g.name === "lock")
                    ctx.arc(12, 10.4, 4.4, Math.PI, 2 * Math.PI);
                else
                    ctx.arc(18.4, 10.4, 4.4, Math.PI, Math.PI * 1.5);
                ctx.stroke();
                break;
            }

            // -------------------------------------------------------- audio
            case "speaker":
            case "speaker.slash": {
                ctx.beginPath();
                ctx.moveTo(3.0, 9.4);
                ctx.lineTo(6.4, 9.4);
                ctx.lineTo(11.0, 5.0);
                ctx.lineTo(11.0, 19.0);
                ctx.lineTo(6.4, 14.6);
                ctx.lineTo(3.0, 14.6);
                ctx.closePath();
                ctx.fill();
                if (g.name === "speaker") {
                    const waves = [
                        {
                            r: 3.0,
                            lvl: 1
                        },
                        {
                            r: 5.6,
                            lvl: 2
                        },
                        {
                            r: 8.2,
                            lvl: 3
                        }
                    ];
                    for (const w of waves) {
                        if (g.level < w.lvl)
                            continue;
                        ctx.beginPath();
                        ctx.arc(11.6, 12, w.r, -Math.PI / 3.1, Math.PI / 3.1);
                        ctx.stroke();
                    }
                } else {
                    ctx.lineWidth = g.weight;
                    line(14.6, 9.0, 20.6, 15.0);
                    line(20.6, 9.0, 14.6, 15.0);
                }
                break;
            }
            case "headphones": {
                ctx.beginPath();
                ctx.arc(12, 12, 8.4, Math.PI, 2 * Math.PI);
                ctx.stroke();
                rrect(3.0, 12.0, 4.0, 8.0, 2.0);
                ctx.fill();
                rrect(17.0, 12.0, 4.0, 8.0, 2.0);
                ctx.fill();
                break;
            }
            case "mic": {
                rrect(9.0, 2.6, 6.0, 11.4, 3.0);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(12, 11.6, 7.0, 0, Math.PI);
                ctx.stroke();
                line(12, 18.6, 12, 21.6);
                break;
            }
            case "play.fill": {
                ctx.beginPath();
                ctx.moveTo(6.4, 3.6);
                ctx.lineTo(19.6, 12);
                ctx.lineTo(6.4, 20.4);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "pause.fill": {
                rrect(5.6, 4.0, 4.6, 16.0, 1.6);
                ctx.fill();
                rrect(13.8, 4.0, 4.6, 16.0, 1.6);
                ctx.fill();
                break;
            }
            case "forward.fill":
            case "backward.fill": {
                ctx.save();
                if (g.name === "backward.fill") {
                    ctx.translate(24, 0);
                    ctx.scale(-1, 1);
                }
                ctx.beginPath();
                ctx.moveTo(2.6, 4.6);
                ctx.lineTo(11.4, 12);
                ctx.lineTo(2.6, 19.4);
                ctx.closePath();
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(11.6, 4.6);
                ctx.lineTo(20.4, 12);
                ctx.lineTo(11.6, 19.4);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
                break;
            }

            // ------------------------------------------------------ display
            case "sun.max": {
                dot(12, 12, 4.2);
                ctx.lineWidth = g.weight;
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4;
                    line(12 + Math.cos(a) * 6.6, 12 + Math.sin(a) * 6.6, 12 + Math.cos(a) * 9.4, 12 + Math.sin(a) * 9.4);
                }
                break;
            }
            case "sun.min": {
                dot(12, 12, 4.2);
                ctx.lineWidth = g.weight;
                for (let i = 0; i < 4; i++) {
                    const a = i * Math.PI / 2 + Math.PI / 4;
                    line(12 + Math.cos(a) * 6.4, 12 + Math.sin(a) * 6.4, 12 + Math.cos(a) * 8.4, 12 + Math.sin(a) * 8.4);
                }
                break;
            }
            case "display": {
                rrect(2.2, 3.6, 19.6, 13.4, 2.4);
                ctx.stroke();
                line(8.4, 20.4, 15.6, 20.4);
                line(12, 17.0, 12, 20.4);
                break;
            }
            case "airplay": {
                ctx.beginPath();
                ctx.moveTo(3.0, 5.0);
                ctx.lineTo(21.0, 5.0);
                ctx.lineTo(21.0, 15.0);
                ctx.lineTo(15.6, 15.0);
                ctx.moveTo(8.4, 15.0);
                ctx.lineTo(3.0, 15.0);
                ctx.closePath();
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(12, 13.0);
                ctx.lineTo(18.4, 21.0);
                ctx.lineTo(5.6, 21.0);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "keyboard": {
                rrect(1.8, 5.4, 20.4, 13.2, 2.6);
                ctx.stroke();
                ctx.lineWidth = g.weight * 0.9;
                for (let r = 0; r < 2; r++)
                    for (let c = 0; c < 5; c++)
                        dot(5.2 + c * 3.4, 9.4 + r * 3.2, 0.75);
                line(7.6, 15.6, 16.4, 15.6);
                break;
            }

            // ------------------------------------------------- ui / actions
            case "magnifyingglass": {
                ctx.beginPath();
                ctx.arc(10.6, 10.6, 6.4, 0, 2 * Math.PI);
                ctx.stroke();
                line(15.4, 15.4, 20.6, 20.6);
                break;
            }
            case "controlcenter": {
                // Two stacked switches, as in the macOS menu bar: the upper
                // one on (knob right), the lower one off (knob left).
                //
                // What decides whether this reads at 15px is the gap between
                // the two pills, and the stroke eats into it from both sides:
                // the drawn gap is the distance between the paths minus one
                // whole line width. Keep that difference near 2.3 grid units
                // (~1.4px at menu-bar size) or the pair fuses into one blob.
                // The lighter stroke below buys most of it back, and the pair
                // is centred on the grid so the mark sits on the bar's optical
                // centre rather than riding high.
                const w = 17.0, h = 5.4, r = h / 2, gap = 3.8;
                const x0 = (24 - w) / 2, y0 = (24 - (2 * h + gap)) / 2;
                ctx.lineWidth = g.weight * 0.85;
                for (let i = 0; i < 2; i++) {
                    const y = y0 + r + i * (h + gap);
                    rrect(x0, y - r, w, h, r);
                    ctx.stroke();
                    dot(i === 0 ? x0 + w - r : x0 + r, y, 1.35);
                }
                break;
            }
            case "square.grid.3x3": {
                for (let r = 0; r < 3; r++)
                    for (let c = 0; c < 3; c++) {
                        rrect(3.0 + c * 6.6, 3.0 + r * 6.6, 5.0, 5.0, 1.5);
                        ctx.fill();
                    }
                break;
            }
            case "rectangle.3.group": {
                rrect(2.4, 4.4, 8.6, 6.6, 1.6);
                ctx.fill();
                rrect(13.0, 4.4, 8.6, 6.6, 1.6);
                ctx.fill();
                rrect(2.4, 13.0, 19.2, 6.6, 1.6);
                ctx.fill();
                break;
            }
            case "bell":
            case "bell.slash": {
                ctx.beginPath();
                ctx.moveTo(5.2, 16.4);
                ctx.lineTo(18.8, 16.4);
                ctx.bezierCurveTo(17.2, 15.0, 17.4, 13.4, 17.4, 10.6);
                ctx.bezierCurveTo(17.4, 6.6, 15.0, 4.0, 12.0, 4.0);
                ctx.bezierCurveTo(9.0, 4.0, 6.6, 6.6, 6.6, 10.6);
                ctx.bezierCurveTo(6.6, 13.4, 6.8, 15.0, 5.2, 16.4);
                ctx.closePath();
                ctx.fill();
                ctx.beginPath();
                ctx.arc(12, 18.4, 2.1, 0, Math.PI);
                ctx.fill();
                if (g.name === "bell.slash")
                    slash();
                break;
            }
            case "gear": {
                const teeth = 8;
                ctx.beginPath();
                for (let i = 0; i < teeth * 2; i++) {
                    const a = i * Math.PI / teeth;
                    const r = (i % 2 === 0) ? 9.4 : 7.4;
                    const x = 12 + Math.cos(a) * r, y = 12 + Math.sin(a) * r;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.fill();
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(12, 12, 3.6, 0, 2 * Math.PI);
                ctx.fill();
                ctx.restore();
                break;
            }
            case "checkmark": {
                ctx.lineWidth = g.weight * 1.15;
                ctx.beginPath();
                ctx.moveTo(4.6, 12.6);
                ctx.lineTo(9.6, 17.6);
                ctx.lineTo(19.4, 6.6);
                ctx.stroke();
                break;
            }
            case "xmark": {
                line(5.6, 5.6, 18.4, 18.4);
                line(18.4, 5.6, 5.6, 18.4);
                break;
            }
            case "xmark.circle.fill": {
                dot(12, 12, 9.4);
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                ctx.lineWidth = g.weight * 1.1;
                ctx.strokeStyle = "rgba(0,0,0,1)";
                line(8.6, 8.6, 15.4, 15.4);
                line(15.4, 8.6, 8.6, 15.4);
                ctx.restore();
                break;
            }
            case "plus": {
                line(12, 4.6, 12, 19.4);
                line(4.6, 12, 19.4, 12);
                break;
            }
            case "minus": {
                line(4.6, 12, 19.4, 12);
                break;
            }
            case "chevron.right":
                chevron(13, 12, "right");
                break;
            case "chevron.left":
                chevron(11, 12, "left");
                break;
            case "chevron.down":
                chevron(12, 13, "down");
                break;
            case "chevron.up":
                chevron(12, 11, "up");
                break;
            case "chevron.up.chevron.down": {
                // The indicator inside a macOS pop-up button.
                ctx.lineWidth = g.weight * 1.15;
                ctx.beginPath();
                ctx.moveTo(6.5, 10.0);
                ctx.lineTo(12, 4.6);
                ctx.lineTo(17.5, 10.0);
                ctx.moveTo(6.5, 14.0);
                ctx.lineTo(12, 19.4);
                ctx.lineTo(17.5, 14.0);
                ctx.stroke();
                break;
            }
            case "ellipsis": {
                dot(5.6, 12, 1.7);
                dot(12, 12, 1.7);
                dot(18.4, 12, 1.7);
                break;
            }
            case "circle.fill":
                dot(12, 12, 9.0);
                break;
            case "circle": {
                ctx.beginPath();
                ctx.arc(12, 12, 8.6, 0, 2 * Math.PI);
                ctx.stroke();
                break;
            }
            case "info.circle": {
                ctx.beginPath();
                ctx.arc(12, 12, 9.0, 0, 2 * Math.PI);
                ctx.stroke();
                dot(12, 7.6, 1.15);
                line(12, 10.8, 12, 16.6);
                break;
            }
            case "exclamationmark.triangle": {
                ctx.beginPath();
                ctx.moveTo(12, 3.4);
                ctx.lineTo(22.0, 20.4);
                ctx.lineTo(2.0, 20.4);
                ctx.closePath();
                ctx.stroke();
                line(12, 9.6, 12, 15.0);
                dot(12, 17.6, 1.1);
                break;
            }
            case "arrow.up.left.and.arrow.down.right": {
                ctx.beginPath();
                ctx.moveTo(3.4, 9.4);
                ctx.lineTo(3.4, 3.4);
                ctx.lineTo(9.4, 3.4);
                ctx.moveTo(3.4, 3.4);
                ctx.lineTo(10.4, 10.4);
                ctx.moveTo(20.6, 14.6);
                ctx.lineTo(20.6, 20.6);
                ctx.lineTo(14.6, 20.6);
                ctx.moveTo(20.6, 20.6);
                ctx.lineTo(13.6, 13.6);
                ctx.stroke();
                break;
            }
            case "arrow.right": {
                line(3.6, 12, 20.0, 12);
                chevron(17.4, 12, "right", 4.4);
                break;
            }
            case "arrow.down": {
                line(12, 3.6, 12, 20.0);
                chevron(12, 17.4, "down", 4.4);
                break;
            }

            // ------------------------------------------------------- objects
            case "folder": {
                ctx.beginPath();
                ctx.moveTo(2.4, 7.6);
                ctx.lineTo(2.4, 18.4);
                ctx.lineTo(21.6, 18.4);
                ctx.lineTo(21.6, 8.6);
                ctx.lineTo(11.6, 8.6);
                ctx.lineTo(9.4, 6.0);
                ctx.lineTo(3.4, 6.0);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "trash": {
                rrect(5.4, 6.6, 13.2, 14.4, 2.4);
                ctx.stroke();
                line(3.0, 6.0, 21.0, 6.0);
                ctx.beginPath();
                ctx.moveTo(9.0, 6.0);
                ctx.lineTo(9.6, 3.4);
                ctx.lineTo(14.4, 3.4);
                ctx.lineTo(15.0, 6.0);
                ctx.stroke();
                line(10.0, 10.4, 10.0, 17.2);
                line(14.0, 10.4, 14.0, 17.2);
                break;
            }
            case "clock": {
                ctx.beginPath();
                ctx.arc(12, 12, 9.0, 0, 2 * Math.PI);
                ctx.stroke();
                line(12, 6.4, 12, 12);
                line(12, 12, 16.2, 14.2);
                break;
            }
            case "calendar": {
                rrect(2.6, 4.6, 18.8, 16.8, 3.0);
                ctx.stroke();
                line(2.6, 9.6, 21.4, 9.6);
                line(7.4, 2.4, 7.4, 6.4);
                line(16.6, 2.4, 16.6, 6.4);
                break;
            }
            case "person.crop.circle": {
                ctx.beginPath();
                ctx.arc(12, 12, 9.0, 0, 2 * Math.PI);
                ctx.stroke();
                dot(12, 9.8, 3.0);
                // Shoulders: a filled half-disc, clipped by the outer circle.
                ctx.save();
                ctx.beginPath();
                ctx.arc(12, 12, 8.3, 0, 2 * Math.PI);
                ctx.clip();
                ctx.beginPath();
                ctx.arc(12, 21.0, 6.2, Math.PI, 2 * Math.PI);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
                break;
            }
            case "eye": {
                ctx.beginPath();
                ctx.moveTo(2.0, 12);
                ctx.bezierCurveTo(6.0, 5.6, 18.0, 5.6, 22.0, 12);
                ctx.bezierCurveTo(18.0, 18.4, 6.0, 18.4, 2.0, 12);
                ctx.closePath();
                ctx.stroke();
                dot(12, 12, 2.8);
                break;
            }
            case "camera": {
                rrect(2.2, 6.4, 19.6, 13.2, 3.0);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(12, 13.0, 4.0, 0, 2 * Math.PI);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(8.4, 6.4);
                ctx.lineTo(9.8, 4.0);
                ctx.lineTo(14.2, 4.0);
                ctx.lineTo(15.6, 6.4);
                ctx.stroke();
                break;
            }
            case "star.fill": {
                ctx.beginPath();
                for (let i = 0; i < 10; i++) {
                    const a = -Math.PI / 2 + i * Math.PI / 5;
                    const r = (i % 2 === 0) ? 9.4 : 4.2;
                    const x = 12 + Math.cos(a) * r, y = 12 + Math.sin(a) * r;
                    if (i === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "sidebar": {
                rrect(2.2, 4.4, 19.6, 15.2, 2.6);
                ctx.stroke();
                line(9.0, 4.4, 9.0, 19.6);
                break;
            }
            case "stage": {
                rrect(7.6, 5.4, 14.0, 13.2, 2.4);
                ctx.stroke();
                rrect(2.2, 7.4, 3.6, 3.6, 1.2);
                ctx.fill();
                rrect(2.2, 13.0, 3.6, 3.6, 1.2);
                ctx.fill();
                break;
            }
            case "hand.raised": {
                rrect(9.0, 3.0, 2.6, 10.0, 1.3);
                ctx.fill();
                rrect(12.2, 4.4, 2.6, 8.6, 1.3);
                ctx.fill();
                rrect(5.8, 6.0, 2.6, 7.4, 1.3);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(5.4, 11.0);
                ctx.bezierCurveTo(3.2, 12.4, 4.2, 15.6, 6.2, 17.6);
                ctx.bezierCurveTo(8.6, 20.0, 10.4, 21.2, 13.4, 21.2);
                ctx.bezierCurveTo(17.4, 21.2, 18.6, 17.6, 18.6, 13.4);
                ctx.lineTo(18.6, 8.4);
                ctx.bezierCurveTo(18.6, 6.4, 15.6, 6.4, 15.6, 8.4);
                ctx.lineTo(15.6, 13.0);
                ctx.lineTo(5.4, 11.0);
                ctx.closePath();
                ctx.fill();
                break;
            }
            case "apple": {
                // The Apple mark, drawn from its silhouette so no font is needed.
                // Authored on a wider grid, then fitted back into the 24 box.
                ctx.save();
                ctx.translate(3.2, 1.0);
                ctx.scale(0.92, 0.92);
                ctx.beginPath();
                ctx.moveTo(15.4, 2.2);
                ctx.bezierCurveTo(15.5, 3.5, 15.0, 4.8, 14.2, 5.7);
                ctx.bezierCurveTo(13.4, 6.7, 12.1, 7.4, 10.9, 7.3);
                ctx.bezierCurveTo(10.8, 6.0, 11.4, 4.7, 12.1, 3.8);
                ctx.bezierCurveTo(13.0, 2.8, 14.4, 2.2, 15.4, 2.2);
                ctx.closePath();
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(19.6, 16.6);
                ctx.bezierCurveTo(19.0, 18.0, 18.7, 18.6, 17.9, 19.8);
                ctx.bezierCurveTo(16.8, 21.5, 15.2, 23.6, 13.3, 23.6);
                ctx.bezierCurveTo(11.6, 23.6, 11.2, 22.5, 8.9, 22.5);
                ctx.bezierCurveTo(6.7, 22.5, 6.2, 23.6, 4.6, 23.6);
                ctx.bezierCurveTo(2.6, 23.6, 1.2, 21.7, 0.1, 20.0);
                ctx.bezierCurveTo(-1.7, 17.1, -1.9, 12.0, 0.4, 9.2);
                ctx.bezierCurveTo(1.4, 7.9, 3.0, 7.1, 4.6, 7.1);
                ctx.bezierCurveTo(6.3, 7.1, 7.3, 8.0, 8.9, 8.0);
                ctx.bezierCurveTo(10.4, 8.0, 11.3, 7.1, 13.3, 7.1);
                ctx.bezierCurveTo(14.7, 7.1, 16.3, 7.9, 17.4, 9.3);
                ctx.bezierCurveTo(13.7, 11.4, 14.3, 16.8, 19.6, 16.6);
                ctx.closePath();
                ctx.fill();
                ctx.restore();
                break;
            }

            default:
                break;
            }

            ctx.restore();
        }
    }
}
