// Optional (part of the "notifications" module): a power menu. Open it from the bar, with `widgetdeck ipc powerPanel`, or with a Hyprland bind.
// Lock / sleep act at once; log out, restart and shut down need a second click (3 s) so nothing happens by accident.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

Scope {
    id: pp
    required property var theme
    property bool open: false
    function toggle() { open = !open; }

    LazyLoader {
        active: pp.open
        PanelWindow {
            id: win
            anchors { top: true; bottom: true; left: true; right: true }
            color: Qt.rgba(0, 0, 0, 0.35)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "widgetdeck-power"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            readonly property var pal: pp.theme.pal
            MouseArea { anchors.fill: parent; onClicked: pp.open = false }
            Item { focus: true; Keys.onEscapePressed: pp.open = false; Component.onCompleted: forceActiveFocus() }

            Rectangle {
                anchors.centerIn: parent
                width: row.width + 48; height: 150; radius: 28
                color: Qt.rgba(win.pal.surface.r, win.pal.surface.g, win.pal.surface.b, 0.78)
                border.width: 1; border.color: Qt.rgba(win.pal.outline.r, win.pal.outline.g, win.pal.outline.b, 0.4)
                MouseArea { anchors.fill: parent }
                Row {
                    id: row
                    anchors.centerIn: parent; spacing: 14
                    Repeater {
                        model: [
                            { icon: "lock", label: I18n.tr("Lock"), cmd: ["loginctl", "lock-session"], sure: false },
                            { icon: "sleep", label: I18n.tr("Sleep"), cmd: ["systemctl", "suspend"], sure: false },
                            { icon: "logout", label: I18n.tr("Log out"), cmd: ["hyprctl", "dispatch", "exit"], sure: true },
                            { icon: "reboot", label: I18n.tr("Restart"), cmd: ["systemctl", "reboot"], sure: true },
                            { icon: "power", label: I18n.tr("Shut down"), cmd: ["systemctl", "poweroff"], sure: true }
                        ]
                        delegate: Rectangle {
                            id: btn
                            required property var modelData
                            property bool armed: false
                            width: 92; height: 100; radius: 20
                            color: armed ? Qt.rgba(win.pal.error.r, win.pal.error.g, win.pal.error.b, 0.35) : (bma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                            Column {
                                anchors.centerIn: parent; spacing: 10
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; width: 32; height: 32; name: modelData.icon; color: win.pal.on_surface }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: btn.armed ? I18n.tr("Click again") : modelData.label; color: win.pal.on_surface; font.family: Fonts.ui; font.pixelSize: 12 }
                            }
                            Timer { id: disarm; interval: 3000; onTriggered: btn.armed = false }
                            MouseArea {
                                id: bma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.sure && !btn.armed) { btn.armed = true; disarm.restart(); return; }
                                    pp.open = false;
                                    Quickshell.execDetached(modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
