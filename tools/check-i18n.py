#!/usr/bin/env python3
"""Checks the UI texts: every English source text must have a German entry in qml/core/i18n.js, and no entry may be unused.

Source texts are the literals in I18n.tr("...") / I18n.trf("..."), plus the label / desc / option texts in qml/widgets/Registry.js and
qml/core/Defaults.js (those files cannot call I18n; the builder translates them when it shows them).
Usage: tools/check-i18n.py [--print-missing]      exit code 1 when something is missing
"""
import json, re, sys, pathlib

root = pathlib.Path(__file__).resolve().parent.parent / "qml"
LIT = r'"((?:[^"\\\n]|\\.)*)"'

def unescape(s):
    try:
        return json.loads('"' + s + '"')
    except Exception:
        return s

keys = {}
for f in sorted(root.rglob("*.qml")):
    for m in re.finditer(r'I18n\.trf?\(\s*' + LIT, f.read_text(encoding="utf-8")):
        keys.setdefault(unescape(m.group(1)), f.name)
for name in ("widgets/Registry.js", "core/Defaults.js"):
    t = (root / name).read_text(encoding="utf-8")
    for m in re.finditer(r'\b(?:label|desc):\s*' + LIT, t):
        keys.setdefault(unescape(m.group(1)), name)
    for m in re.finditer(r'\[\s*"[^"]*"\s*,\s*' + LIT + r'\s*\]', t):
        keys.setdefault(unescape(m.group(1)), name)
    if name == "core/Defaults.js":
        for m in re.finditer(r'^\s*"([^"]+)":\s*\{', t, re.M):           # preset names
            keys.setdefault(m.group(1), name)

js = (root / "core/i18n.js").read_text(encoding="utf-8")
body = re.search(r'var de = (\{.*?\n\});', js, re.S).group(1)
de = json.loads(body)

missing = [k for k in keys if k not in de]
unused = [k for k in de if k not in keys]
for k in missing:
    print("missing German text: %r   (%s)" % (k, keys[k]))
for k in unused:
    print("unused entry: %r" % k)
print("%d texts, %d German entries, %d missing, %d unused" % (len(keys), len(de), len(missing), len(unused)))
sys.exit(1 if missing else 0)
