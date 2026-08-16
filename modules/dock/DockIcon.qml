import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../../common"

// One cell of the dock: an app icon with macOS magnification, a running
// indicator, a hover tooltip and the launch bounce — or, when the model row is
// a `{ kind: "sep" }`, the hairline that divides the dock's three groups.
//
// Magnification is computed against the RESTING layout (dock.restCenters), not
// against the animated one, so growing an icon can never feed back into the
// distance that decided how much it should grow. Dock.qml inverts the mapping
// once per pointer move and publishes the result as `dock.hoverU`, a coordinate
// in that same resting space.
Item {
    id: cell

    // Injected by the Repeater in Dock.qml.
    required property int index
    required property var modelData
    // The Dock scope root: metrics, hover state and the shared DockApps model.
    property var dock: null

    readonly property bool isSep: modelData.kind === "sep"
    readonly property bool vertical: dock.vertical
    readonly property real base: dock.base
    readonly property real peak: dock.peak

    readonly property real restCenter: dock.restCenters[index] !== undefined ? dock.restCenters[index] : 0
    readonly property real restLen: dock.restLen(modelData)
    readonly property real dist: Math.abs(dock.hoverU - restCenter)

    // Raised cosine falloff over ±magRadius (≈2.5 icon widths): 1 under the
    // pointer, 0 at the edge, and flat at both ends so the growth has no
    // visible corner — this is what makes the scrub feel liquid rather than
    // steppy.
    readonly property real falloff: (!dock.magnifyOn || isSep || dist >= dock.magRadius) ? 0 : 0.5 * (Math.cos(Math.PI * dist / dock.magRadius) + 1)

    // The single animated quantity: the cell's layout size AND the icon's
    // visual scale are both derived from it, so they can never drift apart.
    property real mag: 1 + (peak / base - 1) * falloff
    Behavior on mag {
        NumberAnimation {
            duration: Theme.durInstant
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    readonly property real iconSize: base * mag
    readonly property real cellLen: isSep ? dock.sepLen : (iconSize + dock.gap)

    implicitWidth: vertical ? dock.pillThickness : cellLen
    implicitHeight: vertical ? cellLen : dock.pillThickness
    width: implicitWidth
    height: implicitHeight
    // The most-magnified icon (and its tooltip) paints above its neighbours.
    z: mag

    readonly property bool hovered: dock.hoverIndex === index && !isSep
    readonly property var windows: isSep ? [] : dock.apps.toplevelsFor(modelData)
    readonly property bool running: windows.length > 0
    readonly property bool useImage: !isSep && String(modelData.iconPath).length > 0

    // -------------------------------------------------------- launch bounce
    property real bounceOffset: 0
    readonly property bool bouncing: !isSep && dock.apps.bounceKey === modelData.key

    // The bounce stops the moment the app maps its first window (macOS does
    // exactly this) — the backstop timer in DockApps handles apps that never do.
    onRunningChanged: if (running && bouncing) dock.apps.bounceKey = ""

    SequentialAnimation {
        running: cell.bouncing
        loops: 2
        alwaysRunToEnd: false
        onStopped: cell.bounceOffset = 0

        NumberAnimation {
            target: cell
            property: "bounceOffset"
            from: 0
            to: cell.base * 0.55
            duration: Theme.durSlow / 2
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: cell
            property: "bounceOffset"
            to: 0
            duration: Theme.durSlow / 2
            easing.type: Easing.InQuad
        }
    }

    // ------------------------------------------------------------- geometry
    // Icons rest against the pill's inner edge and grow away from it, so the
    // transform origin is the edge the dock is docked to.
    readonly property int visOrigin: {
        switch (dock.edge) {
        case "left":
            return Item.Left;
        case "right":
            return Item.Right;
        default:
            return Item.Bottom;
        }
    }
    // Position of the peak-sized artwork; `scale` shrinks it to iconSize.
    readonly property real visX: {
        switch (dock.edge) {
        case "left":
            return dock.dotBand + bounceOffset;
        case "right":
            return width - dock.dotBand - peak - bounceOffset;
        default:
            return (width - peak) / 2;
        }
    }
    readonly property real visY: vertical ? (height - peak) / 2 : (height - dock.dotBand - peak - bounceOffset)
    readonly property real visScale: iconSize / peak

    // ------------------------------------------------------------ separator
    Rectangle {
        visible: cell.isSep
        anchors.centerIn: parent
        width: cell.vertical ? cell.base * 0.55 : 1
        height: cell.vertical ? 1 : cell.base * 0.55
        color: Theme.separator
    }

    // ------------------------------------------------- themed icon artwork
    // Rendered once at the magnification peak into a layer, then scaled down:
    // the texture stays crisp at full magnification and the drop shadow tracks
    // the icon's real silhouette instead of a bounding box.
    Item {
        id: art
        width: cell.peak
        height: cell.peak
        visible: false
        layer.enabled: cell.useImage
        layer.smooth: true

        IconImage {
            anchors.fill: parent
            source: cell.useImage ? cell.modelData.iconPath : ""
            implicitSize: Math.round(cell.peak)
            mipmap: true
            asynchronous: true
        }
    }

    MultiEffect {
        visible: cell.useImage
        source: art
        x: cell.visX
        y: cell.visY
        width: cell.peak
        height: cell.peak
        scale: cell.visScale
        transformOrigin: cell.visOrigin
        shadowEnabled: true
        shadowColor: Theme.shadowColor
        shadowBlur: 0.5
        blurMax: Theme.space4
        shadowVerticalOffset: Theme.space1 / 2
        shadowOpacity: 0.7
    }

    // ------------------------------------------- drawn tile (fallback / ours)
    // Launchpad, Trash and any app whose icon is missing from the theme get a
    // macOS-style squircle tile. Drawn live (not through a layer) because a
    // Canvas-based Glyph does not paint inside an invisible layered item.
    Item {
        id: tile
        visible: !cell.useImage && !cell.isSep
        x: cell.visX
        y: cell.visY
        width: cell.peak
        height: cell.peak
        scale: cell.visScale
        transformOrigin: cell.visOrigin

        Shadow {
            anchors.fill: parent
            radius: Theme.iconRadius(cell.peak)
            blur: Theme.space3
            offsetY: Theme.space1 / 2
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.iconRadius(cell.peak)
            antialiasing: true
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.lighter(cell.tileColor, 1.18)
                }
                GradientStop {
                    position: 1
                    color: cell.tileColor
                }
            }

            Glyph {
                anchors.centerIn: parent
                visible: String(cell.modelData.glyph ?? "").length > 0
                name: cell.modelData.glyph ?? ""
                size: Math.round(cell.peak * 0.52)
                color: Theme.alwaysLight
                weight: 1.6
            }

            StyledText {
                anchors.centerIn: parent
                visible: String(cell.modelData.glyph ?? "").length === 0
                text: String(cell.modelData.name ?? "?").charAt(0).toUpperCase()
                color: Theme.alwaysLight
                font.pixelSize: Math.round(cell.peak * 0.44)
                font.weight: Theme.wSemibold
            }
        }
    }

    // Deterministic tile colour per app; the two stacks and Launchpad get the
    // neutral system gray macOS uses for its own tiles.
    readonly property color tileColor: {
        if (isSep)
            return "transparent";
        if (modelData.special !== "")
            return Theme.gray;
        let h = 0;
        const n = String(modelData.name ?? "");
        for (let i = 0; i < n.length; i++)
            h = (h * 31 + n.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360.0, 0.5, Theme.dark ? 0.45 : 0.55, 1.0);
    }

    // -------------------------------------------------- running indicator
    Rectangle {
        visible: cell.running && !cell.isSep
        width: dock.dotSize
        height: dock.dotSize
        radius: width / 2
        antialiasing: true
        color: Theme.alpha(Theme.label, 0.55)
        x: {
            switch (dock.edge) {
            case "left":
                return (dock.dotBand - width) / 2;
            case "right":
                return cell.width - dock.dotBand + (dock.dotBand - width) / 2;
            default:
                return (cell.width - width) / 2;
            }
        }
        y: cell.vertical ? (cell.height - height) / 2 : cell.height - (dock.dotBand + height) / 2
    }

    // ------------------------------------------------------------- tooltip
    // Shown after a short dwell, floating above the magnified icon. It lives
    // outside the pill (the dock window is deliberately taller than the pill)
    // and is never interactive, so the window mask ignores it.
    property bool tipShown: false

    Timer {
        id: tipTimer
        interval: Theme.durSlow
        onTriggered: cell.tipShown = true
    }

    onHoveredChanged: {
        if (hovered && !isSep) {
            tipTimer.restart();
        } else {
            tipTimer.stop();
            tipShown = false;
        }
    }

    Item {
        id: tip
        visible: cell.tipShown && cell.opacity > 0
        opacity: cell.tipShown ? 1 : 0
        width: tipLabel.implicitWidth + Theme.space3 * 2
        height: tipLabel.implicitHeight + Theme.space1 * 2
        x: cell.vertical ? (dock.edge === "left" ? cell.width + Theme.space2 : -width - Theme.space2) : (cell.width - width) / 2
        y: cell.vertical ? (cell.height - height) / 2 : cell.visY + cell.peak * (1 - cell.visScale) - height - Theme.space2

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durFast
            }
        }

        Shadow {
            anchors.fill: parent
            radius: parent.height / 2
            blur: Theme.space4
            offsetY: Theme.space1 / 2
        }

        Vibrancy {
            anchors.fill: parent
            material: "tooltip"
            radius: parent.height / 2
        }

        StyledText {
            id: tipLabel
            anchors.centerIn: parent
            role: "callout"
            text: String(cell.modelData.name ?? "")
        }
    }

    // ------------------------------------------------------ downloads stack
    // The fan/grid preview of the newest files, loaded only while hovered.
    Loader {
        active: !cell.isSep && cell.modelData.special === "downloads" && cell.hovered
        visible: active
        x: cell.vertical ? (dock.edge === "left" ? cell.width + Theme.space2 : -width - Theme.space2) : (cell.width - width) / 2
        y: cell.vertical ? Math.max(-cell.y, -height / 2) : cell.visY + cell.peak * (1 - cell.visScale) - height - Theme.space2

        // The listing is only a few names, so re-read it every time the stack
        // opens rather than watching the directory.
        onActiveChanged: if (active)
            cell.dock.apps.refreshDownloads()

        sourceComponent: Stack {
            files: cell.dock.apps.downloadFiles
            directory: cell.dock.apps.downloadsDir
            tileSize: Math.round(cell.base * 0.72)
        }
    }
}
