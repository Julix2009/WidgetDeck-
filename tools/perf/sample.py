#!/usr/bin/env python3
"""Resource sampler for a process tree (Python standard library only; reads /proc, no root needed).

    sample.py --match 'quickshell -p /path' [--seconds 60] [--label idle] [--json out.json]
    sample.py --pid 1234 --snapshot                 one memory snapshot (no waiting)

What it measures for the root process and ALL its descendants (scripts, python, curl ... that are running at the time):
  memory     RSS and PSS (smaps_rollup), per process and in total; GPU memory of the DRM clients (drm-total-system0, once per client id)
  CPU        user + system seconds used during the window (live processes plus the children that were waited for), as % of one core
  wakeups    context switches per second over all threads (voluntary = the thread went to sleep and was woken, involuntary = pre-empted)
  GPU        render-engine time of the DRM clients (fdinfo drm-engine-render) as % of the window
  spawns     processes started below the root during the window (a 10 ms sampling of the children lists: a lower bound, very short lived
             processes can be missed; strace -c -f gives exact numbers when it is installed)
  open files number of open file descriptors, threads
"""
import argparse
import json
import os
import sys
import time

CLK = os.sysconf("SC_CLK_TCK")


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", "replace")
    except OSError:
        return ""


def cmdline(pid):
    c = read("/proc/%d/cmdline" % pid).replace("\0", " ").strip()
    return c or read("/proc/%d/comm" % pid).strip()


def children_of(pid):
    out = []
    try:
        for t in os.listdir("/proc/%d/task" % pid):
            out += [int(x) for x in read("/proc/%d/task/%s/children" % (pid, t)).split()]
    except OSError:
        pass
    return out


def tree(root):
    seen, todo = [], [root]
    while todo:
        p = todo.pop()
        if p in seen or not os.path.exists("/proc/%d" % p):
            continue
        seen.append(p)
        todo += children_of(p)
    return seen


def find_root(match):
    me = os.getpid()
    best = None
    for d in os.listdir("/proc"):
        if d.isdigit() and int(d) != me:
            c = cmdline(int(d))
            if match in c and "sample.py" not in c and not c.startswith(("bash -c", "/usr/bin/bash -c")):
                best = int(d) if best is None else min(best, int(d))
    return best


def smaps(pid):
    d = {}
    for line in read("/proc/%d/smaps_rollup" % pid).splitlines():
        k, _, v = line.partition(":")
        if k in ("Rss", "Pss", "Pss_Anon", "Pss_File", "Pss_Shmem", "Private_Dirty"):
            try:
                d[k] = int(v.split()[0])
            except (ValueError, IndexError):
                pass
    return d


def stat(pid):
    s = read("/proc/%d/stat" % pid)
    if not s:
        return None
    f = s[s.rindex(")") + 2:].split()
    return {"utime": int(f[11]), "stime": int(f[12]), "cutime": int(f[13]), "cstime": int(f[14]), "threads": int(f[17])}


def ctxt(pid):
    v = n = 0
    try:
        for t in os.listdir("/proc/%d/task" % pid):
            for line in read("/proc/%d/task/%s/status" % (pid, t)).splitlines():
                if line.startswith("voluntary_ctxt_switches"):
                    v += int(line.split()[1])
                elif line.startswith("nonvoluntary_ctxt_switches"):
                    n += int(line.split()[1])
    except OSError:
        pass
    return v, n


def drm(pid):
    """{client-id: {render_ns, mem_kib, resident_kib}} over the DRM file descriptors of the process."""
    out = {}
    try:
        fds = os.listdir("/proc/%d/fdinfo" % pid)
    except OSError:
        return out
    for fd in fds:
        t = read("/proc/%d/fdinfo/%s" % (pid, fd))
        if "drm-driver" not in t:
            continue
        kv = {}
        for line in t.splitlines():
            k, _, v = line.partition(":")
            kv[k.strip()] = v.strip()
        cid = kv.get("drm-client-id", fd)
        def num(key):
            x = kv.get(key, "0").split()
            if not x:
                return 0
            n = int(x[0])
            unit = x[1] if len(x) > 1 else ""
            return n * 1024 if unit == "MiB" else n
        out[cid] = {"render_ns": int(kv.get("drm-engine-render", "0 ns").split()[0]), "mem_kib": num("drm-total-system0"), "resident_kib": num("drm-resident-system0")}
    return out


def thread_cpu(pid):
    """{tid: (comm, ticks)} for the threads of one process (which thread burns the CPU: GUI, render, QML worker, ...)."""
    out = {}
    try:
        for t in os.listdir("/proc/%d/task" % pid):
            st = read("/proc/%d/task/%s/stat" % (pid, t))
            if st:
                comm = st[st.index("(") + 1:st.rindex(")")]
                f = st[st.rindex(")") + 2:].split()
                out[t] = (comm, int(f[11]) + int(f[12]))
    except OSError:
        pass
    return out


