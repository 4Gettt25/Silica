import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../common"

// The right-hand pane of the Spotlight card: a big icon, the name, the kind
// and a few metadata rows for whatever is selected — plus the "↵ to open"
// hint macOS puts at the bottom.
Item {
    id: pane

    property var row: null
    property var search: null

    // Header rows carry no `name`, and `row` may be null between searches.
    readonly property string rowName: (!!row && row.name !== undefined) ? row.name : ""

    readonly property string kind: {
        if (!row)
            return "";
        switch (row.kind) {
        case "calc":
            return "Calculator";
        case "web":
            return "Web Search";
        case "run":
            return "Shell Command";
        default:
            return "Application";
        }
    }

    readonly property string title: {
        if (!row)
            return "";
        switch (row.kind) {
        case "calc":
            return row.value;
        case "web":
            return row.term;
        case "run":
            return row.command;
        default:
            return pane.rowName;
        }
    }

    readonly property string hint: {
        if (!row)
            return "";
        switch (row.kind) {
        case "calc":
            return "to copy the result";
        case "web":
            return "to search the web";
        case "run":
            return "to run the command";
        default:
            return "to open";
        }
    }

    // [label, value] pairs; empty values are dropped.
    readonly property var metadata: {
        if (!row)
            return [];
        const out = [];
        if (row.kind === "app") {
            const entry = row.entry;
            const comment = entry.comment || entry.genericName || "";
            if (comment.length > 0)
                out.push(["Description", comment]);
            const exec = (entry.execString || "").trim();
            if (exec.length > 0)
                out.push(["Command", exec]);
            const categories = entry.categories || [];
            if (categories.length > 0)
                out.push(["Categories", categories.join(", ")]);
        } else if (row.kind === "calc") {
            out.push(["Expression", row.expr]);
            out.push(["Result", row.value]);
        } else if (row.kind === "web") {
            out.push(["Query", row.term]);
            out.push(["Engine", "DuckDuckGo"]);
        } else if (row.kind === "run") {
            out.push(["Command", row.command]);
        }
        return out;
    }

    readonly property int iconSize: 96

    implicitHeight: header.implicitHeight + Theme.space5 * 2 + metaColumn.implicitHeight + Theme.space5 + hintRow.implicitHeight + Theme.space4

    Column {
        id: header
        anchors.top: parent.top
        anchors.topMargin: Theme.space5
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space5
        spacing: Theme.space2

        Item {
            id: iconBox
            width: pane.iconSize
            height: pane.iconSize
            anchors.horizontalCenter: parent.horizontalCenter

            readonly property string path: pane.search ? pane.search.rowIconPath(pane.row) : ""
            readonly property bool isApp: !!pane.row && pane.row.kind === "app"

            IconImage {
                anchors.fill: parent
                visible: iconBox.path.length > 0
                source: iconBox.path
                implicitSize: pane.iconSize
                mipmap: true
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                visible: iconBox.isApp && iconBox.path.length === 0
                radius: Theme.iconRadius(width)
                color: pane.search && pane.row ? pane.search.tileColor(pane.rowName) : Theme.fill

                StyledText {
                    anchors.centerIn: parent
                    role: "largeTitle"
                    font.pixelSize: Math.round(parent.width * 0.45)
                    font.weight: Theme.wBold
                    color: Theme.alwaysLight
                    text: pane.rowName.length > 0 ? pane.rowName.charAt(0).toUpperCase() : "?"
                }
            }

            Rectangle {
                anchors.fill: parent
                visible: !iconBox.isApp
                radius: Theme.iconRadius(width)
                color: Theme.fill

                Glyph {
                    anchors.centerIn: parent
                    visible: !!pane.row && pane.row.kind === "web"
                    name: "network"
                    size: Math.round(parent.width * 0.5)
                    color: Theme.secondaryLabel
                    weight: 1.4
                }

                LauncherGlyph {
                    anchors.centerIn: parent
                    visible: !!pane.row && (pane.row.kind === "calc" || pane.row.kind === "run")
                    name: !!pane.row && pane.row.kind === "calc" ? "equal" : "terminal"
                    size: Math.round(parent.width * 0.5)
                    color: Theme.secondaryLabel
                    weight: 1.4
                }
            }
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "title2"
            text: pane.title
            elide: Text.ElideMiddle
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            role: "footnote"
            color: Theme.secondaryLabel
            text: pane.kind
        }
    }

    Column {
        id: metaColumn
        anchors.top: header.bottom
        anchors.topMargin: Theme.space5
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.space5
        anchors.rightMargin: Theme.space5
        spacing: 0

        Repeater {
            model: pane.metadata

            delegate: Item {
                id: metaRow
                required property var modelData
                required property int index

                width: metaColumn.width
                implicitHeight: valueText.implicitHeight + Theme.space2 * 2
                height: implicitHeight

                Rectangle {
                    anchors.top: parent.top
                    width: parent.width
                    height: 1
                    color: Theme.separator
                    visible: metaRow.index > 0
                }

                StyledText {
                    id: labelText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(parent.width * 0.32)
                    role: "footnote"
                    color: Theme.tertiaryLabel
                    text: metaRow.modelData[0]
                    elide: Text.ElideRight
                }

                StyledText {
                    id: valueText
                    anchors.left: labelText.right
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    role: "footnote"
                    color: Theme.secondaryLabel
                    text: metaRow.modelData[1]
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    // "↵ to open"
    Row {
        id: hintRow
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space4
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.space2
        visible: !!pane.row

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 18
            radius: Theme.radiusControl - 2
            color: Theme.fill

            LauncherGlyph {
                anchors.centerIn: parent
                name: "return"
                size: 13
                weight: 1.6
                color: Theme.secondaryLabel
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            role: "footnote"
            color: Theme.tertiaryLabel
            text: pane.hint
        }
    }
}
