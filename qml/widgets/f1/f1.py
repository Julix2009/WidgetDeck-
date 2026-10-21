#!/usr/bin/env python3
"""Data helper of the F1 widget (Python standard library only). Prints ONE line of JSON.

    f1.py fetch                 calendar of the current season + last result + driver standings, from the cache or (when due) the network
    f1.py live                  the running session (OpenF1: flag + top three); only asked for while a session runs and the widget is visible
    f1.py demo <scenario> [circuitId]   invented data for tests and screenshots (no network): weekend | sprint | running | finished | seasonend | cancelled | noresult
    f1.py doctor                reachability of the data sources and the age of the cache (human readable)

Sources (all free, no key, HTTPS with certificate verification): Jolpica-F1 (https://api.jolpi.ca/ergast/f1/, successor of the Ergast API) for the calendar,
results and standings; OpenF1 (https://api.openf1.org/v1/) for cancelled sessions and the optional live view. No scraping, no images, no logos.
Rate limits: the calendar is loaded at most once a day, results / standings every 6 hours (every 10 minutes while a finished race has no result yet),
every source backs off exponentially after an error and obeys Retry-After on 429. All requests are counted in the cache (field "req").
Cache: ${XDG_CACHE_HOME:-~/.cache}/widgetdeck/f1.json. Test hooks: F1_JOLPICA / F1_OPENF1 (base URLs, plain http allowed only with WIDGETDECK_F1_TEST=1),
F1_NOW (ISO time that replaces the clock), F1_CACHE (cache file).
"""
import datetime
import fcntl
import json
import os
import ssl
import sys
import time
import urllib.error
import urllib.request

JOLPICA = os.environ.get("F1_JOLPICA", "https://api.jolpi.ca/ergast/f1").rstrip("/")
OPENF1 = os.environ.get("F1_OPENF1", "https://api.openf1.org/v1").rstrip("/")
TEST = os.environ.get("WIDGETDECK_F1_TEST") == "1"
UA = "WidgetDeck-F1-widget/1 (unofficial fan widget)"
CACHE = os.environ.get("F1_CACHE") or os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "widgetdeck", "f1.json")

CAL_EVERY = 24 * 3600
STD_EVERY = 6 * 3600
PENDING_EVERY = 600
SESSION_MIN = {"FirstPractice": 60, "SecondPractice": 60, "ThirdPractice": 60, "SprintQualifying": 45, "Sprint": 35, "Qualifying": 65, "Race": 130}
ORDER = ["FirstPractice", "SecondPractice", "ThirdPractice", "SprintQualifying", "Sprint", "Qualifying", "Race"]


def now():
    v = os.environ.get("F1_NOW")
    if v:
        return parse_iso(v)
    return time.time()


def parse_iso(s):
    s = s.strip().replace("Z", "+00:00")
    d = datetime.datetime.fromisoformat(s)
    if d.tzinfo is None:
        d = d.replace(tzinfo=datetime.timezone.utc)
    return d.timestamp()


def iso(ts):
    return datetime.datetime.fromtimestamp(ts, datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def out(o):
    sys.stdout.write(json.dumps(o, separators=(",", ":"), ensure_ascii=False) + "\n")


# ---------------------------------------------------------------------------------------------------------------- cache
def load_cache():
    try:
        with open(CACHE, encoding="utf-8") as f:
            c = json.load(f)
        if isinstance(c, dict) and c.get("v") == 1:
            return c
    except (OSError, ValueError):
        pass
    return {"v": 1, "cal": None, "std": None, "last": None, "cancel": None, "removed": [], "backoff": {}, "req": []}


def save_cache(c):
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(c, f, separators=(",", ":"), ensure_ascii=False)
    os.replace(tmp, CACHE)


class Blocked(Exception):
    pass


def http_json(c, host, url, t):
    """GET a JSON document. Honours the back-off of the host, counts the request, sets the back-off on errors."""
    bo = c["backoff"].setdefault(host, {"until": 0, "fails": 0})
    if bo["until"] > t:
        raise Blocked(host)
    if not url.startswith("https://") and not (TEST and url.startswith("http://127.0.0.1")):
        raise ValueError("only https is allowed")
    c["req"].append([int(t), host + " " + url.split("?")[0].replace(JOLPICA, "").replace(OPENF1, "")])
    c["req"] = c["req"][-400:]
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15, context=ssl.create_default_context()) as r:
            data = json.loads(r.read().decode("utf-8"))
        bo["fails"] = 0
        bo["until"] = 0
        return data
    except urllib.error.HTTPError as e:
        wait = None
        if e.code == 429:
            try:
                wait = int(e.headers.get("Retry-After", ""))
            except (TypeError, ValueError):
                wait = None
        bo["fails"] += 1
        bo["until"] = t + (wait if wait else min(7200, 300 * 2 ** (bo["fails"] - 1)))
        raise
    except (urllib.error.URLError, OSError, ValueError):
        bo["fails"] += 1
        bo["until"] = t + min(7200, 300 * 2 ** (bo["fails"] - 1))
        raise


