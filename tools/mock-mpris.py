#!/usr/bin/env python3
"""Mock MPRIS player for testing the music widget transitions without touching your real player.

    python3 tools/mock-mpris.py [art-dir]        # bus name: org.mpris.MediaPlayer2.widgetdeck_mock
    playerctl -p widgetdeck_mock next|previous|play-pause

Playlist: with cover / long title / no cover / slow cover (HTTP, 2.5 s) / broken cover / ...
"""
import http.server
import os
import sys
import threading
import time

import gi
from gi.repository import Gio, GLib

ART = sys.argv[1] if len(sys.argv) > 1 else "/tmp/claude-1000/mock"
os.makedirs(ART, exist_ok=True)
PORT = 8765

def make_art():
    import subprocess
    cols = [("#2f6bff", "#b44cff"), ("#ff8a3d", "#ff3d6e"), ("#12c27a", "#0b6cff"), ("#ffd23d", "#ff6a3d"), ("#8a3dff", "#ff3dc8"), ("#00c2c7", "#1d2bff")]
    for i, (a, b) in enumerate(cols):
        p = f"{ART}/art{i}.png"
        if not os.path.exists(p):
            subprocess.run(["magick", "-size", "600x600", f"gradient:{a}-{b}", "-rotate", str(20 + 37 * i), "-gravity", "center", "-crop", "600x600+0+0", "+repage",
                            "-fill", "#ffffff55", "-draw", f"circle {150 + 60 * i},{200 + 30 * i} {150 + 60 * i},{80 + 30 * i}",
                            "-fill", "#00000044", "-draw", f"rectangle {320 - 20 * i},{380} {560},{560}", p], check=True)

SONGS = [
    ("Aurora Borealis", "Nova Artist", f"file://{ART}/art0.png"),
    ("A Very Long Song Title That Needs The Marquee To Scroll Across The Widget", "The Extraordinarily Long Named Band Of Testers", f"file://{ART}/art1.png"),
    ("No Cover Here", "Silent Sleeve", ""),
    ("Slow Cover (2.5 s)", "Patient Pixels", f"http://127.0.0.1:{PORT}/art3.png"),
    ("Green Hour", "Chlorophyll", f"file://{ART}/art2.png"),
    ("Broken Cover Link", "404 Collective", f"file://{ART}/does-not-exist.png"),
    ("Purple Rain Check", "Violet Static", f"file://{ART}/art4.png"),
    ("Cyan Drift", "Teal Tide", f"file://{ART}/art5.png"),
]

class Slow(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=ART, **k)
    def do_GET(self): time.sleep(2.5); super().do_GET()
    def log_message(self, *a): pass

XML = """<node>
<interface name="org.mpris.MediaPlayer2">
  <method name="Raise"/><method name="Quit"/>
  <property name="CanQuit" type="b" access="read"/><property name="CanRaise" type="b" access="read"/>
  <property name="HasTrackList" type="b" access="read"/><property name="Identity" type="s" access="read"/>
  <property name="SupportedUriSchemes" type="as" access="read"/><property name="SupportedMimeTypes" type="as" access="read"/>
</interface>
<interface name="org.mpris.MediaPlayer2.Player">
  <method name="Next"/><method name="Previous"/><method name="Pause"/><method name="PlayPause"/><method name="Stop"/><method name="Play"/>
  <method name="Seek"><arg type="x" direction="in"/></method>
  <method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
  <method name="OpenUri"><arg type="s" direction="in"/></method>
  <property name="PlaybackStatus" type="s" access="read"/><property name="Rate" type="d" access="readwrite"/>
  <property name="Metadata" type="a{sv}" access="read"/><property name="Volume" type="d" access="readwrite"/>
  <property name="Position" type="x" access="read"/><property name="MinimumRate" type="d" access="read"/>
  <property name="MaximumRate" type="d" access="read"/><property name="CanGoNext" type="b" access="read"/>
  <property name="CanGoPrevious" type="b" access="read"/><property name="CanPlay" type="b" access="read"/>
  <property name="CanPause" type="b" access="read"/><property name="CanSeek" type="b" access="read"/>
  <property name="CanControl" type="b" access="read"/>
</interface></node>"""

