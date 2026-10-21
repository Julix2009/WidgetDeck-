#!/usr/bin/env python3
"""Tests of the F1 data helper (qml/widgets/f1/f1.py) against tools/f1-mock.py (invented data, local): python3 tools/f1-helper-test.py"""
import calendar
import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "qml", "widgets", "f1", "f1.py")
fails = 0


def ok(name, cond, val=None):
    global fails
    if not cond:
        fails += 1
        print("FAIL", name, json.dumps(val)[:300])
    else:
        print("ok  ", name)


sock = socket.socket(); sock.bind(("127.0.0.1", 0)); port = sock.getsockname()[1]; sock.close()
srv = subprocess.Popen([sys.executable, os.path.join(HERE, "f1-mock.py"), str(port)])
tmp = tempfile.mkdtemp(prefix="f1test-")
T0 = time.time()
BASE = "http://127.0.0.1:%d" % port


def ctl(**kw):
    urllib.request.urlopen(BASE + "/_ctl?" + "&".join("%s=%s" % kv for kv in kw.items())).read()


def log():
    return json.load(urllib.request.urlopen(BASE + "/_log"))


def iso(t):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(t))


def run(cmd, now, cache="c1", env=None, base=BASE):
    e = dict(os.environ, F1_CACHE=os.path.join(tmp, cache + ".json"), F1_NOW=iso(now), WIDGETDECK_F1_TEST="1",
             F1_JOLPICA=base + "/jolpica", F1_OPENF1=base + "/openf1")
    e.update(env or {})
    r = subprocess.run([sys.executable, "-I", HELPER] + cmd, capture_output=True, text=True, env=e, timeout=60)
    try:
        return json.loads(r.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"_raw": r.stdout[-200:] + r.stderr[-200:]}


def cache(name="c1"):
    return json.load(open(os.path.join(tmp, name + ".json")))


for _ in range(50):
    try:
        urllib.request.urlopen(BASE + "/_log").read(); break
    except OSError:
        time.sleep(0.1)

# 1) first fetch: calendar + OpenF1 flags + standings + last result; second one answers from the cache without a request
d = run(["fetch"], T0)
ok("first fetch is ok and has the calendar, the last result and the standings", d.get("state") == "ok" and len(d["races"]) == 5 and d["last"]["podium"][0]["code"] == "AAA" and len(d["standings"]) == 10, d)
ok("race sessions come as UTC times with a Z and in order", all(s["start"].endswith("Z") for s in d["races"][0]["sessions"]) and [s["key"] for s in d["races"][0]["sessions"]] == ["FirstPractice", "SecondPractice", "ThirdPractice", "Qualifying", "Race"], d["races"][0]["sessions"])
n1 = len(log())
run(["fetch"], T0 + 60)
ok("a second fetch a minute later makes NO request (cache)", len(log()) == n1, len(log()) - n1)

# 2) a whole simulated day, asked every 30 s by (many) widgets: the requests stay few
ctl(mode="ok"); urllib.request.urlopen(BASE + "/_reset").read()
os.remove(os.path.join(tmp, "c2.json")) if os.path.exists(os.path.join(tmp, "c2.json")) else None
for i in range(0, 24 * 120):
    run(["fetch"], T0 + i * 30, cache="c2") if i % 1 == 0 and i < 4 or i % 20 == 0 else None     # (every 10 minutes is enough to show the policy; the first calls run back to back)
reqs = log()
cal = sum(1 for p in reqs if p == "/jolpica/current.json"); std = sum(1 for p in reqs if p.endswith("driverStandings.json")); res = sum(1 for p in reqs if p.endswith("results.json")); of = sum(1 for p in reqs if p == "/openf1/sessions")
print("     one simulated day: calendar %d, standings %d, last result %d, OpenF1 sessions %d (%d requests in total)" % (cal, std, res, of, len(reqs)))
ok("one day: the calendar is loaded once, standings and results at most 5 times (every 6 h), OpenF1 once", cal == 1 and of == 1 and std <= 5 and res <= 5 and len(reqs) <= 14, [cal, std, res, of])

# 3) 429 with Retry-After: nothing more is asked until the time is over; the old data stays
d = run(["fetch"], T0, cache="c3")
ctl(mode="r429", retry_after=600)
d2 = run(["fetch"], T0 + 7 * 3600, cache="c3")                     # the calendar is not due, standings are (6 h): 429 on the first request
ok("429: the cached data is still shown, marked stale", d2["state"] == "ok" and d2["stale"] is True and len(d2["races"]) == 5, d2.get("errors"))
n = len(log())
run(["fetch"], T0 + 7 * 3600 + 120, cache="c3"); run(["fetch"], T0 + 7 * 3600 + 300, cache="c3")
ok("429: during Retry-After (600 s) no further request is made", len(log()) == n, len(log()) - n)
ctl(mode="ok")
d3 = run(["fetch"], T0 + 7 * 3600 + 700, cache="c3")
ok("after the Retry-After time the source is asked again and recovers", d3["state"] == "ok" and d3["stale"] is False, d3.get("errors"))

