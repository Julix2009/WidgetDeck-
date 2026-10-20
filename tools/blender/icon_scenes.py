"""Scene descriptions of the weather card icons (Blender 4.x / 5.x, Python API).

Everything is modelled procedurally from soft metaball elements (spheres, capsules, ellipsoids that blend into each other like clay) -
no mesh files, no external assets. A scene = a set of LAYERS; every layer holds one or more "parts". All parts of all layers of an icon share
one coordinate system (x = right, z = up, y = away from the camera), so the layer renders line up exactly when they are stacked in the widget.

A part is described by a dict:  {"kind": "ball|capsule|ellipsoid", "co": (x, y, z), "r": radius, "size": (sx, sy, sz), "rot": degrees about y,
                                 "neg": False, "stiff": 2.0}
and a material by a dict (see MATERIALS). Sizes are the visible radius; the builder corrects for the metaball threshold.
Own work (MIT). Nothing is traced or copied from images.
"""
import math


def ball(x, z, r, y=0.0, neg=False, stiff=2.0):
    return {"kind": "ball", "co": (x, y, z), "r": r, "neg": neg, "stiff": stiff}


def capsule(x, z, half, r, rot=0.0, y=0.0, neg=False, stiff=2.0):
    """Rounded rod, `half` = half length of the straight part, rotated by `rot` degrees about the viewing axis."""
    return {"kind": "capsule", "co": (x, y, z), "r": r, "size": (half, 0.0, 0.0), "rot": rot, "neg": neg, "stiff": stiff}


def ellipsoid(x, z, rx, rz, ry=None, y=0.0, stiff=2.0):
    return {"kind": "ellipsoid", "co": (x, y, z), "r": max(rx, rz), "size": (rx, ry if ry else min(rx, rz), rz), "rot": 0.0, "neg": False, "stiff": stiff}


# ---------------------------------------------------------------- materials (Principled BSDF settings; names are resolved per Blender version)
MATERIALS = {
    "cloud":      {"base": (0.97, 0.98, 1.0), "rough": 0.42, "sss": 0.55, "sss_color": (0.62, 0.78, 1.0), "sss_radius": (1.0, 0.9, 1.3), "sheen": 0.35},
    "cloud_grey": {"base": (0.82, 0.86, 0.93), "rough": 0.44, "sss": 0.5, "sss_color": (0.55, 0.68, 0.92), "sss_radius": (1.0, 0.9, 1.3), "sheen": 0.3},
    "cloud_dark": {"base": (0.52, 0.57, 0.68), "rough": 0.46, "sss": 0.45, "sss_color": (0.40, 0.50, 0.80), "sss_radius": (1.0, 0.9, 1.3), "sheen": 0.2},
    "sun":        {"base": (1.0, 0.66, 0.14), "rough": 0.28, "sss": 0.3, "sss_color": (1.0, 0.45, 0.08), "emit": (1.0, 0.52, 0.10), "emit_strength": 0.9, "coat": 0.4},
    "moon":       {"base": (0.97, 0.93, 0.80), "rough": 0.42, "sss": 0.45, "sss_color": (0.72, 0.66, 0.95), "sss_radius": (1.0, 0.9, 1.3), "emit": (1.0, 0.92, 0.7), "emit_strength": 0.12},
    "star":       {"base": (1.0, 0.95, 0.7), "rough": 0.3, "emit": (1.0, 0.88, 0.45), "emit_strength": 3.5},
    "drop":       {"base": (0.35, 0.66, 1.0), "rough": 0.08, "sss": 0.6, "sss_color": (0.2, 0.5, 1.0), "coat": 0.8, "emit": (0.1, 0.3, 0.8), "emit_strength": 0.25},
    "bolt":       {"base": (1.0, 0.78, 0.12), "rough": 0.22, "emit": (1.0, 0.5, 0.05), "emit_strength": 0.7, "coat": 0.6},
    "flake":      {"base": (0.93, 0.98, 1.0), "rough": 0.2, "sss": 0.5, "sss_color": (0.55, 0.78, 1.0), "coat": 0.6},
    "hail":       {"base": (0.94, 0.98, 1.0), "rough": 0.12, "sss": 0.4, "sss_color": (0.6, 0.8, 1.0), "coat": 0.9},
    "fog":        {"base": (0.93, 0.95, 0.98), "rough": 0.6, "sss": 0.45, "sss_color": (0.7, 0.8, 0.95), "sheen": 0.3},
}


