#!/usr/bin/env python3
"""WidgetDeck timetable client for Untis Mobile access (standard library only).

  untis.py fetch              print the timetable (this and next week) as ONE json line; never fails, never prints secrets
  untis.py demo               the same with invented demo data (for tests / screenshots)
  untis.py verify [--stdin]   log in only; prints ok | auth | net | nosecret   (--stdin: the secret json comes from stdin)
  untis.py doctor             plain yes/no lines for widgetdeck-doctor (no host name, no key, no user name)

What is read: the school's time grid and the OWN timetable (getUserData2017 for the person id and the grid, getTimetable for the
lessons). Nothing else is requested - no marks, absences, homework or messages - and only whitelisted fields leave this script:
date, time, slot, subject / room / teacher short names, class, group, state, a short sanitised note.
The key (QR code secret) lives only in the Secret Service (secret-tool); it is never printed, logged or put in a request: the server
gets a one-time code (TOTP) computed from it. HTTPS with certificate verification only.
"""
import base64, datetime, hashlib, hmac, json, os, re, ssl, struct, subprocess, sys, time
import urllib.error, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "widgetdeck")
CACHE = os.path.join(CACHE_DIR, "timetable.json")
TEST_FILE = os.environ.get("WIDGETDECK_UNTIS_FILE")        # test hook: read the secret ONLY from this chmod-600 file (never the keyring)
PRIVATE_FILE = TEST_FILE or os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "widgetdeck-private", "untis.json")
CAFILE = os.environ.get("WIDGETDECK_UNTIS_CAFILE")          # test hook: one extra CA (the local test server); verification stays ON
TIMEOUT = 20
HOST_RE = re.compile(r"^[A-Za-z0-9]([A-Za-z0-9.-]{0,251}[A-Za-z0-9])?(:[0-9]{1,5})?$")
ELEM = {"CLASS": 1, "TEACHER": 2, "SUBJECT": 3, "ROOM": 4, "STUDENT": 5}


class AuthError(Exception): pass
class NetError(Exception): pass
class ServerError(Exception): pass
class NoData(ServerError): pass                              # -7004 "no allowed date": that week is not published (yet)


# ---------------------------------------------------------------------------------------------- secret
def get_secret():
    """-> dict(server, school, user, key) | None. The Secret Service first; the chmod-600 file only if the user chose it."""
    if not TEST_FILE:
        try:
            r = subprocess.run(["secret-tool", "lookup", "application", "widgetdeck", "kind", "untis"],
                               capture_output=True, timeout=30)
            if r.returncode == 0 and r.stdout.strip():
                return parse_secret(r.stdout.decode("utf-8", "replace"))
        except (OSError, subprocess.SubprocessError):
            pass
    try:
        st = os.stat(PRIVATE_FILE)
        if st.st_mode & 0o077 == 0:                           # only a private file (chmod 600) is accepted
            with open(PRIVATE_FILE, encoding="utf-8") as f:
                return parse_secret(f.read())
    except OSError:
        pass
    return None


def parse_secret(text):
    try:
        o = json.loads(text)
        s = {k: str(o[k]) for k in ("server", "school", "user", "key")}
    except (ValueError, KeyError, TypeError):
        return None
    if not HOST_RE.match(s["server"]) or not s["school"] or not s["user"] or not s["key"]:
        return None
    return s


