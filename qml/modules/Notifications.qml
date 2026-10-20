// Optional module "notifications": a notification daemon (org.freedesktop.Notifications) with glass cards. OFF by default.
// Only ONE program can own that D-Bus name: another daemon (dunst, mako, swaync, ...) must be stopped first - the settings and the installer say so.
// IPC: dismissNotifications, toggleDnd.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../core"

Scope {
    id: nt
    required property var theme
    required property var store
    required property var mons
    property bool dnd: false
    readonly property int count: server.trackedNotifications.values.length
    function dismissAll() { var l = server.trackedNotifications.values.slice(); for (var i = 0; i < l.length; i++) l[i].dismiss(); }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: false
        onNotification: n => { n.tracked = true; }
    }

    PanelWindow {
        id: win
        visible: !nt.dnd && col.children.length > 1
        // cards appear on the monitor you are working on (setting "monitors.notify": the focused one, the main one or a chosen one)
        screen: {
            var all = Quickshell.screens, mode = nt.store.cget("monitors.notify", "focused"), want = "", i;
            nt.mons.list;
            if (mode === "primary") { var p = nt.mons.byKey(nt.mons.primaryKey); want = p ? p.name : ""; }
            else if (mode !== "focused") { var k = nt.mons.byKey(mode); want = k ? k.name : ""; }
            if (want === "") { var f = Hyprland.focusedMonitor; want = f ? f.name : ""; }
            for (i = 0; i < all.length; i++) if (all[i].name === want) return all[i];
            return all.length > 0 ? all[0] : null;
        }
        anchors { top: true; right: true }
        margins { top: 54; right: 12 }
        implicitWidth: 380
        implicitHeight: Math.max(1, col.height)
        color: "transparent"
        WlrLayershell.namespace: "widgetdeck"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        mask: Region { item: col }
        readonly property var pal: nt.theme.pal

        Column {
            id: col
            width: parent.width; spacing: 8
            Repeater {
                model: server.trackedNotifications
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    width: col.width; height: body.height + 24; radius: 16
                    color: Qt.rgba(win.pal.surface.r, win.pal.surface.g, win.pal.surface.b, 0.72)
                    border.width: 1; border.color: Qt.rgba(win.pal.outline.r, win.pal.outline.g, win.pal.outline.b, 0.4)
                    Timer {   // popups fade out by themselves; the sender's timeout wins when it sets one
                        interval: modelData.expireTimeout > 0 ? modelData.expireTimeout * 1000 : 7000
                        running: modelData.urgency !== NotificationUrgency.Critical; onTriggered: modelData.expire()
                    }
                    Column {
                        id: body
                        x: 14; y: 12; width: parent.width - 28; spacing: 4
                        Row {
                            width: parent.width; spacing: 8
                            Text { width: parent.width - 28; elide: Text.ElideRight; text: modelData.appName; color: win.pal.on_surface_variant; font.family: Fonts.ui; font.pixelSize: 11 }
                            Text { text: "✕"; color: win.pal.on_surface_variant; font.pixelSize: 12
                                   MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: modelData.dismiss() } }
                        }
                        Text { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: modelData.summary; color: win.pal.on_surface; font.family: Fonts.ui; font.pixelSize: 14; font.bold: true }
                        Text { width: parent.width; visible: text !== ""; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight; text: modelData.body; color: win.pal.on_surface; opacity: 0.85; font.family: Fonts.ui; font.pixelSize: 12 }
                        Row {
                            spacing: 6; visible: modelData.actions.length > 0
                            Repeater {
                                model: modelData.actions
                                delegate: Rectangle {
                                    required property var modelData
                                    height: 24; width: at.implicitWidth + 20; radius: 12; color: Qt.rgba(1, 1, 1, ama.containsMouse ? 0.2 : 0.1)
                                    Text { id: at; anchors.centerIn: parent; text: modelData.text; color: win.pal.on_surface; font.family: Fonts.ui; font.pixelSize: 12 }
                                    MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.invoke() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
