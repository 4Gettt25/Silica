import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../common"

// One line of the Spotlight results list: either a section header or a
// selectable result. Section headers are laid out by the same delegate so the
// list stays a single flat model (see SearchModel.rows).
Item {
    id: rowRoot

    property var row: null
    property bool selected: false
    // Injected by SpotlightWindow so the delegate can resolve icons.
    property var search: null

    readonly property bool isHeader: !!row && row.kind === "header"
    // Header rows carry no `name`; every binding below reads these guards.
    readonly property string rowName: (!!row && row.name !== undefined) ? row.name : ""
    readonly property bool isTopHit: !!row && row.topHit === true

    signal clicked
    signal hovered

    // macOS: headers are short, the Top Hit row is taller than the rest.
    implicitHeight: isHeader ? 24 : (isTopHit ? 50 : 40)
    height: implicitHeight

    // ------------------------------------------------------------- header
    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space3
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        visible: rowRoot.isHeader
        role: "caption"
        color: Theme.tertiaryLabel
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        text: rowRoot.isHeader ? row.title : ""
    }

    // --------------------------------------------------------------- item
    Item {
        anchors.fill: parent
        visible: !rowRoot.isHeader

        // Selection fill is inset from the list edges, like a macOS source list.
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: Theme.space2
            anchors.rightMargin: Theme.space2
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            radius: Theme.radiusControl
            antialiasing: true
            color: rowRoot.selected ? Theme.selection : "transparent"
        }

        Item {
            id: iconBox
            anchors.left: parent.left
            anchors.leftMargin: Theme.space4
            anchors.verticalCenter: parent.verticalCenter
            width: rowRoot.isTopHit ? 36 : 22
            height: width

            readonly property string path: rowRoot.search ? rowRoot.search.rowIconPath(rowRoot.row) : ""
            readonly property bool isApp: !!rowRoot.row && rowRoot.row.kind === "app"

            IconImage {
                anchors.fill: parent
                visible: iconBox.path.length > 0
                source: iconBox.path
                implicitSize: iconBox.width
                mipmap: true
                asynchronous: true
            }

            // App with no themed icon: the shell's initial-tile fallback.
            Rectangle {
                anchors.fill: parent
                visible: iconBox.isApp && iconBox.path.length === 0
                radius: Theme.iconRadius(width)
                color: rowRoot.search && rowRoot.row ? rowRoot.search.tileColor(rowRoot.rowName) : Theme.fill

                StyledText {
                    anchors.centerIn: parent
                    role: "caption"
                    font.pixelSize: Math.round(parent.width * 0.5)
                    font.weight: Theme.wBold
                    color: Theme.alwaysLight
                    text: rowRoot.rowName.length > 0 ? rowRoot.rowName.charAt(0).toUpperCase() : "?"
                }
            }

            // Calculator / web / shell rows get a symbol tile instead.
            Rectangle {
                anchors.fill: parent
                visible: !iconBox.isApp
                radius: Theme.iconRadius(width)
                color: rowRoot.selected ? Theme.alpha(Theme.alwaysLight, 0.22) : Theme.fill

                Glyph {
                    anchors.centerIn: parent
                    visible: !!rowRoot.row && rowRoot.row.kind === "web"
                    name: "network"
                    size: Math.round(parent.width * 0.68)
                    color: rowRoot.selected ? Theme.onSelection : Theme.secondaryLabel
                }

                LauncherGlyph {
                    anchors.centerIn: parent
                    visible: !!rowRoot.row && (rowRoot.row.kind === "calc" || rowRoot.row.kind === "run")
                    name: !!rowRoot.row && rowRoot.row.kind === "calc" ? "equal" : "terminal"
                    size: Math.round(parent.width * 0.68)
                    color: rowRoot.selected ? Theme.onSelection : Theme.secondaryLabel
                }
            }
        }

        Column {
            anchors.left: iconBox.right
            anchors.leftMargin: Theme.space3
            anchors.right: parent.right
            anchors.rightMargin: Theme.space4
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            StyledText {
                width: parent.width
                role: rowRoot.isTopHit ? "title3" : "body"
                color: rowRoot.selected ? Theme.onSelection : Theme.label
                text: rowRoot.rowName
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: rowRoot.isTopHit
                role: "footnote"
                color: rowRoot.selected ? Theme.alpha(Theme.onSelection, 0.75) : Theme.secondaryLabel
                text: rowRoot.row && rowRoot.isTopHit ? rowRoot.row.subtitle : ""
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: rowRoot.hovered()
            onEntered: rowRoot.hovered()
            onClicked: rowRoot.clicked()
        }
    }
}
