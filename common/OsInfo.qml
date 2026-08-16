pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What operating system this is.
//
// Read once at startup from /etc/os-release (plus a small search for the
// distribution's logo, which lives in a different place on every distro). Used
// by the menu bar — the leftmost title can show this machine's logo instead of
// the Apple mark — and by the About pane.
Singleton {
    id: root

    property string prettyName: ""
    property string name: ""
    property string id: ""
    // Absolute path of the distribution logo, or "" when none was found.
    property string logoFile: ""
    property string kernel: ""

    // A file:// url for Image.source, empty when there is no logo to show.
    readonly property string logoSource: logoFile === "" ? "" : "file://" + logoFile

    Process {
        running: true
        // One shot, five lines out: pretty name, name, id, logo path, kernel.
        // The logo search follows the freedesktop LOGO= key first, then the
        // distribution id, across the two directories logos actually live in.
        command: ["sh", "-c", `. /etc/os-release 2>/dev/null
printf '%s\\n%s\\n%s\\n' "\${PRETTY_NAME:-Linux}" "\${NAME:-Linux}" "\${ID:-linux}"
found=""
for n in "\${LOGO:-}" "\${LOGO:-}-logo" "\${ID:-}-logo" "\${ID:-}" distributor-logo; do
    [ -n "$n" ] || continue
    for d in /usr/share/pixmaps /usr/share/icons/hicolor/scalable/apps /usr/share/icons/hicolor/256x256/apps; do
        for e in svg png; do
            if [ -f "$d/$n.$e" ]; then found="$d/$n.$e"; break 3; fi
        done
    done
done
printf '%s\\n' "$found"
uname -r`]

        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n");
                root.prettyName = (l[0] || "").trim();
                root.name = (l[1] || "").trim();
                root.id = (l[2] || "").trim();
                root.logoFile = (l[3] || "").trim();
                root.kernel = (l[4] || "").trim();
            }
        }
    }
}
