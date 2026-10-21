#!/usr/bin/env python3
"""Mock of the two F1 data sources for tests (INVENTED data, plain http on 127.0.0.1; the helper accepts that only with WIDGETDECK_F1_TEST=1).
    f1-mock.py <port>      Jolpica paths under /jolpica/..., OpenF1 under /openf1/..., control: /_ctl?k=v (mode, race_shift_days, ...), log: /_log
Other control keys: t0=<epoch> (start of the fake calendar), country=<name>, result_round, live, retry_after.
Modes (k=mode): ok | r429 | err500 | nofields | cancel | moved | removed | late | long (very long names) | nooutline (a circuit nobody has an outline for) | notime (the next race has no times)   (late: the last-results endpoint still answers with the previous round)
"""
import json
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = {"mode": "ok", "log": [], "t0": None, "result_round": 1, "live": "off", "retry_after": 600}


def iso(ts):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(ts))


def calendar():
    t0 = STATE["t0"]
    races = []
    for i in range(1, 6):
        start = t0 + (i * 7 - 4) * 86400 + 20 * 3600
        d = {"season": "2026", "round": str(i), "raceName": "Test Grand Prix %d" % i,
             "Circuit": {"circuitId": "monza" if i % 2 else "spa", "circuitName": "Test Circuit %d" % i, "Location": {"locality": "Testville", "country": STATE.get("country", "Testland")}},
             "date": iso(start)[:10], "time": iso(start)[11:]}
        for k, off in (("FirstPractice", -48 * 3600), ("SecondPractice", -44 * 3600), ("ThirdPractice", -24 * 3600), ("Qualifying", -20 * 3600)):
            s = start + off
            d[k] = {"date": iso(s)[:10], "time": iso(s)[11:]}
        races.append(d)
    m = STATE["mode"]
    if m == "notime":
        del races[0]["time"]
        del races[0]["Qualifying"]["time"]
        del races[0]["FirstPractice"]
    if m == "nooutline":
        races[0]["Circuit"]["circuitId"] = "nowhere_ring"
    if m == "long":
        races[0]["raceName"] = "Gran Premio Internazionale di Formula Uno del Mediterraneo Occidentale e delle Isole"
        races[0]["Circuit"]["circuitName"] = "Autodromo Internazionale Super Lungo Intitolato a un Pilota Molto Famoso"
        races[0]["Circuit"]["Location"] = {"locality": "San Giovanni in Persiceto Superiore", "country": "United Arab Emirates and Others"}
    if m == "nofields":
        del races[1]["time"]
        del races[1]["Qualifying"]["time"]
        del races[1]["FirstPractice"]
    if m == "moved":
        s = t0 + 20 * 86400
        races[2]["date"] = iso(s)[:10]
    if m == "removed":
        del races[2]
    return {"MRData": {"series": "f1", "RaceTable": {"season": "2026", "Races": races}}}


def results():
    r = STATE["result_round"]
    if STATE["mode"] == "long":
        return {"MRData": {"RaceTable": {"season": "2026", "Races": [{"round": str(r), "raceName": "Gran Premio Internazionale di Formula Uno del Mediterraneo", "date": "2026-01-01", "Results": [
            {"position": str(i + 1), "Driver": {"code": "L%d" % i, "givenName": "Maximilian-Alexander", "familyName": "Schmidt-Hohenzollern-Sigmaringen"}, "Constructor": {"name": "Scuderia Internazionale Racing Team Deutschland"}} for i in range(3)]}]}}}
    return {"MRData": {"RaceTable": {"season": "2026", "Races": [{"round": str(r), "raceName": "Test Grand Prix %d" % r, "date": "2026-01-01", "Results": [
        {"position": str(i + 1), "Driver": {"code": c, "givenName": "G%d" % i, "familyName": "F%d" % i}, "Constructor": {"name": "Team %d" % i}} for i, c in enumerate(["AAA", "BBB", "CCC"])]}]}}}


def standings():
    if STATE["mode"] == "long":
        return {"MRData": {"StandingsTable": {"season": "2026", "StandingsLists": [{"round": "1", "DriverStandings": [
            {"position": str(i + 1), "points": str(1000 - i), "Driver": {"code": "L%d" % i, "givenName": "Maximilian-Alexander", "familyName": "Schmidt-Hohenzollern-Sigmaringen"}, "Constructors": [{"name": "Scuderia Internazionale Racing Team Deutschland"}]} for i in range(12)]}]}}}
    return {"MRData": {"StandingsTable": {"season": "2026", "StandingsLists": [{"round": str(STATE["result_round"]), "DriverStandings": [
        {"position": str(i + 1), "points": str(100 - i), "Driver": {"code": "D%d" % i, "givenName": "G%d" % i, "familyName": "F%d" % i}, "Constructors": [{"name": "Team %d" % i}]} for i in range(12)]}]}}}


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, code, obj, headers=None):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        p = u.path
        if p == "/_ctl":
            for k, v in q.items():
                STATE[k] = v[0] if not v[0].isdigit() else int(v[0])
            return self.send(200, {"ok": True})
        if p == "/_log":
            return self.send(200, STATE["log"])
        if p == "/_reset":
            STATE["log"] = []
            return self.send(200, {"ok": True})
        STATE["log"].append(p)
        m = STATE["mode"]
        if m == "r429":
            return self.send(429, {"error": "slow down"}, {"Retry-After": str(STATE["retry_after"])})
        if m == "err500":
            return self.send(500, {"error": "boom"})
        if p == "/jolpica/current.json":
            return self.send(200, calendar())
        if p == "/jolpica/current/last/results.json":
            return self.send(200, results())
        if p == "/jolpica/current/driverStandings.json":
            return self.send(200, standings())
        if p == "/openf1/sessions" and "year" in q:
            sess = []
            if m == "cancel":
                cal = calendar()["MRData"]["RaceTable"]["Races"]
                sess.append({"session_name": "Race", "is_cancelled": True, "date_start": cal[1]["date"] + "T" + cal[1]["time"]})
            return self.send(200, sess)
        if p == "/openf1/sessions":
            if STATE["live"] == "auth":
                return self.send(401, {"detail": "Live data needs authentication"})
            if STATE["live"] == "on":
                return self.send(200, [{"session_key": 1, "session_name": "Qualifying"}])
            return self.send(200, [])
        if p == "/openf1/drivers":
            return self.send(200, [{"driver_number": 1, "name_acronym": "AAA", "team_name": "Team 1", "full_name": "A A"}, {"driver_number": 2, "name_acronym": "BBB", "team_name": "Team 2", "full_name": "B B"}, {"driver_number": 3, "name_acronym": "CCC", "team_name": "Team 3", "full_name": "C C"}])
        if p == "/openf1/position":
            return self.send(200, [{"date": "2026-01-01T10:00:00", "driver_number": 2, "position": 1}, {"date": "2026-01-01T10:00:00", "driver_number": 1, "position": 2}, {"date": "2026-01-01T10:00:01", "driver_number": 3, "position": 3}, {"date": "2026-01-01T09:59:00", "driver_number": 3, "position": 1}])
        if p == "/openf1/race_control":
            return self.send(200, [{"date": "2026-01-01T10:00:00", "category": "Flag", "flag": "YELLOW"}, {"date": "2026-01-01T10:00:30", "category": "Flag", "flag": "GREEN"}])
        return self.send(404, {"error": "no such path"})


if __name__ == "__main__":
    STATE["t0"] = time.time()
    ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
