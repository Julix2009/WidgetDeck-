// Asks when the builder is open and a newer version exists: update now or not. "Not now" asks again after the next start
// of WidgetDeck (or when an even newer version appears). Nothing is installed without the click.
import QtQuick
import "../core"

Rectangle {
    id: ud
    required property var th
    required property var update               // core/UpdateCheck.qml
    property bool allowed: true                // not while the start animation runs
    readonly property string key: update.latest + "|" + update.version
    readonly property bool wanted: allowed && update.available && update.dismissedKey !== key
    function later() { update.dismissedKey = key; }
    function now() { later(); update.startUpdate(); }

    visible: wanted
    color: Qt.rgba(0, 0, 0, 0.6)
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: wheel => wheel.accepted = true }

    Rectangle {
        anchors.centerIn: parent
        width: 460; height: col.height + 44
        radius: ud.th.cardRadius; color: ud.th.card; border.width: 1; border.color: ud.th.line
        Rectangle { x: ud.th.cardRadius; width: parent.width - 2 * ud.th.cardRadius; height: 3; radius: 2; color: ud.th.accent }
        Column {
            id: col
            x: 22; y: 22; width: parent.width - 44; spacing: 12
            Text { text: I18n.tr("Update available"); color: ud.th.fg; font.family: ud.th.font; font.pixelSize: 20; font.bold: true }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; color: ud.th.fg; font.family: ud.th.font; font.pixelSize: 13
                // on the "main" channel there can be newer changes without a new version number
                text: ud.update.latest !== "" && ud.update.latest !== ud.update.version ? I18n.trf("WidgetDeck %1 is available. You have %2.", ud.update.latest, ud.update.version)
                    : I18n.tr("There are newer changes on GitHub.")
            }
            Rectangle {
                visible: ud.update.notes !== ""
                width: parent.width; height: Math.min(170, notes.implicitHeight + 20); radius: ud.th.ctlRadius; color: ud.th.well
                Flickable {
                    anchors.fill: parent; anchors.margins: 10
                    contentHeight: notes.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                    Text { id: notes; width: parent.width; wrapMode: Text.WordWrap; color: ud.th.dim; font.family: ud.th.font; font.pixelSize: 11; text: ud.update.notes.replace(/^## \[(.*?)\].*$/gm, "WidgetDeck $1").replace(/^### /gm, "") }
                }
            }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: ud.th.dim; font.family: ud.th.font; font.pixelSize: 11
                text: I18n.tr("The update opens in a terminal, shows what changes and asks before it installs. Your settings are kept.") }
            Row {
                anchors.right: parent.right; spacing: 8
                GButton { th: ud.th; implicitHeight: 34; label: I18n.tr("Not now"); onClicked: ud.later() }
                GButton { th: ud.th; implicitHeight: 34; primary: true; pad: 22; label: I18n.tr("Update now"); onClicked: ud.now() }
            }
        }
    }
}
