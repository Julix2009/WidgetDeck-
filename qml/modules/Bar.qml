// Optional module "bar": a slim top bar with workspaces, clock, tray and a power button. OFF by default.
// It never replaces anything by itself: enabling it in the settings (or ./install.sh --modules ...bar) asks first and warns about other bars.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import "../core"

Scope {
    id: bar
    required property var theme
    required property var store
    signal powerRequested()

    readonly property bool use12h: {
        var t = store.cget("time_format", "auto");
        if (t === "12h") return true;
        if (t === "24h") return false;
        return /[aA]/.test(Qt.locale().timeFormat(Locale.ShortFormat).replace(/'[^']*'/g, ""));
    }
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: bar.now = new Date() }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 46
            color: "transparent"
            WlrLayershell.namespace: "widgetdeck"
            WlrLayershell.layer: WlrLayer.Top

            readonly property var pal: bar.theme.pal
            Rectangle {
                anchors { fill: parent; margins: 6 }
                radius: 16
                color: Qt.rgba(win.pal.surface.r, win.pal.surface.g, win.pal.surface.b, 0.62)
                border.width: 1; border.color: Qt.rgba(win.pal.outline.r, win.pal.outline.g, win.pal.outline.b, 0.35)

                // workspaces: whatever exists in this Hyprland session (no fixed count)
                Row {
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 4
                    Repeater {
                        model: Hyprland.workspaces
                        delegate: Rectangle {
                            required property var modelData
                            visible: modelData.id > 0
                            width: visible ? 26 : 0; height: 24; radius: 12
                            readonly property bool focused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                            color: focused ? win.pal.primary : (wma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07))
                            Text { anchors.centerIn: parent; text: modelData.id; color: parent.focused ? win.pal.on_primary : win.pal.on_surface
                                   font.family: Fonts.ui; font.pixelSize: 12; font.bold: true }
                            MouseArea { id: wma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: modelData.activate() }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: win.pal.on_surface; font.family: Fonts.ui; font.pixelSize: 14; font.bold: true
                    text: Qt.locale().toString(bar.now, bar.use12h ? "h:mm ap" : "HH:mm") + "   " + Qt.locale().toString(bar.now, "ddd d MMM")
                }
                Row {
                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                    spacing: 8
                    Repeater {
                        model: SystemTray.items
                        delegate: Item {
                            required property var modelData
                            width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                            Image { anchors.fill: parent; source: modelData.icon; sourceSize: Qt.size(40, 40); smooth: true }
                            MouseArea {
                                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton; cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => { if (mouse.button === Qt.LeftButton) modelData.activate(); else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate(); else if (modelData.hasMenu) modelData.display(win, mouse.x, mouse.y); }
                            }
                        }
                    }
                    Item {
                        width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.fill: parent; name: "power"; color: pma.containsMouse ? win.pal.primary : win.pal.on_surface }
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.powerRequested() }
                    }
                }
            }
        }
    }
}
