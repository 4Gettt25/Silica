import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../../common"

// The Control Center "Now Playing" group.
//
// Media comes from the MPRIS service (Mpris.players is an ObjectModel, so the
// live list is `Mpris.players.values`) — playerctl is not required and is not
// used. The whole group hides itself when no player is on the bus.
CcGroup {
    id: root

    padding: Theme.space2

    // Prefer whichever player is actually playing; otherwise the first one that
    // can be controlled, so a paused Spotify still shows its track.
    readonly property var players: Mpris.players ? Mpris.players.values : []
    readonly property MprisPlayer player: {
        const ps = root.players;
        for (const p of ps)
            if (p.isPlaying)
                return p;
        return ps.length > 0 ? ps[0] : null;
    }

    readonly property bool hasPlayer: root.player !== null
    readonly property string artUrl: root.hasPlayer ? root.player.trackArtUrl : ""

    visible: root.hasPlayer

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        // ---- album art (with a music-note tile as the fallback) ----
        Rectangle {
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            Layout.alignment: Qt.AlignVCenter
            radius: Theme.radiusControl
            antialiasing: true
            clip: true
            color: Theme.fill

            CcNoteGlyph {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                size: 22
                color: Theme.secondaryLabel
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.artUrl
                asynchronous: true
                cache: true
                smooth: true
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
        }

        // ---- title / artist ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                role: "headline"
                text: root.hasPlayer ? (root.player.trackTitle !== "" ? root.player.trackTitle : root.player.identity) : ""
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                role: "caption"
                color: Theme.secondaryLabel
                text: root.hasPlayer ? root.player.trackArtist : ""
                visible: text !== ""
                elide: Text.ElideRight
            }
        }

        // ---- transport ----
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            TransportButton {
                glyph: "backward.fill"
                interactive: root.hasPlayer && root.player.canGoPrevious
                onClicked: root.player.previous()
            }

            TransportButton {
                glyph: (root.hasPlayer && root.player.isPlaying) ? "pause.fill" : "play.fill"
                size: 22
                interactive: root.hasPlayer && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }

            TransportButton {
                glyph: "forward.fill"
                interactive: root.hasPlayer && root.player.canGoNext
                onClicked: root.player.next()
            }
        }
    }

    // A borderless round transport button; macOS draws these as bare glyphs
    // that only pick up a hover wash.
    component TransportButton: Item {
        id: btn

        property string glyph: ""
        property real size: 18
        property bool interactive: true

        signal clicked

        implicitWidth: 28
        implicitHeight: 28
        opacity: btn.interactive ? 1 : 0.35

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            antialiasing: true
            color: (area.containsMouse && btn.interactive) ? Theme.hover : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.durInstant
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: btn.glyph
            size: btn.size
            color: Theme.label
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.interactive
            onClicked: btn.clicked()
        }
    }
}
