// The UI font: the first installed one of a short list, else the system default. A font chosen by the user that is not installed
// (e.g. the config came from another machine) also falls back, so the text never disappears.
pragma Singleton
import QtQuick

QtObject {
    readonly property var installed: Qt.fontFamilies()
    readonly property var preferred: ["Adwaita Sans", "Inter", "Cantarell", "Noto Sans", "DejaVu Sans"]
    function has(name) { return !!name && installed.indexOf(name) >= 0; }
    readonly property string ui: {
        for (var i = 0; i < preferred.length; i++) if (has(preferred[i])) return preferred[i];
        return "sans-serif";
    }
    function resolve(name) { return has(name) ? name : ui; }
    function first(names, fallback) {
        for (var i = 0; i < names.length; i++) if (has(names[i])) return names[i];
        return fallback;
    }
    // for faces with a look of their own (clock styles): a font the user chose wins, else the first installed one of the list
    readonly property string mono: first(["JetBrains Mono", "JetBrainsMono Nerd Font", "Adwaita Mono", "Noto Sans Mono", "DejaVu Sans Mono"], "monospace")
    readonly property string round: first(["Google Sans Flex", "Nunito", "Rubik"], ui)
    function resolveMono(name) { return has(name) ? name : mono; }
    function resolveRound(name) { return has(name) ? name : round; }
}
