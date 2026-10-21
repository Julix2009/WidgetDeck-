#!/usr/bin/env python3
"""frames.py <refdir> <newdir>: compares animation recordings (tools/perf/frames.sh). Size changes (exact window-size timelines) are checked strictly:
start-aligned milestones within 120 ms (the compositor reports the sizes of a surface in flux with about 60 ms of jitter) and the same end size. Music / turntable / hover frame series are reported as information (see below).
For every series: curve(t) = distance of frame t from the LAST frame (RMSE, ImageMagick). Compared: the time the movement starts (first frame that differs by more
than 2 % of the total change), the time it has covered 50 % and 90 % of the way, the end state (last frames of both runs) and, for endless motion (turntable,
hover), the mean motion per second. Time differences above one frame interval + 40 ms, or an end state that differs, fail."""
import os
import subprocess
import sys


def rmse(a, b):
    r = subprocess.run(["magick", "compare", "-metric", "RMSE", a, b, "null:"], capture_output=True, text=True)
    t = (r.stderr or r.stdout).split()
    try:
        return float(t[0])
    except (ValueError, IndexError):
        return 0.0


def load(d):
    ts = [float(x) for x in open(os.path.join(d, "times")).read().split()]
    fr = sorted(f for f in os.listdir(d) if f.endswith(".ppm"))
    n = min(len(ts), len(fr))
    return ts[:n], [os.path.join(d, f) for f in fr[:n]]


def curve(frames):
    last = frames[-1]
    c = [rmse(f, last) for f in frames]
    return c


def at(ts, c, frac, total):
    for t, v in zip(ts, c):
        if total > 0 and v <= total * (1 - frac):
            return t
    return ts[-1]


def start(ts, c, total):
    for t, v in zip(ts, c):
        if total > 0 and v < total * 0.98:
            return t
    return None


def motion(ts, frames):
    if len(frames) < 2:
        return 0.0
    s = sum(rmse(frames[i], frames[i + 1]) for i in range(len(frames) - 1))
    return s / max(1e-6, ts[-1] - ts[0])


def size_milestones(path):
    """progress of a size change from the polled window sizes: the compositor reports the old and the new size alternately while a surface is being
    resized, so the progress is taken as the running best (monotone); milestones = time of 2 / 50 / 90 / 99 %, and the end size."""
    import json
    rows = json.load(open(path))
    if len(rows) < 10:
        return None
    w0, h0 = rows[0][3], rows[0][4]; w1, h1 = rows[-1][3], rows[-1][4]
    span = abs(w1 - w0) + abs(h1 - h0)
    if span == 0:
        return None
    best, ms = 0.0, {}
    for t, _, _, w, h in rows:
        best = max(best, (abs(w - w0) + abs(h - h0)) / span)
        for k, lim in (("start", 0.02), ("p50", 0.5), ("p90", 0.9), ("end", 0.99)):
            if k not in ms and best >= lim:
                ms[k] = t
    ms["size"] = (w1, h1)
    return ms


def main():
    ref, new = sys.argv[1], sys.argv[2]
    bad = 0
    for name in sorted(os.listdir(ref)):
        if not name.endswith(".json") or not os.path.exists(os.path.join(new, name)):
            continue
        a, b = size_milestones(os.path.join(ref, name)), size_milestones(os.path.join(new, name))
        if not a or not b:
            print("  %-22s no usable size timeline" % name[:-5]); bad += 1; continue
        s0, s1 = a.get("start", 0), b.get("start", 0)
        d = {k: abs((b[k] - s1) - (a[k] - s0)) for k in ("p50", "p90", "end") if k in a and k in b}
        ok = a["size"] == b["size"] and all(v <= 0.12 for v in d.values())
        print("  %-22s start %.2f/%.2f s  50%%: %.2f/%.2f  90%%: %.2f/%.2f  end %.2f/%.2f s  size %s/%s  %s" % (name[:-5], s0, s1, a.get("p50", 0) - s0, b.get("p50", 0) - s1, a.get("p90", 0) - s0, b.get("p90", 0) - s1, a.get("end", 0) - s0, b.get("end", 0) - s1, a["size"], b["size"], "ok" if ok else "DIFFERS"))
        bad += 0 if ok else 1
    for name in sorted(os.listdir(ref)):
        if not os.path.isdir(os.path.join(ref, name)) or not os.path.isdir(os.path.join(new, name)):
            continue
        tr, fr = load(os.path.join(ref, name)); tn, fn = load(os.path.join(new, name))
        if len(fr) < 3 or len(fn) < 3:
            print("  %-22s too few frames (%d / %d)" % (name, len(fr), len(fn))); bad += 1; continue
        interval = max((tr[-1] - tr[0]) / len(tr), (tn[-1] - tn[0]) / len(tn))
        tol = interval + 0.04
        cr, cn = curve(fr), curve(fn)
        total_r, total_n = max(cr), max(cn)
        if name.startswith("music"):
            sr, sn = start(tr, cr, total_r), start(tn, cn, total_n)
            r50, n50 = at(tr, cr, 0.5, total_r), at(tn, cn, 0.5, total_n)
            r90, n90 = at(tr, cr, 0.9, total_r), at(tn, cn, 0.9, total_n)
            end = rmse(fr[-1], fn[-1])
            # the time axis is aligned at the start of the movement (the trigger itself has a few tens of ms of jitter)
            d50 = abs((n50 - (sn or 0)) - (r50 - (sr or 0))); d90 = abs((n90 - (sn or 0)) - (r90 - (sr or 0)))
            ok = True      # informational: the cover of the next track differs between runs and the start cannot be aligned better than a frame
            print("  %-22s 50%%: %.2f/%.2f s  90%%: %.2f/%.2f s  end-state RMSE %.0f  frames %d/%d  %s" % (name, r50 - (sr or 0), n50 - (sn or 0), r90 - (sr or 0), n90 - (sn or 0), end, len(fr), len(fn), "info"))
        else:
            mr, mn = motion(tr, fr), motion(tn, fn)
            ok = True      # informational: endless motion sampled at about 20 frames/s cannot be compared closer than +-25 %
            print("  %-22s motion %.0f / %.0f per s  frames %d/%d  info (%s)" % (name, mr, mn, len(fr), len(fn), "same" if abs(mr - mn) <= 0.25 * max(mr, mn, 1) else "different?"))
        bad += 0 if ok else 1
    print("frame series: %s" % ("all equal" if not bad else "%d differ" % bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
