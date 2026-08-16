import QtQuick

// Text with the shell's type system applied.
//
// Pick a macOS text style with `role` instead of setting font sizes by hand:
//
//   StyledText { role: "headline"; text: "Wi-Fi" }
//   StyledText { role: "footnote"; color: Theme.secondaryLabel; text: "Not Connected" }
//
// Every role maps to one of the HIG text styles in Theme (largeTitle, title1,
// title2, title3, headline, body, callout, subheadline, footnote, caption).
Text {
    id: root

    property string role: "body"

    font.family: Theme.fontFamily
    font.pixelSize: {
        switch (role) {
        case "largeTitle":
            return Theme.fsLargeTitle;
        case "title1":
            return Theme.fsTitle1;
        case "title2":
            return Theme.fsTitle2;
        case "title3":
            return Theme.fsTitle3;
        case "headline":
            return Theme.fsHeadline;
        case "callout":
            return Theme.fsCallout;
        case "subheadline":
            return Theme.fsSubheadline;
        case "footnote":
            return Theme.fsFootnote;
        case "caption":
            return Theme.fsCaption;
        case "bar":
            // Menu bar text follows the menu bar size setting.
            return Theme.barFontSize;
        default:
            return Theme.fsBody;
        }
    }
    font.weight: {
        switch (role) {
        case "largeTitle":
        case "title1":
        case "title2":
            return Theme.wSemibold;
        case "title3":
        case "headline":
            return Theme.wSemibold;
        case "caption":
            return Theme.wMedium;
        default:
            return Theme.wRegular;
        }
    }
    // macOS tightens tracking as type gets larger. (Derived from `role`, not
    // from font.pixelSize — reading one part of the font group inside another
    // binding of the same group is a binding loop.)
    font.letterSpacing: {
        switch (role) {
        case "largeTitle":
        case "title1":
            return -0.4;
        case "title2":
        case "title3":
            return -0.2;
        default:
            return 0;
        }
    }
    color: Theme.label
    renderType: Text.NativeRendering
    textFormat: Text.PlainText
}
