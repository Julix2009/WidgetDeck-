#!/usr/bin/env python3
"""Tray icon of WidgetDeck (StatusNotifierItem + com.canonical.dbusmenu), so bars show that it is running.

Quickshell can only DISPLAY tray items, so this small helper provides one. The shell starts it and reads its stdout:
one word per line - "toggle" (left click / first menu entry), "settings", "quit". Needs python-gobject.
Usage: tray.py <label open> <label settings> <label quit>
"""
import ctypes
import os
import signal
import sys

try:
    from gi.repository import Gio, GLib
except ImportError:
    sys.exit("widgetdeck tray: python-gobject is not installed")

LABELS = (sys.argv[1:4] + ["Open builder", "Settings", "Quit WidgetDeck"][len(sys.argv[1:4]):])
MENU = [(1, LABELS[0], "toggle"), (2, LABELS[1], "settings"), (3, None, None), (4, LABELS[2], "quit")]

ITEM_XML = """<node><interface name="org.kde.StatusNotifierItem">
<property name="Category" type="s" access="read"/><property name="Id" type="s" access="read"/>
<property name="Title" type="s" access="read"/><property name="Status" type="s" access="read"/>
<property name="WindowId" type="i" access="read"/><property name="IconName" type="s" access="read"/>
<property name="IconPixmap" type="a(iiay)" access="read"/><property name="ToolTip" type="(sa(iiay)ss)" access="read"/>
<property name="ItemIsMenu" type="b" access="read"/><property name="Menu" type="o" access="read"/>
<method name="Activate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="SecondaryActivate"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="ContextMenu"><arg type="i" direction="in"/><arg type="i" direction="in"/></method>
<method name="Scroll"><arg type="i" direction="in"/><arg type="s" direction="in"/></method>
<signal name="NewIcon"/><signal name="NewStatus"><arg type="s"/></signal>
</interface></node>"""

MENU_XML = """<node><interface name="com.canonical.dbusmenu">
<property name="Version" type="u" access="read"/><property name="Status" type="s" access="read"/>
<property name="TextDirection" type="s" access="read"/><property name="IconThemePath" type="as" access="read"/>
<method name="GetLayout"><arg type="i" direction="in"/><arg type="i" direction="in"/><arg type="as" direction="in"/>
<arg type="u" direction="out"/><arg type="(ia{sv}av)" direction="out"/></method>
<method name="GetGroupProperties"><arg type="ai" direction="in"/><arg type="as" direction="in"/><arg type="a(ia{sv})" direction="out"/></method>
<method name="GetProperty"><arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="out"/></method>
<method name="Event"><arg type="i" direction="in"/><arg type="s" direction="in"/><arg type="v" direction="in"/><arg type="u" direction="in"/></method>
<method name="EventGroup"><arg type="a(isvu)" direction="in"/><arg type="ai" direction="out"/></method>
<method name="AboutToShow"><arg type="i" direction="in"/><arg type="b" direction="out"/></method>
<method name="AboutToShowGroup"><arg type="ai" direction="in"/><arg type="ai" direction="out"/><arg type="ai" direction="out"/></method>
<signal name="LayoutUpdated"><arg type="u"/><arg type="i"/></signal>
</interface></node>"""


# the heavy "W" of the start animation, on a 100 x 80 grid
W = ((0, 0), (19, 0), (29, 52), (40, 0), (60, 0), (71, 52), (81, 0), (100, 0), (83, 80), (62, 80), (50, 27), (38, 80), (17, 80))


def inside(x, y):
    hit = False
    for (ax, ay), (bx, by) in zip(W, W[1:] + W[:1]):
        if (ay > y) != (by > y) and x < ax + (y - ay) * (bx - ax) / (by - ay):
            hit = not hit
    return hit


