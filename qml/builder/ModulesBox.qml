// Switches for the optional modules. Switching on the bar or the notification service first looks for programs that would be replaced
// (modules/conflicts.sh) and asks; nothing is ever stopped for the user.
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Column {
    id: mb
    required property var store
    required property var th
    spacing: 8
    property string pending: ""          // module waiting for the user's "enable anyway"
    property string conflict: ""
    readonly property string script: decodeURIComponent(Qt.resolvedUrl("../modules/conflicts.sh").toString().replace("file://", ""))

    function toggle(name, on) {
        if (!on) { store.setConfig("modules." + name, false); if (pending === name) pending = ""; return; }
        if (name === "bar" || name === "notifications") { pending = name; conflict = ""; probe.command = ["bash", script, name]; probe.running = true; }
        else store.setConfig("modules." + name, true);
    }
    Process {
        id: probe
        stdout: StdioCollector {
            onStreamFinished: {
                mb.conflict = text.trim();
                if (mb.conflict === "") { mb.store.setConfig("modules." + mb.pending, true); mb.pending = ""; }
            }
        }
    }

    GSwitch { width: parent.width; th: mb.th; label: I18n.tr("Widgets (weather, network, sensors, music …)"); checked: mb.store.cget("modules.widgets", true); onToggled: v => mb.toggle("widgets", v) }
    GSwitch { width: parent.width; th: mb.th; label: I18n.tr("Builder and grid"); checked: mb.store.cget("modules.builder", true); onToggled: v => mb.toggle("builder", v) }
    Text { visible: !mb.store.cget("modules.builder", true); width: parent.width; wrapMode: Text.WordWrap; color: mb.th.danger; font.family: mb.th.font; font.pixelSize: 11
        text: I18n.tr("With the builder off, this panel disappears. Switch it back on with: widgetdeck module builder on") }
    GSwitch { width: parent.width; th: mb.th; label: I18n.tr("Bar (off by default)"); checked: mb.store.cget("modules.bar", false); onToggled: v => mb.toggle("bar", v) }
    GSwitch { width: parent.width; th: mb.th; label: I18n.tr("Notifications and power menu (off by default)"); checked: mb.store.cget("modules.notifications", false); onToggled: v => mb.toggle("notifications", v) }

    Rectangle {
        visible: mb.pending !== "" && mb.conflict !== ""
        width: parent.width; height: warn.height + 24; radius: 12; color: Qt.rgba(1, 0.6, 0.2, 0.14); border.width: 1; border.color: Qt.rgba(1, 0.6, 0.2, 0.6)
        Column {
            id: warn
            x: 12; y: 12; width: parent.width - 24; spacing: 8
            Text { width: parent.width; wrapMode: Text.WordWrap; color: mb.th.fg; font.family: mb.th.font; font.pixelSize: 12
                text: (mb.pending === "bar" ? I18n.tr("Another bar is already running:") : I18n.tr("Another program already provides notifications:")) + "\n" + mb.conflict }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: mb.th.dim; font.family: mb.th.font; font.pixelSize: 11
                text: mb.pending === "bar" ? I18n.tr("WidgetDeck does not stop it. Both bars would be visible; turn the other one off first (e.g. remove it from your Hyprland autostart).")
                                           : I18n.tr("Only one program can own the notification service. WidgetDeck does not stop the other one: turn it off first (e.g. systemctl --user disable --now <name>, or remove it from your autostart), then enable this.") }
            Row {
                spacing: 8
                GButton { th: mb.th; label: I18n.tr("Enable anyway"); onClicked: { mb.store.setConfig("modules." + mb.pending, true); mb.pending = ""; } }
                GButton { th: mb.th; label: I18n.tr("Cancel"); onClicked: mb.pending = "" }
            }
        }
    }
}
