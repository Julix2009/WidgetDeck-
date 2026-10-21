// Overview of the track outlines of a calendar, drawn with the real Track component (offscreen):
//   tools/f1/outline-sheet.sh calendar.json sheet.png
// calendar.json = JSON from `f1.py fetch` (its races[].circuitId decide what is shown); a circuit without an outline is marked in red.
import QtQuick
import "../../qml/widgets/f1"
import "../../qml/widgets/f1/circuits.js" as C

Rectangle {
    id: root
    width: 1500; height: 1000
    color: "#161a26"
    property var ids: []
    Component.onCompleted: {
        var x = new XMLHttpRequest();
        x.open("GET", "file://@CAL@", false); x.send();
        try { var d = JSON.parse(x.responseText); ids = d.races.map(function (r) { return r.circuitId + "|" + r.name; }); } catch (e) { console.log("no calendar", e); }
        shot.start();
    }
    Grid {
        anchors.fill: parent; anchors.margins: 16; columns: 6; spacing: 10
        Repeater {
            model: root.ids
            delegate: Rectangle {
                required property string modelData
                readonly property string cid: modelData.split("|")[0]
                readonly property var circ: C.CIRCUITS[cid] || null
                width: (root.width - 32 - 50) / 6; height: 150; radius: 12
                color: circ ? "#222838" : "#4a1c22"
                Track { anchors.fill: parent; anchors.margins: 8; anchors.bottomMargin: 26; circuit: parent.circ; draw: false; lineWidth: 3 }
                Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 6; anchors.horizontalCenter: parent.horizontalCenter; color: parent.circ ? "#aab" : "#f99"; font.pixelSize: 11
                       text: parent.cid + (parent.circ ? (parent.circ.closed ? "" : "  (open)") : "  MISSING") }
            }
        }
    }
    Timer {
        id: shot; interval: 600
        onTriggered: root.grabToImage(function (r) { r.saveToFile("@OUT@"); Qt.quit(); })
    }
}