# ---------------------------------------------------------------------------------------------------------------- parsing
def to_ts(date, tm):
    """('2026-10-25', '20:00:00Z') -> epoch; None when there is no time."""
    if not date or not tm:
        return None
    try:
        return parse_iso(date + "T" + tm)
    except ValueError:
        return None


def parse_calendar(d):
    t = d["MRData"]["RaceTable"]
    races = []
    for r in t.get("Races", []):
        circ = r.get("Circuit") or {}
        loc = circ.get("Location") or {}
        sessions = []
        for key in ORDER:
            s = r if key == "Race" else r.get(key)
            if not s or not s.get("date"):
                continue
            ts = to_ts(s.get("date"), s.get("time"))
            sessions.append({"key": key, "start": iso(ts) if ts is not None else None, "date": s.get("date")})
        races.append({
            "round": int(r["round"]), "name": r.get("raceName") or "", "circuitId": circ.get("circuitId") or "", "circuitName": circ.get("circuitName") or "",
            "locality": loc.get("locality") or "", "country": loc.get("country") or "", "date": r.get("date"), "sessions": sessions, "cancelled": False,
        })
    return {"season": int(t.get("season") or 0), "races": races}


def parse_last(d):
    t = d["MRData"]["RaceTable"]
    if not t.get("Races"):
        return None
    r = t["Races"][0]
    pod = []
    for x in (r.get("Results") or [])[:3]:
        dr = x.get("Driver") or {}
        pod.append({"pos": int(x.get("position") or 0), "code": dr.get("code") or "", "name": ((dr.get("givenName") or "") + " " + (dr.get("familyName") or "")).strip(),
                    "team": (x.get("Constructor") or {}).get("name") or ""})
    return {"round": int(r["round"]), "name": r.get("raceName") or "", "date": r.get("date"), "podium": pod}


def parse_standings(d):
    sl = d["MRData"]["StandingsTable"].get("StandingsLists") or []
    if not sl:
        return None
    rows = []
    for x in sl[0].get("DriverStandings", [])[:10]:
        dr = x.get("Driver") or {}
        cons = x.get("Constructors") or []
        rows.append({"pos": int(x.get("position") or 0), "code": dr.get("code") or "", "name": ((dr.get("givenName") or "") + " " + (dr.get("familyName") or "")).strip(),
                     "team": cons[0].get("name") if cons else "", "points": float(x.get("points") or 0)})
    return {"round": int(sl[0].get("round") or 0), "drivers": rows}


def cancelled_dates(sessions):
    """OpenF1 sessions of the season -> set of 'YYYY-MM-DD' of races that are flagged cancelled."""
    s = set()
    for x in sessions:
        if x.get("session_name") == "Race" and x.get("is_cancelled") is True and x.get("date_start"):
            s.add(x["date_start"][:10])
    return sorted(s)


# ---------------------------------------------------------------------------------------------------------------- refresh policy
def pending_result(c, t):
    """A race has finished (start + its length + 30 min) but the last result in the cache is older: ask every 10 minutes until it appears."""
    cal = c.get("cal")
    if not cal:
        return False
    last = (c.get("last") or {}).get("round", 0)
    for r in cal["races"]:
        rs = [s for s in r["sessions"] if s["key"] == "Race" and s["start"]]
        if rs and r["round"] > last and parse_iso(rs[0]["start"]) + (SESSION_MIN["Race"] + 30) * 60 <= t <= parse_iso(rs[0]["start"]) + 4 * 24 * 3600:
            return True
    return False


