import QtQuick

// A macOS menu: the white/dark vibrant card with highlighted rows, a
// checkmark gutter, right-aligned shortcuts and submenu chevrons.
//
// It is a plain Item — the caller owns the window it lives in and where it is
// placed. Used by the menu bar, the Apple menu, dock context menus and the
// desktop menu.
//
// Model: an array of plain objects
//   { text, icon?, shortcut?, checked?, enabled?, destructive?, action?,
//     separator?: true, header?: true, submenu?: [ ...same... ] }
Item {
    id: root

    property var items: []
    property var screenRef: null
    property bool shown: true
    // Minimum card width; the card grows to fit its widest row.
    property int minWidth: 180
    property int rowHeight: 22
    property int separatorHeight: 8
    // Keyboard selection (-1 = nothing selected).
    property int selectedIndex: -1

    signal activated(var entry)
    signal dismissed

    readonly property int _hPad: 10
    readonly property int _gutter: 18
    readonly property int _vPad: 5

    // ---- measurement -----------------------------------------------------
    // Rows must all be the same width, so measure the widest label + shortcut
    // once, imperatively (a binding that writes to TextMetrics would loop).
    property int contentWidth: minWidth

    function remeasure() {
        let w = 0;
        for (const e of items) {
            if (e.separator === true)
                continue;
            labelMetrics.text = e.text ?? "";
            let row = labelMetrics.advanceWidth;
            if (e.shortcut) {
                shortcutMetrics.text = e.shortcut;
                row += 22 + shortcutMetrics.advanceWidth;
            }
            if (e.submenu)
                row += 18;
            w = Math.max(w, Math.ceil(row));
        }
        contentWidth = Math.max(minWidth, w + _gutter + _hPad * 2 + 8);
    }

    onItemsChanged: remeasure()
    Component.onCompleted: remeasure()
    onShownChanged: if (shown) remeasure()

    TextMetrics {
        id: labelMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsBody
    }
    TextMetrics {
        id: shortcutMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsBody
    }

    implicitWidth: contentWidth
    implicitHeight: column.implicitHeight + _vPad * 2
    width: implicitWidth
    height: implicitHeight

    // ---- keyboard navigation --------------------------------------------
    function _selectable(i) {
        const e = items[i];
        return e && e.separator !== true && e.header !== true && e.enabled !== false;
    }

    function moveSelection(delta) {
        if (items.length === 0)
            return;
        let i = selectedIndex;
        for (let n = 0; n < items.length; n++) {
            i += delta;
            if (i < 0)
                i = items.length - 1;
            if (i >= items.length)
                i = 0;
            if (_selectable(i)) {
                selectedIndex = i;
                return;
            }
        }
    }

    function activateSelected() {
        if (selectedIndex >= 0 && _selectable(selectedIndex))
            root.activated(items[selectedIndex]);
    }

    // ---- card ------------------------------------------------------------
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    transformOrigin: Item.Top
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durInstant
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durInstant
            easing.type: Theme.easingType
            easing.bezierCurve: Theme.easeOut
        }
    }

    Shadow {
        anchors.fill: parent
        radius: Theme.radiusMenu
        blur: 24
        offsetY: 4
    }

    Vibrancy {
        anchors.fill: parent
        material: "menu"
        radius: Theme.radiusMenu
    }

    Column {
        id: column
        x: 0
        y: root._vPad
        width: parent.width

        Repeater {
            model: root.items

            delegate: Loader {
                id: rowLoader
                required property var modelData
                required property int index

                width: column.width
                readonly property bool isSeparator: modelData.separator === true
                readonly property bool isHeader: modelData.header === true
                height: isSeparator ? root.separatorHeight : root.rowHeight
                sourceComponent: isSeparator ? separatorComponent : rowComponent
            }
        }
    }

    Component {
        id: separatorComponent
        Item {
            implicitHeight: root.separatorHeight
            implicitWidth: root.contentWidth

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 1
                color: Theme.separator
            }
        }
    }

    Component {
        id: rowComponent

        Item {
            id: row
            implicitHeight: root.rowHeight
            implicitWidth: root.contentWidth

            // `modelData` and `index` resolve through the Loader's context.
            readonly property bool rowEnabled: modelData.enabled !== false && modelData.header !== true
            readonly property bool highlighted: rowEnabled && (mouse.containsMouse || root.selectedIndex === index)
            readonly property color ink: !rowEnabled ? Theme.tertiaryLabel : (highlighted ? Theme.onSelection : (modelData.destructive === true ? Theme.red : Theme.label))

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                radius: 4
                antialiasing: true
                color: row.highlighted ? Theme.selection : "transparent"
            }

            Glyph {
                id: check
                anchors.verticalCenter: parent.verticalCenter
                x: root._hPad
                size: 12
                name: modelData.checked === true ? "checkmark" : ""
                color: row.ink
                weight: 2.4
            }

            Glyph {
                id: leadingIcon
                anchors.verticalCenter: parent.verticalCenter
                x: root._hPad
                size: 14
                visible: modelData.checked === undefined && (modelData.icon || "") !== ""
                name: modelData.icon || ""
                color: row.ink
            }

            StyledText {
                id: rowLabel
                anchors.verticalCenter: parent.verticalCenter
                x: root._hPad + root._gutter
                width: parent.width - x - root._hPad - (shortcutLabel.visible ? shortcutLabel.width + 14 : 0) - (submenuChevron.visible ? 16 : 0)
                text: modelData.text ?? ""
                role: modelData.header === true ? "caption" : "body"
                color: modelData.header === true ? Theme.tertiaryLabel : row.ink
                elide: Text.ElideRight
            }

            StyledText {
                id: shortcutLabel
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root._hPad + (submenuChevron.visible ? 14 : 0)
                visible: (modelData.shortcut || "") !== ""
                text: modelData.shortcut || ""
                color: row.highlighted ? Theme.onSelection : Theme.tertiaryLabel
            }

            Glyph {
                id: submenuChevron
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: root._hPad - 4
                visible: modelData.submenu !== undefined
                size: 11
                name: "chevron.right"
                color: row.ink
                weight: 2.2
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.rowEnabled
                onEntered: root.selectedIndex = index
                onClicked: root.activated(modelData)
            }
        }
    }
}
