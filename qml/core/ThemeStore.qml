// Theme engine glue: Matugen palette -> animated colours for the builder and every widget.
//
//   A wallpaper change that runs matugen (your own pipeline, or the builder button) writes
//   ~/.config/widgetdeck/theme.json (template: ~/.config/matugen/templates/widgetdeck-theme.json.template).
//   This object watches that file, so palette changes arrive live; every role is an animated colour
//   (Palette.qml) and fades smoothly. No file / theming off -> fixed fallback palette (ThemeData.js).
//
// Colour sources in the widget config: "theme:<role>" (follows Matugen), "shell:<name>" (the colours of another Quickshell setup, see below)
// or "#rrggbb" (own colour, never touched).
import QtQuick
import Quickshell
import Quickshell.Io
import "ThemeData.js" as TD

Scope {
    id: root
    required property var store
    property var data: null                       // parsed theme.json
    property alias pal: palette
    signal wallpaperPaletteChanged()               // theme.json was rewritten (= the wallpaper changed)

    // Matugen is optional: without it the fixed default palette (ThemeData.js FALLBACK) is used and the theming engine stays off
    property bool hasMatugen: false
    Process { id: probe; command: ["sh", "-c", "command -v matugen >/dev/null 2>&1"]; running: true; onExited: (code, status) => root.hasMatugen = code === 0 }
    readonly property bool enabled: hasMatugen && store.builder.themeEnabled !== false
    readonly property string mode: store.builder.themeMode === "light" ? "light" : "dark"
    readonly property bool dark: mode === "dark"
    readonly property string scheme: store.builder.themeScheme || "scheme-tonal-spot"
    readonly property var roles: TD.ROLES
    readonly property string sourceColor: data && data.source ? data.source : ""
    property bool busy: false

    readonly property var colorKeys: ["fg", "accent", "bg", "border_color", "tint_color"]

    ThemePalette { id: palette }

    // ───────────── palette plumbing ─────────────
    function apply() {
        var src = (enabled && data && data[mode]) ? data[mode] : TD.FALLBACK[mode];
        for (var i = 0; i < TD.ROLES.length; i++) {
            var r = TD.ROLES[i], v = src[r] || TD.FALLBACK[mode][r];
            if (palette[r].toString() !== String(v).toLowerCase()) palette[r] = v;
        }
    }
    onEnabledChanged: apply()
    onModeChanged: apply()
    onDataChanged: apply()
    Component.onCompleted: { apply(); Qt.callLater(function () { palette.animate = true; }); }

    function parse(text) {
        try {
            var o = JSON.parse(text);
            if (!o || !o.dark || !o.light || !o.dark.primary) return false;
            data = o;
            return true;
        } catch (e) { return false; }        // matugen is mid-write: the next change event brings the full file
    }
    FileView {
        id: tfile
        path: root.store.dir + "/theme.json"
        watchChanges: true
        property bool first: true
        onLoaded: {
            var ok = root.parse(text());
            if (ok && !first) root.wallpaperPaletteChanged();
            first = false;
        }
        onLoadFailed: error => { first = false; }
        onFileChanged: reload()
    }

    // ───────────── colours of another shell: "shell:<name>" ─────────────
    // The Serpantinum shell (Catppuccin names: base, mantle, text, surface0-2, blue, red ...) writes them to $XDG_STATE_HOME/serpantinum/qs_colors.json whenever its
    // wallpaper changes - with its own matugen configuration, so theme.json does not see it. The file is watched: the widgets follow live.
    // Without the file "shell:<name>" falls back to the matching Matugen role, and the Serpantinum palette is not offered.
    property var shellColors: ({})
    readonly property bool shellColorsAvailable: Object.keys(shellColors).length > 0
    readonly property string shellColorsPath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/serpantinum/qs_colors.json"
    readonly property var shellFallback: ({ base: "surface", mantle: "surface_container", crust: "surface_container_lowest", text: "on_surface", subtext0: "on_surface_variant",
        subtext1: "outline", surface0: "surface_container_high", surface1: "surface_container_highest", surface2: "outline_variant", overlay0: "outline", overlay1: "outline", overlay2: "outline",
        blue: "primary", sapphire: "primary", teal: "tertiary", green: "secondary", mauve: "primary", pink: "tertiary", peach: "tertiary", yellow: "tertiary", maroon: "error", red: "error" })
    FileView {
        id: sfile
        path: root.shellColorsPath
        watchChanges: true
        onLoaded: {
            try {
                var o = JSON.parse(text()), ok = {};
                for (var k in o) if (typeof o[k] === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(o[k])) ok[k] = o[k];
                root.shellColors = ok;
            } catch (e) { }                      // mid-write: the next change event brings the full file
        }
        onLoadFailed: error => { root.shellColors = ({}); }
        onFileChanged: reload()
    }

    // ───────────── colour access ─────────────
    // "theme:primary" -> current (animated) colour, "#aabbcc" -> unchanged
    function resolve(spec) {
        if (typeof spec === "string" && spec.indexOf("shell:") === 0) {
            var name = spec.substring(6), sc = shellColors[name];
            if (sc !== undefined) return sc;
            var fb = palette[shellFallback[name] || "primary"];
            return fb === undefined ? "#ff00ff" : fb.toString();
        }
        if (typeof spec === "string" && spec.indexOf("theme:") === 0) {
            var c = palette[spec.substring(6)];
            return c === undefined ? "#ff00ff" : c.toString();
        }
        return spec;
    }
    function isTheme(spec) { return typeof spec === "string" && spec.indexOf("theme:") === 0; }
    function resolveStyle(st) {
        var o = Object.assign({}, st);
        for (var i = 0; i < colorKeys.length; i++) if (o[colorKeys[i]] !== undefined) o[colorKeys[i]] = resolve(o[colorKeys[i]]);
        // glass darkness: "auto" follows the theme mode (legacy booleans keep working)
        if (o.dark === undefined || o.dark === "auto") o.dark = dark;
        else if (o.dark === "dark") o.dark = true;
        else if (o.dark === "light") o.dark = false;
        return o;
    }
    function resolveProps(schema, props) {
        var o = Object.assign({}, props);
        if (schema) for (var i = 0; i < schema.length; i++) if (schema[i].kind === "color" && o[schema[i].key] !== undefined) o[schema[i].key] = resolve(o[schema[i].key]);
        return o;
    }
    function palette_() {      // role -> hex for plugin widgets
        var o = {};
        for (var i = 0; i < TD.ROLES.length; i++) o[TD.ROLES[i]] = palette[TD.ROLES[i]].toString();
        return o;
    }

    // ───────────── matugen (optional, builder side) ─────────────
    // Scheme type / mode changed in the builder: run matugen on the CURRENT wallpaper with those options. matugen renders every template
    // of ITS config (~/.config/matugen/config.toml), WidgetDeck's theme.json among them (see README: "Theme"). An optional executable
    // ~/.config/widgetdeck/hooks/after-matugen runs afterwards, e.g. to reload other programs that follow the palette.
    function regenerate(wallpaperPath) {
        if (regen.running) return;
        busy = true;
        regen.command = ["sh", "-c",
            "command -v matugen >/dev/null 2>&1 || { echo 'matugen is not installed'; exit 1; }\n"
            + "[ -f \"$1\" ] || { echo 'no wallpaper file found'; exit 1; }\n"
            + "matugen image \"$1\" --source-color-index 0 -t \"$2\" -m \"$3\" || exit 1\n"
            + "h=\"$4/hooks/after-matugen\"; [ -x \"$h\" ] && \"$h\"; exit 0",
            "sh", wallpaperPath, scheme, mode, store.dir];
        regen.running = true;
    }
    Process {
        id: regen
        stderr: StdioCollector { onStreamFinished: if (text.trim() !== "") console.log("[widgetdeck-theme] matugen:", text.trim().split("\n").slice(-2).join(" | ")) }
        onExited: (code, status) => { root.busy = false; if (code !== 0) console.log("[widgetdeck-theme] matugen failed (exit " + code + ")"); }
    }
}
