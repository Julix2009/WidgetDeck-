// What the quick apps widgets share: the installed apps, starting one, changing a widget's list (which also changes its size) and the state of
// the app chooser (AppPicker.qml, one window for all widgets, created by shell.qml). The list itself is the widget prop "apps" in the layout.
// The chooser is opened from the widget on the desktop and from the builder's settings panel.
// NOTE: no curly braces in the comment lines above "pragma Singleton" (Quickshell's scanner stops at the first one).
pragma Singleton
import QtQuick
import Quickshell
import "Model.js" as M
import "../../core/SnapEngine.js" as SE

Singleton {
    id: svc
    property var store: null                      // the layout / settings store (set by shell.qml)
    property string pickerFor: ""                 // widget id the chooser is open for, "" = closed
    property var pickerScreen: null
    property bool pickerRemoves: false            // only the builder's chooser can take apps out again

    readonly property var entries: DesktopEntries.applications.values
    function entry(id) { var l = entries; for (var i = 0; i < l.length; i++) if (l[i].id === id) return l[i]; return null; }
    function listOf(widgetId) { if (!store || !store.raw(widgetId)) return []; return M.clean(store.propsOf(widgetId).apps); }

    function setList(widgetId, list) {
        var c = store ? store.raw(widgetId) : null;
        if (!c || c.type !== "quickapps") return false;
        if (JSON.stringify(list) === JSON.stringify(listOf(widgetId))) return false;
        store.setProp(widgetId, "apps", list);
        var cell = store.gridFor(store.homeKey(c)).cell, s = M.sizeFor(list.length);
        store.animateGeom(widgetId, [SE.gridCeil(s[0], cell), SE.gridCeil(s[1], cell)]);
        return true;
    }
    function add(widgetId, appId) { return setList(widgetId, M.add(listOf(widgetId), appId)); }
    function remove(widgetId, appId) { return setList(widgetId, M.remove(listOf(widgetId), appId)); }

    function openPicker(widgetId, screen, removes) { pickerScreen = screen; pickerRemoves = removes === true; pickerFor = widgetId; }
    function closePicker() { pickerFor = ""; }

    // Quickshell does not open a terminal for terminal programs (htop and the like): the first terminal that is installed does
    function launch(appId) {
        var e = entry(appId);
        if (!e) return false;
        var cmd = Array.prototype.slice.call(e.command);
        if (cmd.length === 0) return false;
        if (e.runInTerminal) cmd = ["sh", "-c", "for t in \"$TERMINAL\" kitty foot alacritty ghostty wezterm konsole xterm; do command -v \"$t\" >/dev/null 2>&1 || continue; [ \"$t\" = wezterm ] && exec \"$t\" start -- \"$@\"; exec \"$t\" -e \"$@\"; done", "sh"].concat(cmd);
        Quickshell.execDetached({ command: cmd, workingDirectory: e.workingDirectory || Quickshell.env("HOME") });
        return true;
    }
}
