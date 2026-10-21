#!/usr/bin/env python3
"""report.py <baseline-dir> [<other-baseline-dir>]: markdown table of one measuring run (tools/perf/baseline.sh), or of two runs side by side with the change."""
import json
import os
import sys


def load(d):
    out = {}
    for f in sorted(os.listdir(d)):
        if f.endswith(".json"):
            mode, _, rest = f[:-5].partition("-")
            out.setdefault(mode, {})[rest] = json.load(open(os.path.join(d, f)))
    return out


def cell(a, b, fmt="%.1f", lower_better=True):
    if a is None:
        return "-"
    if b is None:
        return fmt % a
    pct = (b - a) / a * 100 if a else 0
    return "%s -> %s (%+.0f%%)" % (fmt % a, fmt % b, pct)


def main():
    A = load(sys.argv[1]); B = load(sys.argv[2]) if len(sys.argv) > 2 else {}
    rows = [
        ("Start until all windows exist (s)", lambda m: (m.get("start") or {}).get("start_s"), "%.2f"),
        ("PSS total after start (MiB)", lambda m: m["idle0"]["pss_kib"] / 1024, "%.0f"),
        ("RSS total after start (MiB)", lambda m: m["idle0"]["rss_kib"] / 1024, "%.0f"),
        ("PSS total after 10 min (MiB)", lambda m: m["idle10"]["pss_kib"] / 1024, "%.0f"),
        ("GPU memory of the shell (MiB)", lambda m: m["idle10"]["gpu_mem_kib"] / 1024, "%.0f"),
        ("Processes (helpers included)", lambda m: len(m["idle10"]["procs"]), "%d"),
        ("Threads of the main process", lambda m: m["idle10"]["procs"][0]["threads"], "%d"),
        ("Idle CPU, first minute (% of one core)", lambda m: m["idle0"]["cpu_pct"], "%.2f"),
        ("Idle CPU after 10 min (%)", lambda m: m["idle10"]["cpu_pct"], "%.2f"),
        ("Idle wakeups / s after 10 min", lambda m: m["idle10"]["wakeups_per_s"], "%.0f"),
        ("Idle GPU render engine (%)", lambda m: m["idle10"]["gpu_render_pct"], "%.2f"),
        ("Processes started / min (idle)", lambda m: m["idle10"]["spawned_per_min"], "%.0f"),
        ("Hover: CPU % / GPU %", lambda m: (m["hover"]["cpu_pct"], m["hover"]["gpu_render_pct"]), None),
        ("Size animations: CPU % / GPU %", lambda m: (m["anim"]["cpu_pct"], m["anim"]["gpu_render_pct"]), None),
        ("Music (track change): CPU % / GPU %", lambda m: (m["music"]["cpu_pct"], m["music"]["gpu_render_pct"]), None),
        ("Network requests / hour", lambda m: (m.get("net") or {}).get("per_hour"), "%.0f"),
        ("Cache directory (KiB)", lambda m: (m.get("files") or {}).get("cache_kib"), "%d"),
        ("Log lines", lambda m: (m.get("files") or {}).get("log_lines"), "%d"),
    ]
    modes = [m for m in ("frosted", "liquid") if m in A]
    print("| Metric | " + " | ".join(modes) + " |"); print("|---|" + "---|" * len(modes))
    for name, fn, fmt in rows:
        vals = []
        for m in modes:
            try:
                a = fn(A[m]); b = fn(B[m]) if m in B else None
            except (KeyError, IndexError, TypeError):
                vals.append("-"); continue
            if isinstance(a, tuple):
                vals.append(" / ".join("%.2f" % x for x in a) + ((" -> " + " / ".join("%.2f" % x for x in b)) if b else ""))
            else:
                vals.append(cell(a, b, fmt))
        print("| %s | %s |" % (name, " | ".join(vals)))
    for m in modes:
        print("\nTop consumers, %s (after 10 min, PSS):" % m)
        for p in sorted(A[m]["idle10"]["procs"], key=lambda x: -x["pss_kib"])[:6]:
            print("  %7.1f MiB  thr %-3d %s" % (p["pss_kib"] / 1024, p["threads"], p["cmd"][:90]))
        print("  started while idle:", "; ".join((A[m]["idle10"].get("spawned_cmds") or [])[:14]))


if __name__ == "__main__":
    main()