def refresh(c, t):
    errors = []
    cal = c.get("cal")
    if cal is None or t - cal["at"] >= CAL_EVERY:
        try:
            new = parse_calendar(http_json(c, "jolpica", JOLPICA + "/current.json?limit=40", t))
            old = (cal or {}).get("races", [])
            removed = [r for r in c.get("removed", []) if t - parse_iso(r["date"] + "T00:00:00Z") < 20 * 24 * 3600]
            if old and cal.get("season") == new["season"]:
                have = {r["round"]: r for r in new["races"]}
                for o in old:
                    n = have.get(o["round"])
                    if n and n["date"] != o["date"]:
                        n["moved_from"] = o["date"]
                    elif not n and not any(x["date"] == o["date"] for x in new["races"]):
                        # a race that used to be in the calendar and is gone: cancelled (or moved to a date that is not known yet)
                        if parse_iso(o["date"] + "T00:00:00Z") > t - 20 * 24 * 3600 and not any(x["name"] == o["name"] for x in removed):
                            removed.append({"name": o["name"], "date": o["date"], "round": o["round"]})
            c["removed"] = removed
            try:
                of = http_json(c, "openf1", OPENF1 + "/sessions?year=" + str(new["season"] or datetime.datetime.utcfromtimestamp(t).year), t)
                cd = cancelled_dates(of if isinstance(of, list) else [])
                for r in new["races"]:
                    if r["date"] and any(abs((parse_iso(r["date"] + "T00:00:00Z") - parse_iso(d + "T00:00:00Z"))) <= 24 * 3600 for d in cd):
                        r["cancelled"] = True
            except (urllib.error.URLError, OSError, ValueError, Blocked):
                pass                                                   # the cancel flags are a bonus
            new["at"] = int(t)
            c["cal"] = new
        except Blocked:
            pass
        except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
            errors.append("calendar: " + str(e)[:80])
    due_pending = pending_result(c, t)
    std = c.get("std")
    if std is None or t - std["at"] >= (PENDING_EVERY if due_pending else STD_EVERY):
        try:
            s = parse_standings(http_json(c, "jolpica", JOLPICA + "/current/driverStandings.json", t))
            if s:
                s["at"] = int(t)
                c["std"] = s
            last = parse_last(http_json(c, "jolpica", JOLPICA + "/current/last/results.json", t))
            if last:
                last["at"] = int(t)
                c["last"] = last
            if not s and not last and std is None:
                c["std"] = {"at": int(t), "round": 0, "drivers": []}     # new season without results yet: do not ask again at once
        except Blocked:
            pass
        except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
            errors.append("results: " + str(e)[:80])
    return errors


def fetch():
    lock = open(CACHE + ".lock", "a") if os.path.isdir(os.path.dirname(CACHE)) else None
    if lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
    try:
        c = load_cache()
        t = now()
        errors = refresh(c, t)
        save_cache(c)
    finally:
        if lock:
            fcntl.flock(lock, fcntl.LOCK_UN)
            lock.close()
    cal = c.get("cal")
    if not cal:
        out({"state": "error" if errors else "empty", "errors": errors, "fetched": 0})
        return
    ats = [x["at"] for x in (cal, c.get("std"), c.get("last")) if x]
    out({"state": "ok", "season": cal["season"], "total": len(cal["races"]), "races": cal["races"], "removed": c.get("removed", []), "last": c.get("last"), "standings": (c.get("std") or {}).get("drivers", []),
         "standings_round": (c.get("std") or {}).get("round", 0), "fetched": cal["at"], "checked": max(ats), "stale": bool(errors) or t - cal["at"] > 2 * CAL_EVERY, "errors": errors,
         "source": "jolpica"})


