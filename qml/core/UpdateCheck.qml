// Version display and the once-a-day update hint (no automatic installation).
// core/updatecheck.sh does the work (git ls-remote, cached 24 h, silent without network / access); installing is started by the user via
// the button, which opens `widgetdeck-update` in a terminal.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var store
    readonly property bool enabled: !store || !store.config.update || store.config.update.check !== false
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("updatecheck.sh").toString().replace("file://", ""))

    property string version: ""
    property string state: ""            // "", current, available, unknown, disabled
    property string latest: ""
    property string notes: ""
    property string updater: ""
    property bool busy: false
    property bool manual: false
    property string message: ""
    readonly property bool available: state === "available"

    function check(force) {
        if (proc.running) return;
        manual = force === true; busy = true; message = "";
        proc.command = force === true ? ["bash", script, "--force"] : ["bash", script];
        proc.running = true;
    }
    function startUpdate() {
        Quickshell.execDetached(["sh", "-c", "exec \"${1:-widgetdeck-update}\" --terminal", "sh", updater]);
    }

    FileView {
        path: decodeURIComponent(Qt.resolvedUrl("../VERSION").toString().replace("file://", ""))
        onLoaded: { root.version = text().trim(); console.log("[widgetdeck] version", root.version); }
    }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text.trim());
                    root.version = o.version || root.version; root.state = o.state || ""; root.latest = o.latest || ""; root.notes = o.notes || ""; root.updater = o.updater || "";
                } catch (e) { root.state = "unknown"; }
                if (root.manual) root.message = root.state === "available" ? "" : root.state === "current" ? I18n.tr("You have the latest version.")
                    : root.state === "disabled" ? I18n.tr("The check is switched off.") : I18n.tr("Check not possible (no network, or no access to the repository).");
                root.busy = false; root.manual = false;
            }
        }
        onExited: root.busy = false
    }
    // once a day at most (the script caches), first look shortly after the start; nothing while switched off
    Timer { interval: 25000; running: root.enabled; onTriggered: root.check(false) }
    Timer { interval: 6 * 3600 * 1000; repeat: true; running: root.enabled; onTriggered: root.check(false) }
    onEnabledChanged: if (enabled) check(false); else { state = "disabled"; }
}
