#!/usr/bin/env python3
"""Local test server that speaks the small part of the Untis Mobile JSON-RPC interface the widget uses. INVENTED data only.
  tools/untis-mock.py <port> <cert.pem> <key.pem> [mode]      mode: ok (default) | revoked | broken | slow | quirks
The test secret is TESTKEY (base32); the mock checks the one-time code like a real server would.
"""
import base64, datetime, hashlib, hmac, json, ssl, struct, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer

KEY = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"            # RFC 6238 test secret - not a real credential
MODE = sys.argv[4] if len(sys.argv) > 4 else "ok"
USER = "test.user"


def totp(now):
    raw = base64.b32decode(KEY)
    d = hmac.new(raw, struct.pack(">Q", int(now) // 30), hashlib.sha1).digest()
    o = d[-1] & 15
    return "%06d" % ((struct.unpack(">I", d[o:o + 4])[0] & 0x7FFFFFFF) % 1000000)


def lessons_for(d0):
    out = []
    mon = datetime.datetime.strptime(d0, "%Y%m%d").date()
    for i, (su, ro, te, st, en) in enumerate([("M", "A1", "KOL", 800, 850), ("D", "A1", "WEI", 855, 945), ("E", "B2", "SEI", 1000, 1050)]):
        day = mon + datetime.timedelta(days=i % 5)
        l = {"id": i + 1, "date": int(day.strftime("%Y%m%d")), "startTime": st, "endTime": en, "kl": [{"id": 1, "name": "3B"}],
             "te": [{"id": 1, "name": te}], "su": [{"id": 1, "name": su}], "ro": [{"id": 1, "name": ro}]}
        if i == 1:
            l["code"] = "cancelled"
        if i == 2:
            l["te"] = [{"id": 2, "name": "XYZ", "orgid": 1}]; l["substText"] = "Mail an max@example.org, Nr 123456789"
        out.append(l)
    return out


class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass

    def reply(self, obj, code=200, cookie=False):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json")
        if cookie: self.send_header("Set-Cookie", "JSESSIONID=TESTSESSION; Path=/WebUntis; Secure")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)

    def do_HEAD(self): self.send_response(200); self.end_headers()

    def do_POST(self):
        if MODE == "slow": time.sleep(40)
        if MODE == "broken": return self.reply({"x": 1}, 500)
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        m = body.get("method"); p = body.get("params") or [{}]
        if isinstance(p, dict): p = [p]
        if m == "getUserData2017":
            a = p[0].get("auth", {})
            ok = MODE != "revoked" and a.get("user") == USER and "%06d" % int(a.get("otp", -1)) in {totp(time.time() + k * 30) for k in (-1, 0, 1)}
            if not ok: return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "error": {"code": -8504, "message": "bad credentials"}})
            if MODE == "quirks":        # what real schools send: ISO times, empty labels
                days = [{"day": d, "units": [{"label": "", "startTime": "T08:00", "endTime": "T08:50"}, {"label": "", "startTime": "T08:55", "endTime": "T09:45"}, {"label": "", "startTime": "T10:00", "endTime": "T10:50"}]} for d in ("MON", "TUE", "WED", "THU", "FRI")]
            else:
                days = [{"day": d, "units": [{"label": "1", "startTime": 800, "endTime": 850}, {"label": "2", "startTime": 855, "endTime": 945}, {"label": "3", "startTime": 1000, "endTime": 1050}]} for d in ("MON", "TUE", "WED", "THU", "FRI")]
            return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "result": {"userData": {"elemType": "STUDENT", "elemId": 42, "displayName": "Test Student", "schoolName": "Testschule"},
                                                                                "masterData": {"timeGrid": {"days": days}}}}, cookie=True)
        if "JSESSIONID=TESTSESSION" not in (self.headers.get("Cookie") or ""):
            return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "error": {"code": -8520, "message": "not authenticated"}})
        if m == "getTimetable":
            o = p[0]["options"]
            if MODE == "quirks" and str(o["startDate"]) > (datetime.date.today() + datetime.timedelta(days=1)).strftime("%Y%m%d") and datetime.datetime.strptime(str(o["startDate"]), "%Y%m%d").date() > datetime.date.today():
                return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "error": {"code": -7004, "message": "no allowed date"}})   # next week not published yet
            return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "result": lessons_for(str(o["startDate"]))})
        return self.reply({"jsonrpc": "2.0", "id": body.get("id"), "error": {"code": -32601, "message": "method not found"}})


srv = HTTPServer(("127.0.0.1", int(sys.argv[1])), H)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER); ctx.load_cert_chain(sys.argv[2], sys.argv[3])
srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
srv.serve_forever()
