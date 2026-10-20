// A reader of a shared feed (see Feeds.qml). Properties: key, command, interval (ms; 0 = stream), active. Signal: got(text).
import QtQuick

QtObject {
    id: f
    property string key: ""
    property var command: []
    property int interval: 60000
    property bool active: true
    signal got(string text)
    property string _sub: ""
    function refresh() { Feeds.refresh(key); }
    function sync() {
        if (_sub !== "" && (_sub !== key || !active)) { Feeds.release(f, _sub); _sub = ""; }
        if (active && key !== "" && _sub === "") { _sub = key; Feeds.acquire(f); }
    }
    onKeyChanged: Qt.callLater(sync)
    onActiveChanged: Qt.callLater(sync)
    Component.onCompleted: Qt.callLater(sync)
    Component.onDestruction: if (_sub !== "") Feeds.release(f, _sub)
}