def nfds(pid):
    try:
        return len(os.listdir("/proc/%d/fd" % pid))
    except OSError:
        return 0


def snapshot(root):
    procs = []
    gpu = {}
    for p in tree(root):
        st = stat(p)
        if not st:
            continue
        sm = smaps(p)
        procs.append({"pid": p, "cmd": cmdline(p)[:110], "rss_kib": sm.get("Rss", 0), "pss_kib": sm.get("Pss", 0), "pss_anon_kib": sm.get("Pss_Anon", 0), "threads": st["threads"], "fds": nfds(p)})
        gpu.update({("%d:%s" % (p, k)): v for k, v in drm(p).items()})
    return procs, gpu


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--match"); ap.add_argument("--pid", type=int)
    ap.add_argument("--seconds", type=float, default=60); ap.add_argument("--label", default="")
    ap.add_argument("--snapshot", action="store_true"); ap.add_argument("--json")
    a = ap.parse_args()
    root = a.pid or (find_root(a.match) if a.match else None)
    if not root:
        sys.exit("no such process")
    res = {"label": a.label, "root": root, "root_cmd": cmdline(root)[:100], "time": time.strftime("%Y-%m-%d %H:%M:%S")}
    procs, gpu = snapshot(root)
    res["procs"] = procs
    res["rss_kib"] = sum(p["rss_kib"] for p in procs); res["pss_kib"] = sum(p["pss_kib"] for p in procs)
    res["gpu_mem_kib"] = sum(v["mem_kib"] for v in gpu.values())
    if not a.snapshot:
        th0 = thread_cpu(root)
        pids0 = {p: (stat(p), ctxt(p)) for p in tree(root)}
        gpu0 = {k: v["render_ns"] for k, v in gpu.items()}
        t0 = time.time(); spawned = {}; known = set(pids0)
        last_children = root
        while time.time() - t0 < a.seconds:
            for p in tree(root):
                if p not in known:
                    known.add(p); spawned[p] = cmdline(p)[:60]
            time.sleep(0.01)
        t1 = time.time(); dt = t1 - t0
        pids1 = {p: (stat(p), ctxt(p)) for p in tree(root)}
        cpu = 0.0; vol = invol = 0
        for p, (s1, c1) in pids1.items():
            s0, c0 = pids0.get(p, (None, (0, 0)))
            if s1:
                cpu += (s1["utime"] + s1["stime"]) - ((s0["utime"] + s0["stime"]) if s0 else 0)
                vol += c1[0] - c0[0]; invol += c1[1] - c0[1]
        # time of children that ended and were waited for by a live process of the tree
        for p, (s1, c1) in pids1.items():
            s0 = pids0.get(p, (None, None))[0]
            if s1:
                cpu += (s1["cutime"] + s1["cstime"]) - ((s0["cutime"] + s0["cstime"]) if s0 else 0)
        for p in list(pids0):                                    # processes that were there at the start and are gone now: not countable
            pass
        th1 = thread_cpu(root)
        thr = {}
        for t, (comm, ticks) in th1.items():
            d = ticks - th0.get(t, (comm, 0))[1]
            thr[comm] = thr.get(comm, 0) + d
        res["threads_cpu_pct"] = {k: round(v / CLK / dt * 100, 2) for k, v in sorted(thr.items(), key=lambda kv: -kv[1])[:8] if v > 0}
        _, gpu1 = snapshot(root)
        gns = sum(v["render_ns"] - gpu0.get(k, 0) for k, v in gpu1.items())
        res.update({"seconds": round(dt, 1), "cpu_pct": round(cpu / CLK / dt * 100, 3), "wakeups_per_s": round(vol / dt, 1), "preempt_per_s": round(invol / dt, 2),
                    "gpu_render_pct": round(gns / 1e9 / dt * 100, 3), "spawned": len(spawned), "spawned_per_min": round(len(spawned) / dt * 60, 1),
                    "spawned_cmds": sorted(set(v.split(" ")[0].split("/")[-1] + " " + " ".join(v.split(" ")[1:3]) for v in spawned.values()))[:30]})
        res["procs_end"] = len(pids1)
    if a.json:
        with open(a.json, "w") as f:
            json.dump(res, f, indent=1)
    show = {k: v for k, v in res.items() if k not in ("procs", "spawned_cmds")}
    print(json.dumps(show))
    for p in sorted(res["procs"], key=lambda x: -x["pss_kib"])[:8]:
        print("  %7.1f MiB PSS  %7.1f MiB RSS  thr %-3d fds %-3d %s" % (p["pss_kib"] / 1024, p["rss_kib"] / 1024, p["threads"], p["fds"], p["cmd"]))
    if res.get("threads_cpu_pct"):
        print("  CPU by thread (% of one core):", ", ".join("%s %.1f" % kv for kv in res["threads_cpu_pct"].items()))
    if res.get("spawned_cmds"):
        print("  started during the window:", "; ".join(res["spawned_cmds"][:12]))


if __name__ == "__main__":
    main()