# ---------------------------------------------------------------------------------------------------------------- live (OpenF1)
def live():
    c = load_cache()
    t = now()
    try:
        ss = http_json(c, "openf1", OPENF1 + "/sessions?date_start%3C=" + iso(t) + "&date_end%3E=" + iso(t), t)
        if not isinstance(ss, list) or not ss:
            save_cache(c)
            out({"running": False})
            return
        s = ss[-1]
        key = s["session_key"]
        names = c.setdefault("drivers", {})
        if str(key) not in names:
            dr = http_json(c, "openf1", OPENF1 + "/drivers?session_key=" + str(key), t)
            names[str(key)] = {str(d["driver_number"]): {"code": d.get("name_acronym") or "", "team": d.get("team_name") or "", "name": d.get("full_name") or ""} for d in dr if "driver_number" in d}
            c["drivers"] = {str(key): names[str(key)]}
        pos = http_json(c, "openf1", OPENF1 + "/position?session_key=" + str(key) + "&date%3E=" + iso(t - 300), t)
        rc = http_json(c, "openf1", OPENF1 + "/race_control?session_key=" + str(key) + "&date%3E=" + iso(t - 1200), t)
        save_cache(c)
        latest = {}
        for p in pos if isinstance(pos, list) else []:
            n = p.get("driver_number")
            if n is not None and (n not in latest or p.get("date", "") >= latest[n].get("date", "")):
                latest[n] = p
        top = sorted(latest.values(), key=lambda p: p.get("position") or 99)[:3]
        flag = None
        for m in sorted(rc if isinstance(rc, list) else [], key=lambda m: m.get("date", "")):
            if m.get("category") == "Flag" and m.get("flag"):
                flag = m["flag"]
            elif m.get("category") == "SafetyCar":
                flag = "SC" if "DEPLOYED" in (m.get("message") or "").upper() else flag
        out({"running": True, "session": s.get("session_name"), "key": key, "flag": flag,
             "top": [{"pos": p.get("position"), "code": names[str(key)].get(str(p.get("driver_number")), {}).get("code", ""), "team": names[str(key)].get(str(p.get("driver_number")), {}).get("team", "")} for p in top]})
    except Blocked:
        out({"running": False, "error": "backoff"})
    except urllib.error.HTTPError as e:
        save_cache(c)
        out({"running": False, "error": "http " + str(e.code)})
    except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
        save_cache(c)
        out({"running": False, "error": str(e)[:60]})


# ---------------------------------------------------------------------------------------------------------------- demo (invented, no network)
CIRCUITS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "circuits.json")