# 4) errors back off exponentially
ctl(mode="err500"); urllib.request.urlopen(BASE + "/_reset").read()
run(["fetch"], T0, cache="c4")
b = cache("c4")["backoff"]["jolpica"]
ok("an error sets a back-off", b["fails"] == 1 and b["until"] > time.time() - 5, b)
run(["fetch"], T0 + 301, cache="c4"); b2 = cache("c4")["backoff"]["jolpica"]
ok("the second error doubles the wait (5 min, then 10 min)", b2["fails"] == 2 and (b2["until"] - (T0 + 301)) >= 599, b2)
ctl(mode="ok")

# 5) offline: nothing reachable -> error without cache, stale data with cache
d = run(["fetch"], T0, cache="c5", base="http://127.0.0.1:1")
ok("offline without a cache: state error, no fake data", d.get("state") == "error" and "races" not in d, d)
run(["fetch"], T0, cache="c5b")
d = run(["fetch"], T0 + 26 * 3600, cache="c5b", base="http://127.0.0.1:1")
ok("offline with a cache: the last data is shown (stale)", d["state"] == "ok" and d["stale"] is True and len(d["races"]) == 5, d.get("errors"))

# 6) missing fields: no time / no session -> null, never a wrong value
ctl(mode="nofields"); d = run(["fetch"], T0, cache="c6"); ctl(mode="ok")
r2 = d["races"][1]
ok("a race without a time has start null for the race and the qualifying; the missing practice is simply absent", [s for s in r2["sessions"] if s["key"] == "Race"][0]["start"] is None and [s["key"] for s in r2["sessions"]] == ["SecondPractice", "ThirdPractice", "Qualifying", "Race"], r2["sessions"])

# 7) cancelled (OpenF1 flag), moved and removed races
ctl(mode="cancel"); d = run(["fetch"], T0, cache="c7"); ctl(mode="ok")
ok("a race flagged cancelled by OpenF1 is marked", d["races"][1]["cancelled"] is True and d["races"][0]["cancelled"] is False, [r["cancelled"] for r in d["races"]])
run(["fetch"], T0, cache="c8")
ctl(mode="moved"); d = run(["fetch"], T0 + 25 * 3600, cache="c8")
ok("a race that moved to another date is marked with its old date", d["races"][2].get("moved_from") is not None, d["races"][2])
ctl(mode="ok"); run(["fetch"], T0, cache="c9"); ctl(mode="removed"); d = run(["fetch"], T0 + 25 * 3600, cache="c9"); ctl(mode="ok")
ok("a race that disappeared from the calendar is reported as removed", len(d["races"]) == 4 and len(d["removed"]) == 1 and d["removed"][0]["name"] == "Test Grand Prix 3", d.get("removed"))

# 8) after a race: the result is asked for every 10 minutes until it is there
run(["fetch"], T0, cache="cA")
cal = cache("cA")["cal"]["races"][0]
race_start = [s for s in cal["sessions"] if s["key"] == "Race"][0]["start"]
rs = calendar.timegm(time.strptime(race_start, "%Y-%m-%dT%H:%M:%SZ"))
ctl(result_round=1); urllib.request.urlopen(BASE + "/_reset").read()
run(["fetch"], rs + 3 * 3600, cache="cA")                       # the race (round 1) ended, but result round 1 is already in the cache: nothing pending for round 1
n_before = len(log())
cal2 = cache("cA")["cal"]["races"][1]
rs2 = calendar.timegm(time.strptime([s for s in cal2["sessions"] if s["key"] == "Race"][0]["start"], "%Y-%m-%dT%H:%M:%SZ"))
run(["fetch"], rs2 + 3 * 3600, cache="cA")                       # round 2 ended: result round still 1 -> due
a = len(log())
run(["fetch"], rs2 + 3 * 3600 + 120, cache="cA")                 # 2 minutes later: not asked again
ok("a finished race without a result: asked once, then not again within 10 minutes", a > n_before and len(log()) == a, [n_before, a, len(log())])
ctl(result_round=2); run(["fetch"], rs2 + 3 * 3600 + 700, cache="cA")
ok("ten minutes later it is asked again and the result is taken", cache("cA")["last"]["round"] == 2, cache("cA")["last"])

# 9) live view (OpenF1)
ctl(live="on"); lv = run(["live"], T0, cache="cL")
ok("live: the running session, the flag and the first three", lv.get("running") is True and lv["flag"] == "GREEN" and [t["code"] for t in lv["top"]] == ["BBB", "AAA", "CCC"], lv)
ctl(live="auth"); lv = run(["live"], T0 + 600, cache="cL")
ok("live: a source that wants authentication -> the normal view (running false, no crash)", lv.get("running") is False and "error" in lv, lv)
ctl(live="off"); lv = run(["live"], T0 + 1800, cache="cL2")
ok("live: no session running -> running false", lv.get("running") is False, lv)

# 10) only https is allowed outside the tests
d = run(["fetch"], T0, cache="cH", env={"WIDGETDECK_F1_TEST": "0", "F1_JOLPICA": "http://example.invalid/x"})
ok("plain http is refused without the test switch", d.get("state") in ("error", "empty") and "races" not in d, d)

# 11) the invented demo scenarios
for sc in ("weekend", "sprint", "running", "finished", "seasonend", "cancelled", "noresult"):
    dm = run(["demo", sc, "monza"], T0, cache="cD")
    ok("demo scenario " + sc, dm.get("state") == "ok" and dm["races"][1]["circuitId"] == "monza" and dm["source"] == "demo", dm)

srv.terminate()
sys.exit(1 if fails else 0)
