#!/usr/bin/env python3
"""layersample.py <sig> <seconds> <x> <y> <out.json>: polls the layer-shell surfaces of the compositor (hyprctl socket, as fast as it answers) and records
the size of the (widget, not the bar) surface whose top-left corner is nearest to the hint (x, y); a widget keeps its layer corner while it changes size: the exact timeline of a size animation, independent of what is drawn inside."""
import json
import os
import socket
import sys
import time

sig, secs, x, y, out = sys.argv[1], float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
path = "/run/user/%d/hypr/%s/.socket.sock" % (os.getuid(), sig)


def layers():
    s = socket.socket(socket.AF_UNIX); s.connect(path); s.sendall(b"j/layers")
    buf = b""
    while True:
        d = s.recv(65536)
        if not d:
            break
        buf += d
    s.close()
    return json.loads(buf)


rows = []
t0 = time.time()
while time.time() - t0 < secs:
    t = time.time() - t0
    best = None
    for mon in layers().values():
        for lvl in mon.get("levels", {}).values():
            for l in lvl:
                if str(l.get("namespace", "")).startswith("widgetdeck") and l["h"] > 100:
                    d = abs(l["x"] - x) + abs(l["y"] - y)
                    if d < 150 and (best is None or d < best[0]):
                        best = (d, l["x"], l["y"], l["w"], l["h"])
    if best:
        rows.append([round(t, 4), best[1], best[2], best[3], best[4]])
json.dump(rows, open(out, "w"))