def icon(size):
    """the W as ARGB32 in network byte order, smoothed with 4 x 4 samples per pixel"""
    scale = size * 0.96 / 100
    left, top = (size - 100 * scale) / 2, (size - 80 * scale) / 2
    px = bytearray(size * size * 4)
    for y in range(size):
        for x in range(size):
            hits = sum(inside((x + (i + 0.5) / 4 - left) / scale, (y + (j + 0.5) / 4 - top) / scale) for i in range(4) for j in range(4))
            at = (y * size + x) * 4
            px[at:at + 4] = bytes((hits * 255 // 16, 0xF2, 0xF2, 0xF2))
    return (size, size, bytes(px))


PIXMAPS = [icon(s) for s in (22, 32, 48, 64)]


def say(word):
    try:
        print(word, flush=True)
    except OSError:          # the shell is gone
        loop.quit()


def item_property(_c, _s, _p, _i, name):
    return {
        "Category": GLib.Variant("s", "ApplicationStatus"), "Id": GLib.Variant("s", "widgetdeck"),
        "Title": GLib.Variant("s", "WidgetDeck"), "Status": GLib.Variant("s", "Active"),
        "WindowId": GLib.Variant("i", 0), "IconName": GLib.Variant("s", ""),
        "IconPixmap": GLib.Variant("a(iiay)", PIXMAPS), "ToolTip": GLib.Variant("(sa(iiay)ss)", ("", [], "WidgetDeck", "")),
        "ItemIsMenu": GLib.Variant("b", False), "Menu": GLib.Variant("o", "/MenuBar"),
    }.get(name)


def item_call(_c, _s, _p, _i, method, _args, invocation):
    if method in ("Activate", "SecondaryActivate"):
        say("toggle")
    invocation.return_value(None)


def props(entry):
    ident, label, _ = entry
    if label is None:
        return {"type": GLib.Variant("s", "separator")}
    return {"label": GLib.Variant("s", label.replace("_", "__")), "enabled": GLib.Variant("b", True), "visible": GLib.Variant("b", True)}


def layout(parent):
    if parent == 0:
        kids = [GLib.Variant("(ia{sv}av)", (e[0], props(e), [])) for e in MENU]
        return (0, {"children-display": GLib.Variant("s", "submenu")}, kids)
    for e in MENU:
        if e[0] == parent:
            return (parent, props(e), [])
    return (parent, {}, [])


def event(ident, kind):
    if kind == "clicked":
        for e in MENU:
            if e[0] == ident and e[2]:
                say(e[2])


def menu_property(_c, _s, _p, _i, name):
    return {"Version": GLib.Variant("u", 3), "Status": GLib.Variant("s", "normal"),
            "TextDirection": GLib.Variant("s", "ltr"), "IconThemePath": GLib.Variant("as", [])}.get(name)


def menu_call(_c, _s, _p, _i, method, args, invocation):
    a = args.unpack()
    if method == "GetLayout":
        out = GLib.Variant("(u(ia{sv}av))", (1, layout(a[0])))
    elif method == "GetGroupProperties":
        out = GLib.Variant("(a(ia{sv}))", ([(e[0], props(e)) for e in MENU if not a[0] or e[0] in a[0]],))
    elif method == "GetProperty":
        found = [props(e) for e in MENU if e[0] == a[0]]
        out = GLib.Variant("(v)", (found[0].get(a[1], GLib.Variant("s", "")) if found else GLib.Variant("s", ""),))
    elif method == "Event":
        event(a[0], a[1])
        out = None
    elif method == "EventGroup":
        for ident, kind, _data, _time in a[0]:
            event(ident, kind)
        out = GLib.Variant("(ai)", ([],))
    elif method == "AboutToShow":
        out = GLib.Variant("(b)", (False,))
    else:
        out = GLib.Variant("(aiai)", ([], []))
    invocation.return_value(out)


def register(bus, name):
    def done(conn, result):
        try:
            conn.call_finish(result)
        except GLib.Error as error:
            print("widgetdeck tray: " + error.message, file=sys.stderr)
    bus.call("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher",
             "RegisterStatusNotifierItem", GLib.Variant("(s)", (name,)), None, Gio.DBusCallFlags.NONE, -1, None, done)


# end together with the shell that started us
ctypes.CDLL(None).prctl(1, signal.SIGTERM)
loop = GLib.MainLoop()
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
NAME = "org.kde.StatusNotifierItem-%d-1" % os.getpid()
bus.register_object("/StatusNotifierItem", Gio.DBusNodeInfo.new_for_xml(ITEM_XML).interfaces[0], item_call, item_property, None)
bus.register_object("/MenuBar", Gio.DBusNodeInfo.new_for_xml(MENU_XML).interfaces[0], menu_call, menu_property, None)
Gio.bus_own_name_on_connection(bus, NAME, Gio.BusNameOwnerFlags.NONE, None, None)
# register whenever a tray (watcher) appears: also after the bar was restarted
Gio.bus_watch_name_on_connection(bus, "org.kde.StatusNotifierWatcher", Gio.BusNameWatcherFlags.NONE, lambda *_: register(bus, NAME), None)
loop.run()