def totp(key, now):
    k = re.sub(r"[\s=-]", "", key).upper()
    k += "=" * (-len(k) % 8)
    raw = base64.b32decode(k)
    digest = hmac.new(raw, struct.pack(">Q", int(now) // 30), hashlib.sha1).digest()
    o = digest[-1] & 0x0F
    return "%06d" % ((struct.unpack(">I", digest[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)


# ---------------------------------------------------------------------------------------------- http
class Session:
    def __init__(self, secret):
        self.s = secret
        ctx = ssl.create_default_context(cafile=CAFILE) if CAFILE else ssl.create_default_context()
        self.sid = ""                                          # session id from the login answer (cookies are handled by hand: robust for any host name)
        self.op = urllib.request.build_opener(urllib.request.HTTPSHandler(context=ctx))
        self.base = "https://" + secret["server"] + "/WebUntis/"

    def rpc(self, path, query, method, params):
        url = self.base + path + "?" + urllib.parse.urlencode(query)
        body = json.dumps({"id": "wd", "method": method, "jsonrpc": "2.0", "params": params}).encode()
        headers = {"Content-Type": "application/json", "Accept": "application/json"}
        if self.sid:
            headers["Cookie"] = "JSESSIONID=%s; schoolname=_%s" % (self.sid, base64.b64encode(self.s["school"].encode()).decode())
        req = urllib.request.Request(url, data=body, headers=headers)
        try:
            with self.op.open(req, timeout=TIMEOUT) as r:
                for c in r.headers.get_all("Set-Cookie") or []:
                    m = re.match(r"\s*JSESSIONID=([^;]+)", c)
                    if m:
                        self.sid = m.group(1)
                data = json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                raise AuthError()
            raise ServerError()
        except (urllib.error.URLError, OSError, ssl.SSLError):
            raise NetError()
        except ValueError:
            raise ServerError()
        err = data.get("error") if isinstance(data, dict) else None
        if err:
            code = err.get("code") if isinstance(err, dict) else None
            if code in (-8504, -8520, -8509, -8998):            # bad credentials / not authenticated / no right
                raise AuthError()
            if code == -7004:
                raise NoData()
            raise ServerError()
        return data.get("result") if isinstance(data, dict) else None

    def login(self):
        """getUserData2017 with a one-time code; -> (person type, person id, time grid or None)."""
        now = time.time()
        auth = {"clientTime": int(now * 1000), "user": self.s["user"], "otp": int(totp(self.s["key"], now))}
        res = self.rpc("jsonrpc_intern.do", {"m": "getUserData2017", "school": self.s["school"], "v": "i2.2"}, "getUserData2017", [{"auth": auth}])
        if not isinstance(res, dict):
            raise AuthError()
        ud = res.get("userData") or {}
        et = ud.get("elemType")
        etype = ELEM.get(et, et) if not isinstance(et, int) else et
        eid = ud.get("elemId")
        if not isinstance(etype, int) or not isinstance(eid, int):
            raise AuthError()
        grid = ((res.get("masterData") or {}).get("timeGrid") or {}).get("days")
        return etype, eid, grid

    def timegrid(self):
        res = self.rpc("jsonrpc.do", {"school": self.s["school"]}, "getTimegridUnits", {})
        return res

    def timetable(self, etype, eid, d0, d1):
        opts = {"options": {"element": {"id": eid, "type": etype, "keyType": "id"},
                            "startDate": d0.strftime("%Y%m%d"), "endDate": d1.strftime("%Y%m%d"),
                            "showBooking": False, "showInfo": True, "showSubstText": True, "showLsText": True,
                            "showLsNumber": False, "showStudentgroup": True,
                            "klasseFields": ["name"], "roomFields": ["name"], "subjectFields": ["name"], "teacherFields": ["name"]}}
        res = self.rpc("jsonrpc.do", {"school": self.s["school"]}, "getTimetable", opts)
        return res if isinstance(res, list) else []


# ---------------------------------------------------------------------------------------------- normalising
DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]


def hhmm(v):
    """800 | "0800" | "08:00" | "T08:00" | "08:00:00" -> "08:00" (servers differ)"""
    if isinstance(v, str):
        m = re.search(r"(\d{1,2}):(\d{2})", v)
        if m:
            return "%02d:%02d" % (int(m.group(1)), int(m.group(2)))
        v = v.strip().lstrip("T")
    try:
        v = int(v)
        return "%02d:%02d" % (v // 100, v % 100)
    except (TypeError, ValueError):
        return ""


def norm_grid(days, units=None):
    out = {}
    if isinstance(days, list):
        for d in days:
            name = str(d.get("day", ""))[:3].upper()
            # some schools send empty labels: then the units are simply numbered
            out[name] = [{"label": str(u.get("label") or (i + 1)), "start": hhmm(u.get("startTime")), "end": hhmm(u.get("endTime"))} for i, u in enumerate(d.get("units", []))]
    elif isinstance(units, list):                              # getTimegridUnits: day 1 = Sunday ... 7 = Saturday
        for d in units:
            try:
                name = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][int(d.get("day")) - 1]
            except (TypeError, ValueError, IndexError):
                continue
            out[name] = [{"label": str(u.get("name", "")), "start": hhmm(u.get("startTime")), "end": hhmm(u.get("endTime"))} for u in d.get("timeUnits", [])]
    return out


EMAIL = re.compile(r"\S+@\S+")
LONGNUM = re.compile(r"\d{6,}")


def clean(text, limit=80):
    t = " ".join(str(text or "").split())
    t = EMAIL.sub("", t)
    t = LONGNUM.sub("", t)
    return " ".join(t.split())[:limit]


def names(items):
    return [str(i.get("name", "")).strip() for i in (items or []) if isinstance(i, dict) and i.get("name")]


def changed_part(items):
    return any(isinstance(i, dict) and i.get("orgid") for i in (items or []))


def norm_lesson(l, grid):
    try:
        d = str(int(l["date"]))
        date = "%s-%s-%s" % (d[0:4], d[4:6], d[6:8])
    except (KeyError, TypeError, ValueError):
        return None
    start, end = hhmm(l.get("startTime")), hhmm(l.get("endTime"))
    code, lstype = l.get("code"), l.get("lstype")
    if code == "cancelled":
        state = "cancelled"
    elif lstype == "ex":
        state = "exam"
    elif code == "irregular" or changed_part(l.get("te")) or changed_part(l.get("ro")) or changed_part(l.get("su")):
        state = "changed"
    else:
        state = "normal"
    slot = ""
    try:
        wd = DAYS[datetime.date.fromisoformat(date).weekday()]
        for u in grid.get(wd, []):
            if u["start"] == start:
                slot = u["label"]
                break
    except ValueError:
        pass
    note = clean(" ".join(str(l.get(k) or "") for k in ("substText", "lstext", "info")))
    return {"date": date, "start": start, "end": end, "slot": slot,
            "subject": "/".join(names(l.get("su"))), "room": "/".join(names(l.get("ro"))), "teacher": "/".join(names(l.get("te"))),
            "klass": "/".join(names(l.get("kl"))), "group": clean(l.get("sg"), 24), "state": state, "note": note,
            "subst": {"teacher": changed_part(l.get("te")), "room": changed_part(l.get("ro")), "subject": changed_part(l.get("su"))}}


# ---------------------------------------------------------------------------------------------- cache + output
def week_range(today):
    mon = today - datetime.timedelta(days=today.weekday())
    return mon, mon + datetime.timedelta(days=13)


def out(state, data=None, source="untis"):
    o = {"state": state, "source": source, "fetched": 0, "grid": {}, "lessons": []}
    if data:
        o["fetched"] = data.get("fetched", 0)
        o["grid"] = data.get("grid", {})
        o["lessons"] = data.get("lessons", [])
    sys.stdout.write(json.dumps(o, ensure_ascii=False) + "\n")


def read_cache():
    try:
        with open(CACHE, encoding="utf-8") as f:
            d = json.load(f)
        return d if isinstance(d, dict) and "lessons" in d else None
    except (OSError, ValueError):
        return None


def write_cache(data):
    try:
        os.makedirs(CACHE_DIR, mode=0o700, exist_ok=True)
        tmp = CACHE + ".tmp"
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False)
        os.replace(tmp, CACHE)
    except OSError:
        pass


def cmd_fetch():
    secret = get_secret()
    if secret is None:
        return out("unconfigured")
    cached = read_cache()
    try:
        s = Session(secret)
        etype, eid, gdays = s.login()
        grid = norm_grid(gdays)
        if not grid:
            try:
                grid = norm_grid(None, s.timegrid())
            except (AuthError, ServerError):
                grid = {}
        d0, d1 = week_range(datetime.date.today())
        lessons = []
        for i, ws in enumerate((d0, d0 + datetime.timedelta(days=7))):         # this week and the next one
            try:
                got = s.timetable(etype, eid, ws, ws + datetime.timedelta(days=6))
            except NoData:
                continue                                          # not published yet (e.g. next week): nothing to show, not an error
            except ServerError:
                if i == 0:
                    raise                                         # the current week is required
                continue
            for l in got:
                n = norm_lesson(l, grid) if isinstance(l, dict) else None
                if n:
                    lessons.append(n)
        lessons.sort(key=lambda x: (x["date"], x["start"], x["subject"]))
        data = {"fetched": int(time.time()), "grid": grid, "lessons": lessons}
        write_cache(data)
        return out("ok", data)
    except AuthError:
        return out("expired", cached)
    except NetError:
        return out("stale" if cached else "offline", cached)
    except (ServerError, ValueError, KeyError, TypeError):
        return out("stale" if cached else "error", cached)


def cmd_demo(variant=""):
    name = "demo-%s.json" % re.sub(r"[^a-z]", "", variant) if variant else "demo.json"
    with open(os.path.join(HERE, name), encoding="utf-8") as f:
        t = json.load(f)
    today = datetime.date.today()
    mon = today - datetime.timedelta(days=today.weekday())
    lessons = []
    for wk in (0, 1):
        for l in t["lessons"]:
            if wk == 1 and l.get("week0only"):
                continue
            day = mon + datetime.timedelta(days=wk * 7 + l["day"])
            n = {k: v for k, v in l.items() if k not in ("day", "week0only")}
            n["date"] = day.isoformat()
            lessons.append(n)
    lessons.sort(key=lambda x: (x["date"], x["start"], x["subject"]))
    out("ok", {"fetched": int(time.time()), "grid": t["grid"], "lessons": lessons}, "demo")


def cmd_verify(from_stdin):
    secret = parse_secret(sys.stdin.read()) if from_stdin else get_secret()
    if secret is None:
        print("nosecret")
        return
    try:
        Session(secret).login()
        print("ok")
    except AuthError:
        print("auth")
    except (NetError, ServerError, ValueError):
        print("net")


def cmd_doctor():
    have_tool = subprocess.run(["sh", "-c", "command -v secret-tool >/dev/null 2>&1"]).returncode == 0
    print("secret-tool: " + ("yes" if have_tool else "no"))
    service = "no"
    if have_tool:
        try:
            r = subprocess.run(["secret-tool", "search", "--all", "application", "widgetdeck", "kind", "untis"], capture_output=True, timeout=30)
            service = "yes" if r.returncode in (0, 1) and not r.stderr.strip() else "no"
        except (OSError, subprocess.SubprocessError):
            service = "no"
    print("secret-service: " + service)
    secret = get_secret()
    print("key: " + ("yes" if secret else "no"))
    if secret:
        try:
            Session(secret).op.open(urllib.request.Request("https://" + secret["server"] + "/WebUntis/", method="HEAD"), timeout=10).close()
            print("server: reachable")
        except urllib.error.HTTPError:
            print("server: reachable")
        except (urllib.error.URLError, OSError, ssl.SSLError):
            print("server: not reachable")
    c = read_cache()
    print("last fetch: " + ("%d min ago" % ((time.time() - c.get("fetched", 0)) // 60) if c and c.get("fetched") else "never"))


if __name__ == "__main__":
    a = sys.argv[1:] or ["fetch"]
    try:
        if a[0] == "fetch": cmd_fetch()
        elif a[0] == "demo": cmd_demo(a[1] if len(a) > 1 else "")
        elif a[0] == "verify": cmd_verify("--stdin" in a)
        elif a[0] == "doctor": cmd_doctor()
        else: print("usage: untis.py fetch|demo|verify|doctor", file=sys.stderr)
    except Exception:                                           # never a traceback: it could contain request data
        if a[0] in ("fetch", "demo"):
            out("error")
        else:
            print("error")