# ---------------------------------------------------------------- reusable models
def cloud_parts(scale=1.0, dx=0.0, dz=0.0):
    """A cumulus from 7 overlapping soft balls and a flat-ish soft base."""
    s = scale
    P = [ball(-0.56, -0.08, 0.28, y=0.02, stiff=5.0), ball(-0.26, 0.14, 0.36, y=-0.06, stiff=5.0), ball(0.14, 0.17, 0.40, y=-0.04, stiff=5.0),
         ball(0.50, -0.03, 0.30, y=0.04, stiff=5.0), ball(-0.02, -0.04, 0.34, y=-0.14, stiff=5.0),
         capsule(0.0, -0.22, 0.40, 0.22, y=-0.02, stiff=4.0)]
    out = []
    for p in P:
        q = dict(p); x, y, z = p["co"]
        q["co"] = (x * s + dx, y * s, z * s + dz); q["r"] = p["r"] * s
        if "size" in p: q["size"] = tuple(v * s for v in p["size"])
        out.append(q)
    return out


def sun_parts(x=0.0, z=0.0, scale=1.0, rays=10):
    s = scale
    P = [ball(x, z, 0.40 * s, stiff=3.0)]
    for i in range(rays):                                           # short soft rays (rounded rods around the ball)
        a = 2 * math.pi * i / rays
        cx, cz = x + math.cos(a) * 0.57 * s, z + math.sin(a) * 0.57 * s
        P.append(capsule(cx, cz, 0.05 * s, 0.07 * s, rot=-math.degrees(a), stiff=2.5))
    return P


def moon_parts(x=0.0, z=0.0, scale=1.0):
    """A thick soft crescent from a row of balls along an arc (fat in the middle, thin horns), with a few craters pressed in."""
    s = scale
    P = []
    n = 15
    for i in range(n):
        u = i / (n - 1)
        ang = math.radians(95 + 170 * u)                             # opens to the right
        r = (0.05 + 0.115 * math.sin(math.pi * u) ** 0.9) * s
        P.append(ball(x + math.cos(ang) * 0.46 * s + 0.12 * s, z + math.sin(ang) * 0.46 * s, r, y=0.0, stiff=4.0))
    P += [ball(x - 0.32 * s, z + 0.02 * s, 0.04 * s, y=-0.2 * s, neg=True, stiff=4.0), ball(x - 0.26 * s, z + 0.20 * s, 0.03 * s, y=-0.18 * s, neg=True, stiff=4.0),
          ball(x - 0.27 * s, z - 0.18 * s, 0.035 * s, y=-0.18 * s, neg=True, stiff=4.0)]
    return P


def star_parts(x, z, s=1.0):
    return [ball(x, z, 0.06 * s), capsule(x, z, 0.09 * s, 0.035 * s, rot=0), capsule(x, z, 0.09 * s, 0.035 * s, rot=90)]


def drop_parts(x, z, s=1.0):
    return [ball(x, z - 0.03 * s, 0.10 * s, stiff=3.0), ball(x, z + 0.06 * s, 0.07 * s, stiff=3.0), ball(x, z + 0.14 * s, 0.042 * s, stiff=3.0)]


def flake_parts(x, z, s=1.0):
    P = [ball(x, z, 0.06 * s)]
    for ang in (0, 60, 120):
        P.append(capsule(x, z, 0.12 * s, 0.026 * s, rot=ang))
    for ang in (0, 60, 120):                                        # tips
        for sign in (1, -1):
            a = math.radians(ang)
            P.append(ball(x + sign * math.cos(a) * 0.145 * s, z + sign * math.sin(a) * 0.145 * s, 0.042 * s))
    return P


def bolt_parts(x=0.0, z=0.0, s=1.0):
    pts = [(0.14, 0.40), (-0.06, 0.04), (0.10, 0.02), (-0.14, -0.42)]
    P = []
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        half = math.hypot(bx - ax, bz - az) / 2
        rot = -math.degrees(math.atan2(bz - az, bx - ax))
        P.append(capsule(x + mx * s, z + mz * s, half * s, 0.085 * s, rot=rot, stiff=2.2))
    return P


def hail_parts(x, z, s=1.0):
    return [ball(x, z, 0.105 * s, stiff=3.5)]


def fog_parts():
    return [capsule(-0.05, 0.12, 0.34, 0.085), capsule(0.12, -0.08, 0.30, 0.085), capsule(-0.10, -0.28, 0.36, 0.085)]


