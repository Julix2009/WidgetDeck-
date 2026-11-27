#!/usr/bin/env python3
"""GitHub helper: unwritable cache and the pause after "rate limited" (no network): python3 tools/github-test.py"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("gh", os.path.join(HERE, "..", "qml", "widgets", "github", "github.py"))
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
fails, calls = 0, []


def ok(name, cond, val=None):
    global fails
    fails += 0 if cond else 1
    print("ok  " if cond else "FAIL", name, "" if cond else val)


def good(user):
    calls.append(user)
    return g.finish(user, [{"d": "2026-01-01", "c": 1, "l": 1}], 1, "public")


def limited(user):
    calls.append(user)
    raise g.Problem("ratelimit")


g.shutil.which = lambda _: None
sys.argv = ["github.py", "someone"]
tmp = tempfile.mkdtemp()
blocker = os.path.join(tmp, "file"); open(blocker, "w").close()
g.CACHE, g.from_public = os.path.join(blocker, "x"), good
try:
    r = g.main()
except OSError as e:
    r = {"state": str(e)}
ok("unwritable cache: the fetched data is still returned", r["state"] == "ok", r)
g.CACHE, g.from_public = os.path.join(tmp, "c"), limited
del calls[:]
a, b = g.main(), g.main()
ok("after 'rate limited' the next call makes no request", len(calls) == 1 and a["error"] == b["error"] == "ratelimit", (calls, a, b))
sys.exit(1 if fails else 0)
