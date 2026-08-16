import QtQuick
import Quickshell

// Everything Spotlight knows how to find, as one flat row list.
//
// `rows` is a binding: reading DesktopEntries.applications.values inside
// build() registers the dependency, so the list also refreshes when a .desktop
// file appears or disappears while the window is open.
//
// Row shapes (every row has `kind`):
//   { kind: "header",  title }
//   { kind: "app",     entry, name, subtitle, iconName, topHit }
//   { kind: "calc",    name, expr, value, subtitle }
//   { kind: "web",     name, term, subtitle }
//   { kind: "run",     name, command, subtitle }
// Header rows are not selectable; SpotlightWindow skips them when moving.
QtObject {
    id: model

    property string query: ""
    // Spotlight shows at most a handful of apps before "Show all".
    readonly property int maxApps: 8

    readonly property var rows: model.build(model.query)

    // ------------------------------------------------------------- scoring

    // Fuzzy score of an already-lowercased `q` against `text`.
    // -1 means "no match"; higher is better.
    function fuzzyScore(q, text) {
        if (q.length === 0)
            return 0;
        if (text.length === 0)
            return -1;
        const idx = text.indexOf(q);
        if (idx === 0)
            return 1000 - text.length;          // prefix: the best kind of match
        if (idx > 0) {
            // A substring that starts a word ("code" in "Visual Studio Code")
            // ranks above one that starts mid-word.
            const prev = text.charAt(idx - 1);
            const wordStart = (prev === " " || prev === "-" || prev === "_" || prev === ".");
            return (wordStart ? 900 : 800) - idx * 2 - text.length;
        }
        // Subsequence match, rewarding streaks and word starts.
        let qi = 0, score = 0, streak = 0, last = -2, first = -1;
        for (let i = 0; i < text.length && qi < q.length; i++) {
            if (text.charAt(i) === q.charAt(qi)) {
                if (first < 0)
                    first = i;
                streak = (i === last + 1) ? streak + 1 : 0;
                last = i;
                score += 2 + streak * 3;
                const p = i > 0 ? text.charAt(i - 1) : " ";
                if (i === 0 || p === " " || p === "-" || p === "_" || p === ".")
                    score += 5;
                qi++;
            }
        }
        if (qi < q.length)
            return -1;
        return 100 + score - first * 2 - text.length * 0.1;
    }

    // Best score of a desktop entry: the name counts fully, the generic name
    // and the comment count for less so "Web Browser" never outranks a real
    // name match.
    function scoreEntry(entry, lq) {
        let best = fuzzyScore(lq, (entry.name || "").toLowerCase());
        const generic = fuzzyScore(lq, (entry.genericName || "").toLowerCase());
        if (generic >= 0)
            best = Math.max(best, generic * 0.55);
        const comment = fuzzyScore(lq, (entry.comment || "").toLowerCase());
        if (comment >= 0)
            best = Math.max(best, comment * 0.3);
        return best;
    }

    // ---------------------------------------------------------- calculator

    // Evaluate a sanitized arithmetic expression, or return null.
    // Only digits and arithmetic characters ever reach the evaluator, so no
    // identifier (and therefore no function call) can be constructed.
    // Returns { display, plain }: `display` has thousands separators for the
    // row, `plain` is what ↵ puts on the clipboard.
    function calcResult(expr) {
        if (expr.length === 0)
            return null;
        if (!/^[0-9+\-*/(). %^]+$/.test(expr))
            return null;
        if (!/[+\-*/^%]/.test(expr))
            return null; // a bare number is not a calculation
        // `^` is exponentiation everywhere except in C-like languages.
        let js = expr.replace(/\^/g, "**");
        // `%` before an operand is modulo ("10 % 3"); anywhere else it is a
        // percentage ("200 * 15%", "50% + 4").
        js = js.replace(/%(\s*)(?![0-9(.])/g, "/100$1");
        let value;
        try {
            value = Function('"use strict"; return (' + js + ');')();
        } catch (err) {
            return null;
        }
        if (typeof value !== "number" || !isFinite(value))
            return null;
        const rounded = Math.round(value * 1e10) / 1e10;
        return {
            display: model.formatNumber(rounded),
            plain: String(rounded)
        };
    }

    function formatNumber(rounded) {
        if (Math.abs(rounded) >= 1e12 || (rounded !== 0 && Math.abs(rounded) < 1e-6))
            return rounded.toExponential(6).replace(/\.?0+e/, "e");
        // Thousands separators, like the macOS calculator result row.
        const parts = String(rounded).split(".");
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        return parts.join(".");
    }

    // ------------------------------------------------------------- icons

    // Quickshell.iconPath(name, true) returns "" for a missing icon, which is
    // what drives the initial-tile fallback in the row and preview.
    function rowIconPath(row) {
        if (!row || !row.iconName || row.iconName.length === 0)
            return "";
        return Quickshell.iconPath(row.iconName, true);
    }

    // Deterministic tile color per name, the shell's standard icon fallback.
    function tileColor(name) {
        let h = 0;
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) % 360;
        return Qt.hsla(h / 360.0, 0.55, 0.5, 1.0);
    }

    // ------------------------------------------------------------- rows

    function build(rawQuery) {
        const q = rawQuery.trim();
        const rows = [];
        if (q.length === 0)
            return rows;

        // "> command" runs a shell command instead of searching.
        if (q.charAt(0) === ">") {
            const command = q.slice(1).trim();
            if (command.length > 0) {
                rows.push({
                    kind: "header",
                    title: "Actions"
                });
                rows.push({
                    kind: "run",
                    name: "Run “" + command + "”",
                    command: command,
                    subtitle: "Shell Command"
                });
            }
            return rows;
        }

        const lq = q.toLowerCase();
        const apps = DesktopEntries.applications.values;
        const scored = [];
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i];
            if (entry.noDisplay)
                continue;
            const score = model.scoreEntry(entry, lq);
            if (score >= 0)
                scored.push({
                    entry: entry,
                    score: score
                });
        }
        scored.sort(function (a, b) {
            if (b.score !== a.score)
                return b.score - a.score;
            return a.entry.name < b.entry.name ? -1 : 1;
        });

        function appRow(entry, topHit) {
            return {
                kind: "app",
                entry: entry,
                name: entry.name || "",
                subtitle: "Application",
                iconName: entry.icon || "",
                topHit: topHit === true
            };
        }

        if (scored.length > 0) {
            rows.push({
                kind: "header",
                title: "Top Hit"
            });
            rows.push(appRow(scored[0].entry, true));
        }

        const calc = model.calcResult(q);
        if (calc !== null) {
            rows.push({
                kind: "header",
                title: "Calculator"
            });
            rows.push({
                kind: "calc",
                name: q + " = " + calc.display,
                expr: q,
                value: calc.display,
                plain: calc.plain,
                subtitle: "Calculator"
            });
        }

        if (scored.length > 1) {
            rows.push({
                kind: "header",
                title: "Applications"
            });
            const limit = Math.min(model.maxApps, scored.length - 1);
            for (let j = 1; j <= limit; j++)
                rows.push(appRow(scored[j].entry, false));
        }

        rows.push({
            kind: "header",
            title: "Web Search"
        });
        rows.push({
            kind: "web",
            name: "Search the Web for “" + q + "”",
            term: q,
            subtitle: "DuckDuckGo"
        });

        return rows;
    }
}
