// To-do list: tick off, remove, and type new tasks right on the desktop (Enter adds, Esc leaves the field). One list for all instances and monitors
// (todo/TodoService.qml, logic in todo/Model.js). Typing needs the keyboard: it is held (wantsKeyboard, see DesktopWidget) from a click into the
// field until the pointer leaves the widget, Esc is pressed or nothing is typed for a while. A pointer merely resting on the widget takes nothing.
import QtQuick
import "../core"
import "todo"
import "todo/Model.js" as M
import "music"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})
    property bool wantsKeyboard: false

    readonly property var svc: TodoService
    readonly property bool demo: props.demo === true          // the library preview shows invented tasks, never the real list
    readonly property real fs: style.font_size || 16
    readonly property real k: fs / 16 * (props.text_size || 1)
    function s(v) { return v * k; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: palette.primary || style.accent || "#8ab4ff"
    function faded(a) { return Qt.rgba(cFg.r, cFg.g, cFg.b, a); }

    readonly property var items: demo ? [{ id: "a", text: I18n.tr("Water the plants"), done: false }, { id: "b", text: I18n.tr("Answer the e-mail"), done: false },
                                         { id: "c", text: I18n.tr("Buy milk"), done: true }] : svc.items
    readonly property var shown: M.sorted(items, props.show_done !== false)
    readonly property int openCount: M.openCount(items)
    readonly property bool hasDone: items.length > openCount

    HoverHandler { id: hov }
    // the keyboard is only borrowed: given back when the pointer leaves, and after 30 s without typing (a half written task stays in the field)
    Timer { id: idle; interval: 30000; running: w.wantsKeyboard; onTriggered: w.release() }
    Connections { target: hov; function onHoveredChanged() { if (!hov.hovered) w.release(); } }
    function release() { input.focus = false; wantsKeyboard = false; }

    // ---- header: name, number of open tasks, "remove done" while the pointer is over the widget
    Item {
        id: head
        width: parent.width; height: w.s(24)
        Row {
            height: parent.height; spacing: w.s(7)
            Icon { anchors.verticalCenter: parent.verticalCenter; width: w.s(17); height: width; name: "check"; color: w.cAcc; stroke: 2.4 }
            GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.bold: true; font.letterSpacing: 1.4; font.pixelSize: w.s(11); opacity: 0.9; text: I18n.tr("To-do").toUpperCase() }
        }
        Row {
            anchors.right: parent.right; height: parent.height; spacing: w.s(8)
            MButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: hov.hovered && w.hasDone && !w.demo
                width: clearText.implicitWidth + w.s(18); height: w.s(22); animate: false; hoverColor: w.cAcc
                onClicked: w.svc.removeDone()
                GText { id: clearText; anchors.centerIn: parent; wstyle: w.style; font.pixelSize: w.s(11); text: I18n.tr("Remove done") }
            }
            GText { anchors.verticalCenter: parent.verticalCenter; wstyle: w.style; font.pixelSize: w.s(12); opacity: 0.75; visible: w.demo || !w.svc.broken; text: I18n.trf("%1 open", w.openCount) }
        }
    }

    // ---- the tasks
    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: w.s(8); bottom: field.top; bottomMargin: w.s(8) }
        clip: true; boundsBehavior: Flickable.StopAtBounds
        spacing: w.s(2)
        model: w.shown
        // the model is replaced on every change: keep the scroll position
        property real keepY: 0
        onContentYChanged: if (moving || flicking) keepY = contentY
        onModelChanged: Qt.callLater(function () { list.contentY = Math.max(0, Math.min(list.keepY, list.contentHeight - list.height)); })
        delegate: Rectangle {
            id: row
            required property var modelData
            width: list.width; height: Math.max(w.s(28), label.implicitHeight + w.s(10))
            radius: Math.min(w.innerRadius, w.s(10))
            color: rowHover.hovered ? w.faded(0.07) : "transparent"
            HoverHandler { id: rowHover }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!w.demo) w.svc.toggle(row.modelData.id) }
            Rectangle {
                id: box
                x: w.s(4); anchors.verticalCenter: parent.verticalCenter
                width: w.s(16); height: width; radius: width / 2
                color: row.modelData.done ? w.cAcc : "transparent"
                border.width: row.modelData.done ? 0 : 1.5; border.color: w.faded(0.5)
                Icon { anchors.centerIn: parent; visible: row.modelData.done; width: w.s(11); height: width; name: "check"; color: w.palette.on_primary || "#10131a"; stroke: 3.4 }
            }
            GText {
                id: label
                anchors { left: box.right; leftMargin: w.s(9); right: parent.right; rightMargin: w.s(28); verticalCenter: parent.verticalCenter }
                wstyle: w.style; font.pixelSize: w.s(14); wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                textFormat: Text.PlainText
                font.strikeout: row.modelData.done; opacity: row.modelData.done ? 0.5 : 1
                text: row.modelData.text
            }
            MButton {
                anchors { right: parent.right; rightMargin: w.s(3); verticalCenter: parent.verticalCenter }
                visible: rowHover.hovered && !w.demo
                width: w.s(20); height: width; animate: false; baseColor: "transparent"; hoverColor: w.cAcc
                onClicked: w.svc.remove(row.modelData.id)
                Icon { anchors.centerIn: parent; width: w.s(12); height: width; name: "cancel"; color: w.cFg; stroke: 2.4 }
            }
        }
    }
    GText {
        anchors.centerIn: list
        width: list.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
        visible: w.shown.length === 0 || (!w.demo && w.svc.broken)
        wstyle: w.style; font.pixelSize: w.s(13); opacity: 0.7
        text: !w.demo && w.svc.broken ? I18n.tr("todo.json cannot be read. It is left untouched.") : I18n.tr("Nothing to do.")
    }

    // ---- a new task
    Rectangle {
        id: field
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: w.s(32); radius: height / 2
        color: w.faded(input.activeFocus ? 0.14 : 0.08)
        border.width: input.activeFocus ? 1.5 : 0; border.color: w.cAcc
        TextInput {
            id: input
            anchors { fill: parent; leftMargin: w.s(14); rightMargin: w.s(14) }
            verticalAlignment: TextInput.AlignVCenter
            color: w.cFg; selectionColor: w.cAcc
            font.family: Fonts.resolve(w.style.font); font.pixelSize: w.s(14)
            clip: true; maximumLength: M.MAX_TEXT
            enabled: !w.demo && !w.svc.broken
            onAccepted: if (w.svc.add(text)) { text = ""; list.keepY = 0; }
            Keys.onEscapePressed: { text = ""; w.release(); }
            onTextChanged: if (w.wantsKeyboard) idle.restart()
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: mouse => { w.wantsKeyboard = true; input.forceActiveFocus(); mouse.accepted = false; } }
        GText {
            anchors { left: parent.left; leftMargin: w.s(14); verticalCenter: parent.verticalCenter }
            visible: input.text === ""
            wstyle: w.style; font.pixelSize: w.s(14); opacity: 0.5
            text: I18n.tr("New task …")
        }
    }
}
