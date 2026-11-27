// The to-do list: ONE list for every widget instance and every monitor, saved in todo.json next to the layout. All logic is in Model.js.
// A file that cannot be read is never overwritten: the widget says so and changes are refused until it is repaired. Edits from outside are noticed.
// NOTE: no curly braces in the comment lines above "pragma Singleton" (Quickshell's scanner stops at the first one).
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as M

Singleton {
    id: svc
    property var store: null                      // the layout / settings store (set by shell.qml)
    readonly property string dir: store ? store.dir : ""
    readonly property bool storeReady: !!store && store.loaded === true

    property var items: []
    property bool loaded: false
    property bool broken: false
    property string lastText: ""
    readonly property int openCount: M.openCount(items)

    function newId() { return "t" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36); }
    function apply(next) {
        if (!loaded || broken) return false;
        var t = M.serialize(next);
        if (t === M.serialize(items)) return false;
        items = next; lastText = t; file.setText(t);
        return true;
    }
    function add(text) { return apply(M.add(items, text, newId())); }
    function toggle(id) { return apply(M.toggle(items, id)); }
    function remove(id) { return apply(M.remove(items, id)); }
    function removeDone() { return apply(M.removeDone(items)); }
    function statusJson() { return JSON.stringify({ loaded: loaded, broken: broken, open: openCount, items: items }); }

    function read(t) {
        if (t !== lastText || broken) {
            var l = M.parse(t);
            broken = l === null;
            if (broken) console.warn("[todo] todo.json is not a valid list: left untouched");
            else { items = l; lastText = t; }
        }
        loaded = true;
    }
    FileView {
        id: file
        path: svc.storeReady ? svc.dir + "/todo.json" : ""
        watchChanges: true
        atomicWrites: true
        printErrors: false                        // no file yet is normal
        onLoaded: svc.read(text())
        onLoadFailed: error => {
            svc.broken = error !== FileViewError.FileNotFound;
            if (!svc.broken) { svc.items = []; svc.lastText = ""; }
            svc.loaded = true;
        }
        onFileChanged: reload()
    }
}
