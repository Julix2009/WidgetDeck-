// Colour source of one property: "Theme" (follows Matugen, with a role) or "Eigene" (fixed colour).
// Value format: "theme:<role>" or "#rrggbb" - stored like that in widgets.json.
import QtQuick

Item {
    id: s
    required property var th
    property string label: ""
    property string value: "#ffffff"
    property string defRole: "primary"      // role to start from when switching to "Theme"
    signal picked(string v)
    readonly property bool isTheme: value.indexOf("theme:") === 0
    readonly property string role: isTheme ? value.substring(6) : defRole
    readonly property color shown: isTheme ? (th.pal[role] !== undefined ? th.pal[role] : "#ff00ff") : Qt.color(value)
    implicitHeight: 84
    Text { text: s.label; color: s.th.dim; font.family: s.th.font; font.pixelSize: 12 }
    Row {
        y: 18; width: parent.width; spacing: 6
        GButton { th: s.th; label: "Theme"; checked: s.isTheme; width: (s.width - 6) / 2; onClicked: s.picked("theme:" + s.role) }
        GButton { th: s.th; label: "Eigene Farbe"; checked: !s.isTheme; width: (s.width - 6) / 2; onClicked: s.picked(s.isTheme ? s.shown.toString() : s.value) }
    }
    Rectangle {
        id: sw
        y: 54; width: parent.width; height: 30; radius: s.th.ctlRadius; color: s.shown
        border.width: 1; border.color: s.th.line
        Text {
            anchors.centerIn: parent; font.family: s.th.font; font.pixelSize: 12
            text: s.isTheme ? s.role : s.value
            color: s.shown.hslLightness > 0.55 ? "#101216" : "#f2f4f8"
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (s.isTheme) {
                    var items = [], roles = s.th.themeStore.roles;
                    for (var i = 0; i < roles.length; i++) items.push(["theme:" + roles[i], roles[i], s.th.pal[roles[i]].toString()]);
                    s.th.pickList(sw, items, s.value, function (v) { s.picked(v); });
                } else s.th.pickColor(sw, s.value, function (h) { s.picked(h); });
            }
        }
    }
}
