#!/usr/bin/env python3
"""Data of the GitHub activity widget: the contribution calendar, as one JSON line.

    github.py [user]          user empty = the account the GitHub CLI is logged in with; "demo" = invented data

With a user name the public contributions page is read (no login, no token). Without one the GitHub CLI is asked
(`gh api graphql`, the token stays inside gh) - and for a user name it is tried first, if it is installed and logged in.
The answer is cached for 30 minutes; when a request fails the last answer is returned with "stale": true.
"""
import datetime as dt
import html
import json
import os
import random
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

TTL = 1800
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "widgetdeck")
LEVELS = {"NONE": 0, "FIRST_QUARTILE": 1, "SECOND_QUARTILE": 2, "THIRD_QUARTILE": 3, "FOURTH_QUARTILE": 4}
FIELDS = "login contributionsCollection { contributionCalendar { totalContributions weeks { contributionDays { date contributionCount contributionLevel } } } }"

class Problem(Exception):
    pass


def finish(user, days, total, source):
    days = sorted(days, key=lambda d: d["d"])
    # the current streak may end yesterday: today is not over yet
    current = 0
    for i, d in enumerate(reversed(days)):
        if d["c"] > 0:
            current += 1
        elif i > 0:
            break
    return {"state": "ok", "user": user, "days": days, "total": total, "streak": current,
            "today": days[-1]["c"] if days else 0, "source": source, "fetched": int(time.time())}


# ───────────── GitHub CLI ─────────────
def from_gh(user):
    head = "query($login: String!) { user(login: $login) { " if user else "query { viewer { "
    cmd = ["gh", "api", "graphql", "-f", "query=" + head + FIELDS + " } }"]
    if user:
        cmd += ["-f", "login=" + user]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=40)
    if r.returncode != 0:
        raise Problem("notfound" if "Could not resolve to a User" in r.stderr + r.stdout else "gh")
    u = json.loads(r.stdout)["data"]["user" if user else "viewer"]
    cal = u["contributionsCollection"]["contributionCalendar"]
    days = [{"d": d["date"], "c": d["contributionCount"], "l": LEVELS.get(d["contributionLevel"], 0)} for w in cal["weeks"] for d in w["contributionDays"]]
    return finish(u["login"], days, cal["totalContributions"], "gh")


# ───────────── public pages, no token ─────────────
def get(url):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "WidgetDeck", "Accept": "text/html"})
        with urllib.request.urlopen(req, timeout=25) as r:
            return r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raise Problem("notfound" if e.code == 404 else ("ratelimit" if e.code in (403, 429) else "network"))
    except (urllib.error.URLError, TimeoutError, OSError):
        raise Problem("network")


def parse_calendar(page):
    counts = {}
    for target, text in re.findall(r'<tool-tip[^>]*\bfor="([^"]+)"[^>]*>(.*?)</tool-tip>', page, re.S):
        m = re.match(r"\s*([\d,]+) contribution", html.unescape(text))
        counts[target] = int(m.group(1).replace(",", "")) if m else 0
    days = []
    for tag in re.findall(r"<td[^>]*\bdata-date=[^>]*>", page):
        a = dict(re.findall(r'([\w-]+)="([^"]*)"', tag))
        days.append({"d": a["data-date"], "c": counts.get(a.get("id"), 0), "l": int(a.get("data-level", 0))})
    return days


def from_public(user):
    days = parse_calendar(get("https://github.com/users/%s/contributions" % user))
    if not days:
        raise Problem("network")
    return finish(user, days, sum(d["c"] for d in days), "public")


def demo():
    rnd = random.Random(7)
    today = dt.date.today()
    start = today - dt.timedelta(days=364 + (today.weekday() + 1) % 7)
    days = []
    for i in range((today - start).days + 1):
        busy = rnd.random() < (0.28 if i < 300 else 0.75)
        c = rnd.choice((1, 1, 2, 3, 5, 8, 13)) if busy else 0
        days.append({"d": (start + dt.timedelta(days=i)).isoformat(), "c": c, "l": 0 if not c else (1 if c < 3 else 2 if c < 5 else 3 if c < 9 else 4)})
    return finish("demo", days, sum(d["c"] for d in days), "demo")


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def write_json(path, data):
    """Atomic; a cache that cannot be written (disk full, read-only) never loses the answer that was just fetched."""
    tmp = None
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        fd, tmp = tempfile.mkstemp(suffix=".tmp", dir=os.path.dirname(path))
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f)
        os.replace(tmp, path)
    except OSError:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)


def main():
    user = (sys.argv[1] if len(sys.argv) > 1 else "").strip().lstrip("@")
    if user == "demo":
        return demo()
    if user and not re.fullmatch(r"[A-Za-z0-9-]{1,39}", user):
        return {"state": "error", "error": "notfound"}
    path = os.path.join(CACHE, "github-%s.json" % (user.lower() or "_own"))
    old = read_json(path)
    try:
        if old and time.time() - old["fetched"] < TTL:
            return old
    except (KeyError, TypeError):
        old = None
    # after "rate limited" GitHub is left alone for a while: 30 min, doubling up to 4 h
    held = path + ".backoff"
    hold = read_json(held) or {}
    if hold.get("until", 0) > time.time():
        if old:
            old["stale"] = True
            return old
        return {"state": "error", "error": "ratelimit"}
    try:
        data = None
        if shutil.which("gh"):
            try:
                data = from_gh(user)
            except (Problem, subprocess.SubprocessError, ValueError, KeyError) as e:
                if str(e) == "notfound":
                    raise Problem("notfound")
        if data is None:
            if not user:
                raise Problem("nouser")
            data = from_public(user)
    except Problem as e:
        if str(e) == "ratelimit":
            fails = min(hold.get("fails", 0) + 1, 4)
            write_json(held, {"fails": fails, "until": time.time() + min(14400, 1800 * 2 ** (fails - 1))})
        if old:
            old["stale"] = True
            return old
        return {"state": "error", "error": str(e)}
    write_json(path, data)
    if hold:
        try:
            os.unlink(held)
        except OSError:
            pass
    return data


if __name__ == "__main__":
    print(json.dumps(main()))