# ---------------------------------------------------------------- the icons: variant -> ordered layers (back to front) -> {material, parts}
def L(material, parts):
    return {"material": material, "parts": parts}


def variants():
    V = {}
    cl = lambda mat="cloud", sc=1.0, dx=0.0, dz=0.0: L(mat, cloud_parts(sc, dx, dz))
    V["clear_day"] = {"sun": L("sun", sun_parts(0.0, 0.0, 1.0))}
    V["clear_night"] = {"moon": L("moon", moon_parts(0.0, 0.0, 1.0)),
                        "stars": L("star", star_parts(0.62, 0.55, 1.1) + star_parts(-0.64, 0.46, 0.8) + star_parts(0.55, -0.50, 0.6))}
    V["mostly_clear_day"] = {"sun": L("sun", sun_parts(-0.18, 0.2, 0.78)), "cloud": cl("cloud", 0.62, 0.30, -0.28)}
    V["mostly_clear_night"] = {"moon": L("moon", moon_parts(-0.18, 0.2, 0.78)), "stars": L("star", star_parts(0.55, 0.62, 0.9)), "cloud": cl("cloud", 0.62, 0.30, -0.28)}
    V["partly_day"] = {"sun": L("sun", sun_parts(-0.28, 0.28, 0.68)), "cloud": cl("cloud", 0.86, 0.1, -0.18)}
    V["partly_night"] = {"moon": L("moon", moon_parts(-0.30, 0.30, 0.74)), "cloud": cl("cloud", 0.84, 0.16, -0.22)}
    V["cloudy"] = {"cloud_back": cl("cloud_grey", 0.62, -0.36, 0.22), "cloud": cl("cloud", 0.86, 0.12, -0.12)}
    V["fog"] = {"cloud": cl("cloud_grey", 0.78, 0.0, 0.30), "fog": L("fog", [dict(p, co=(p["co"][0], p["co"][1], p["co"][2] - 0.2)) for p in fog_parts()])}
    dr = lambda xs, z: L("drop", sum([drop_parts(x, z - (i % 2) * 0.12, 1.0) for i, x in enumerate(xs)], []))
    V["drizzle"] = {"cloud": cl("cloud", 0.86, 0.0, 0.26), "drops_a": dr([-0.30, 0.18], -0.46), "drops_b": dr([-0.06, 0.40], -0.50)}
    V["rain"] = {"cloud": cl("cloud_grey", 0.9, 0.0, 0.26), "drops_a": dr([-0.44, -0.04, 0.34], -0.44), "drops_b": dr([-0.24, 0.16, 0.52], -0.52)}
    V["heavy_rain"] = {"cloud": cl("cloud_dark", 0.92, 0.0, 0.28), "drops_a": dr([-0.46, -0.10, 0.26, 0.60], -0.44), "drops_b": dr([-0.28, 0.08, 0.44], -0.54)}
    V["thunder"] = {"cloud": cl("cloud_dark", 0.92, 0.0, 0.30), "bolt": L("bolt", bolt_parts(0.04, -0.56, 0.9)), "drops_a": dr([-0.52, 0.56], -0.52)}
    fk = lambda xs, z, s=1.0: L("flake", sum([flake_parts(x, z - (i % 2) * 0.12, s) for i, x in enumerate(xs)], []))
    V["snow"] = {"cloud": cl("cloud", 0.9, 0.0, 0.26), "flakes_a": fk([-0.54, 0.02, 0.56], -0.50, 0.95), "flakes_b": fk([-0.26, 0.30], -0.80, 0.85)}
    V["sleet"] = {"cloud": cl("cloud_grey", 0.9, 0.0, 0.26), "drops_a": dr([-0.38, 0.40], -0.48), "flakes_a": fk([0.02], -0.52, 1.1)}
    hl = lambda xs, z: L("hail", sum([hail_parts(x, z - (i % 2) * 0.12, 1.0) for i, x in enumerate(xs)], []))
    V["hail"] = {"cloud": cl("cloud_dark", 0.92, 0.0, 0.28), "hail_a": hl([-0.44, -0.04, 0.38], -0.46), "hail_b": hl([-0.24, 0.18, 0.58], -0.54)}
    V["unknown"] = {"cloud": cl("cloud_grey", 0.92, 0.0, 0.0)}
    return V


if __name__ == "__main__":       # python3 tools/blender/icon_scenes.py  -> {variant: [layers]} (used by tools/weathercard-test.js)
    import json
    print(json.dumps({k: list(v.keys()) for k, v in variants().items()}))