def demo(scenario, circuit):
    t = now()
    try:
        with open(CIRCUITS, encoding="utf-8") as f:
            cc = json.load(f)["circuits"]
    except (OSError, ValueError):
        cc = {}
    cid = circuit if circuit and circuit != "auto" else "silverstone"
    ci = cc.get(cid) or {}
    place = ci.get("place") or "Testville"
    h = 3600
    sprint = scenario == "sprint"
    # race start: weekend = 3 days ahead; running = a session that started 20 minutes ago; finished = race ended 40 minutes ago
    race = t + 3 * 24 * h
    if scenario == "running":
        race = t + 24 * h            # Saturday's qualifying is running: the race is tomorrow
    elif scenario in ("finished", "noresult"):
        race = t - (SESSION_MIN["Race"] + 40) * 60
    elif scenario == "seasonend":
        race = t - 3 * 24 * h
    race = (race // 900) * 900
    keys = ["FirstPractice", "SprintQualifying", "Sprint", "Qualifying", "Race"] if sprint else ["FirstPractice", "SecondPractice", "ThirdPractice", "Qualifying", "Race"]
    offs = {"FirstPractice": -48 * h - 3 * h, "SecondPractice": -48 * h + 1 * h, "ThirdPractice": -24 * h - 3 * h, "SprintQualifying": -48 * h + 1.5 * h, "Sprint": -24 * h - 4 * h, "Qualifying": -24 * h + 1 * h, "Race": 0}
    sessions = []
    for k in keys:
        st = race + offs[k]
        if scenario == "running" and k == "Qualifying":
            st = t - 20 * 60
        sessions.append({"key": k, "start": iso(st), "date": iso(st)[:10]})
    if scenario == "running":
        sessions[-1]["start"] = iso(t + 22 * h)
    if scenario == "weekend" and circuit == "__missing_time__":
        sessions[1]["start"] = None
    year = datetime.datetime.utcfromtimestamp(t).year
    mk = lambda rd, name, st, cid2, cancelled=False: {"round": rd, "name": name, "circuitId": cid2, "circuitName": (cc.get(cid2) or {}).get("name") or name, "locality": (cc.get(cid2) or {}).get("place") or place,
                                                      "country": "Testland", "date": iso(st)[:10], "sessions": [{"key": "Race", "start": iso(st), "date": iso(st)[:10]}], "cancelled": cancelled}
    races = [mk(20, "Test Grand Prix", race - 14 * 24 * h, "monza"), {"round": 21, "name": "Grand Prix of " + place, "circuitId": cid, "circuitName": ci.get("name") or "Test Circuit", "locality": place, "country": "Testland",
                                                                      "date": iso(race)[:10], "sessions": sessions, "cancelled": scenario == "cancelled"}]
    if scenario != "seasonend":
        races.append(mk(22, "Second Test Grand Prix", race + 14 * 24 * h, "spa"))
        races.append(mk(23, "Third Test Grand Prix", race + 28 * 24 * h, "suzuka"))
    last = {"round": 20 if scenario not in ("finished", "seasonend") else 21, "name": "Test Grand Prix" if scenario not in ("finished",) else "Grand Prix of " + place, "date": iso(race - 14 * 24 * h)[:10],
            "podium": [{"pos": 1, "code": "AAA", "name": "Anna Alpha", "team": "Team Red"}, {"pos": 2, "code": "BBB", "name": "Ben Bravo", "team": "Team Blue"}, {"pos": 3, "code": "CCC", "name": "Cleo Charlie", "team": "Team Green"}]}
    if scenario == "noresult":
        last = None
    drivers = [{"pos": i + 1, "code": c, "name": n, "team": tm, "points": 300 - 37 * i} for i, (c, n, tm) in enumerate([("AAA", "Anna Alpha", "Team Red"), ("BBB", "Ben Bravo", "Team Blue"), ("CCC", "Cleo Charlie", "Team Green"), ("DDD", "Dan Delta", "Team Red"),
                                                                                                                       ("EEE", "Eli Echo", "Team Blue"), ("FFF", "Fay Foxtrot", "Team Green"), ("GGG", "Gus Golf", "Team Gold"), ("HHH", "Hal Hotel", "Team Gold"),
                                                                                                                       ("III", "Ida India", "Team Violet"), ("JJJ", "Jo Juliet", "Team Violet")])]
    removed = [{"name": "Cancelled Test Grand Prix", "date": iso(race + 7 * 24 * h)[:10], "round": 99}] if scenario == "cancelled" else []
    out({"state": "ok", "season": year, "total": 24, "races": races, "removed": removed, "last": last, "standings": drivers, "standings_round": 21, "fetched": int(t) - 600, "checked": int(t) - 600, "stale": False, "errors": [], "source": "demo"})


# ---------------------------------------------------------------------------------------------------------------- doctor
def doctor():
    c = load_cache()
    t = now()
    for name, url in (("Jolpica-F1", JOLPICA + "/current/next.json"), ("OpenF1", OPENF1 + "/sessions?session_key=latest")):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=10, context=ssl.create_default_context()) as r:
                json.loads(r.read().decode("utf-8"))
            print(name + ": reachable")
        except urllib.error.HTTPError as e:
            print(name + ": HTTP " + str(e.code))
        except (urllib.error.URLError, OSError, ValueError) as e:
            print(name + ": not reachable (" + str(e)[:50] + ")")
    for key, label in (("cal", "calendar"), ("std", "standings"), ("last", "last result")):
        v = c.get(key)
        print("cache " + label + ": " + (("age %d min" % ((t - v["at"]) // 60)) if v else "none"))
    day = [r for r in c.get("req", []) if t - r[0] < 86400]
    print("requests in the last 24 h: %d" % len(day))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    if cmd == "fetch":
        fetch()
    elif cmd == "live":
        live()
    elif cmd == "demo":
        demo(sys.argv[2] if len(sys.argv) > 2 else "weekend", sys.argv[3] if len(sys.argv) > 3 else "")
    elif cmd == "doctor":
        doctor()
    else:
        sys.exit(__doc__)


main()
