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
}