idx, status, t0, pos0 = 0, "Playing", time.time(), 0.0
LENGTH = 200 * 1_000_000

def metadata():
    t, a, art = SONGS[idx]
    d = {"mpris:trackid": GLib.Variant("o", f"/org/mock/track/{idx}_{int(time.time()*1000)}"), "mpris:length": GLib.Variant("x", LENGTH),
         "xesam:title": GLib.Variant("s", t), "xesam:artist": GLib.Variant("as", [a]), "xesam:album": GLib.Variant("s", "Mock Album")}
    if art: d["mpris:artUrl"] = GLib.Variant("s", art)
    return d

def position():
    return int(((pos0 + (time.time() - t0 if status == "Playing" else 0)) * 1_000_000) % LENGTH)

def props(iface):
    if iface == "org.mpris.MediaPlayer2":
        return {"CanQuit": GLib.Variant("b", False), "CanRaise": GLib.Variant("b", False), "HasTrackList": GLib.Variant("b", False),
                "Identity": GLib.Variant("s", "WidgetDeck Mock"), "SupportedUriSchemes": GLib.Variant("as", []), "SupportedMimeTypes": GLib.Variant("as", [])}
    return {"PlaybackStatus": GLib.Variant("s", status), "Rate": GLib.Variant("d", 1.0), "Metadata": GLib.Variant("a{sv}", metadata()),
            "Volume": GLib.Variant("d", 1.0), "Position": GLib.Variant("x", position()), "MinimumRate": GLib.Variant("d", 1.0), "MaximumRate": GLib.Variant("d", 1.0),
            "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True), "CanPlay": GLib.Variant("b", True),
            "CanPause": GLib.Variant("b", True), "CanSeek": GLib.Variant("b", True), "CanControl": GLib.Variant("b", True)}

conn = None
def emit(changed):
    full = props("org.mpris.MediaPlayer2.Player")
    conn.emit_signal(None, "/org/mpris/MediaPlayer2", "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     GLib.Variant("(sa{sv}as)", ("org.mpris.MediaPlayer2.Player", {k: full[k] for k in changed}, [])))

def on_call(c, sender, path, iface, method, params, inv):
    global idx, status, t0, pos0
    if iface == "org.freedesktop.DBus.Properties":
        if method == "Get":
            i, n = params.unpack(); inv.return_value(GLib.Variant("(v)", (props(i)[n],)))
        elif method == "GetAll":
            i = params.unpack()[0]; inv.return_value(GLib.Variant("(a{sv})", (props(i),)))
        else: inv.return_value(None)
        return
    if method in ("Next", "Previous"):
        idx = (idx + (1 if method == "Next" else -1)) % len(SONGS); pos0, t0 = 0.0, time.time()
        emit(["Metadata", "PlaybackStatus"])
    elif method == "PlayPause" or method in ("Pause", "Play"):
        pos0 = position() / 1e6; t0 = time.time()
        status = ("Paused" if status == "Playing" else "Playing") if method == "PlayPause" else ("Paused" if method == "Pause" else "Playing")
        emit(["PlaybackStatus"])
    elif method == "Stop":
        status = "Stopped"; emit(["PlaybackStatus"])
    inv.return_value(None)

def on_bus(c, name):
    global conn
    conn = c
    ni = Gio.DBusNodeInfo.new_for_xml(XML)
    for i in ni.interfaces: c.register_object("/org/mpris/MediaPlayer2", i, on_call, None, None)

make_art()
threading.Thread(target=lambda: http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Slow).serve_forever(), daemon=True).start()
Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.widgetdeck_mock", Gio.BusNameOwnerFlags.NONE, on_bus, None, None)
print("mock player up: playerctl -p widgetdeck_mock next", flush=True)
GLib.MainLoop().run()
