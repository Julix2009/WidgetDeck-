"""Renders the weather card icons with Blender (Cycles) as transparent sprite layers.

    blender --background --python tools/blender/render_icons.py -- [options]
or  tools/blender/render.sh [options]

What it makes (all reproducible from icon_scenes.py, nothing is downloaded or copied):
  <out>/<variant>/<layer>/<yaw>_<pitch>.webp   one layer of one icon seen from a slightly different angle (soft metaball models, SSS-like
                                                clay material, key light top left, fill right below, rim light, ambient occlusion by the world light)
  <out>/<variant>/shadow/<yaw>_<pitch>.webp    the soft drop shadow of the whole icon on a wall behind it (shadow catcher = "the glass")
  <out>/<variant>/small.webp                   all layers merged, front view, for the hour strip
  <out>/manifest.json                          sizes, angles, variants and layers
The widget blends the neighbouring angle frames while the mouse moves over the icon (real 3D rotation, not a 2D shift).
Options:  --out DIR  --size 512  --small-size 256  --samples 48  --yaw 5  --pitch 3  --yaw-range 15  --pitch-range 10
          --only clear_day,rain   --quick (front view only, low samples: for looking at the result)   --png (keep PNG, no WebP)
Own work (MIT).
"""
import bpy
import json
import math
import os
import shutil
import subprocess
import sys
from mathutils import Euler, Quaternion, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import icon_scenes as S  # noqa: E402


# ------------------------------------------------------------------ command line
def parse():
    a = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    o = {"out": os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "qml", "widgets", "weathercard", "icons3d"), "size": 256, "small": 128,
         "samples": 32, "yaw": 5, "pitch": 3, "yaw_range": 15.0, "pitch_range": 10.0, "only": None, "quick": False, "png": False,
         "key": 400.0, "fill": 55.0, "rim": 230.0, "world": 0.28, "exposure": 0.0, "view": "Standard"}
    i = 0
    while i < len(a):
        k = a[i]
        if k == "--quick": o["quick"] = True
        elif k == "--png": o["png"] = True
        elif k == "--helpers-only": o["helpers"] = True
        elif k in ("--out", "--only"): o[k[2:]] = a[i + 1]; i += 1
        elif k in ("--size", "--samples", "--yaw", "--pitch"): o[k[2:]] = int(a[i + 1]); i += 1
        elif k in ("--key", "--fill", "--rim", "--world", "--exposure"): o[k[2:]] = float(a[i + 1]); i += 1
        elif k == "--view": o["view"] = a[i + 1]; i += 1
        elif k == "--small-size": o["small"] = int(a[i + 1]); i += 1
        elif k in ("--yaw-range", "--pitch-range"): o[k[2:].replace("-", "_")] = float(a[i + 1]); i += 1
        i += 1
    o["out"] = os.path.abspath(o["out"])
    if o["only"]: o["only"] = set(o["only"].split(","))
    return o


# ------------------------------------------------------------------ helpers
def setin(node, names, value):
    """Set the first existing input of a node (socket names differ between Blender versions)."""
    for n in names:
        if n in node.inputs:
            try:
                node.inputs[n].default_value = value
                return True
            except Exception:
                pass
    return False


def make_material(name, spec):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = mat.node_tree.nodes["Principled BSDF"]
    base = spec["base"]
    setin(b, ["Base Color"], (base[0], base[1], base[2], 1.0))
    setin(b, ["Roughness"], spec.get("rough", 0.5))
    sss = spec.get("sss", 0.0)
    if sss:
        setin(b, ["Subsurface Weight", "Subsurface"], sss)
        c = spec.get("sss_color", base)
        setin(b, ["Subsurface Radius"], tuple(spec.get("sss_radius", (1.0, 0.8, 0.6))))
        setin(b, ["Subsurface Scale"], 0.25)
        setin(b, ["Subsurface Color"], (c[0], c[1], c[2], 1.0))          # only in older versions; newer ones use the base colour
        if "Subsurface Weight" in b.inputs and spec.get("sss_color"):    # newer: tint the scattering through the base colour a little
            mix = spec["sss_color"]
            setin(b, ["Base Color"], (base[0] * 0.8 + mix[0] * 0.2, base[1] * 0.8 + mix[1] * 0.2, base[2] * 0.8 + mix[2] * 0.2, 1.0))
    setin(b, ["Sheen Weight", "Sheen"], spec.get("sheen", 0.0))
    setin(b, ["Sheen Roughness"], 0.5)
    setin(b, ["Coat Weight", "Clearcoat"], spec.get("coat", 0.0))
    setin(b, ["Coat Roughness", "Clearcoat Roughness"], 0.12)
    if "emit" in spec:
        e = spec["emit"]
        setin(b, ["Emission Color", "Emission"], (e[0], e[1], e[2], 1.0))
        setin(b, ["Emission Strength"], spec.get("emit_strength", 1.0))
    return mat


def threshold_scale(stiff, thr):
    """A metaball element of radius r and stiffness s reaches r * sqrt(1 - (thr / s) ** (1/3)) at the threshold (field = s * (1 - d^2/r^2)^3)."""
    return math.sqrt(max(0.05, 1.0 - (thr / stiff) ** (1.0 / 3.0)))


def build_layer(name, layer, materials):
    thr = 0.6
    mb = bpy.data.metaballs.new(name)
    mb.threshold = thr
    mb.resolution = 0.045
    mb.render_resolution = 0.012
    mb.update_method = 'UPDATE_ALWAYS'
    for p in layer["parts"]:
        t = {"ball": 'BALL', "capsule": 'CAPSULE', "ellipsoid": 'ELLIPSOID'}[p["kind"]]
        el = mb.elements.new(type=t)
        k = threshold_scale(p["stiff"], thr)
        el.co = Vector(p["co"])
        el.radius = p["r"] / k
        el.stiffness = p["stiff"]
        el.use_negative = p.get("neg", False)
        if t == 'CAPSULE':
            el.size_x = p["size"][0]
            el.rotation = Quaternion((0.0, 1.0, 0.0), -math.radians(p.get("rot", 0.0)))      # about the viewing axis (y)
        elif t == 'ELLIPSOID':
            el.size_x, el.size_y, el.size_z = p["size"]
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(materials[layer["material"]])
    return obj


def add_area(name, loc, size, energy, color):
    d = bpy.data.lights.new(name, 'AREA')
    d.energy, d.size, d.color = energy, size, color
    o = bpy.data.objects.new(name, d)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    return o


def setup(o):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    c = sc.cycles
    c.device = 'CPU'
    c.samples = o["samples"]
    c.use_adaptive_sampling = True
    c.adaptive_threshold = 0.02
    c.max_bounces = 6
    c.use_denoising = True
    try:
        c.denoiser = 'OPENIMAGEDENOISE'
    except Exception:
        pass
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.image_settings.color_depth = '8'
    sc.view_settings.view_transform = o["view"]
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = o["exposure"]
    w = bpy.data.worlds.new("World")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.66, 0.74, 0.95, 1.0)       # a cool sky-ish ambient: soft blue in the shadows, ambient occlusion comes from it
    bg.inputs[1].default_value = o["world"]
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens, cam.data.sensor_width = 80.0, 36.0           # slight perspective; the frame spans about +-1.125 units at distance 5
    sc.collection.objects.link(cam)
    cam.location = (0.0, -5.0, 0.0)
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    sc.camera = cam
    lights = {
        "key": add_area("Key", (-3.2, -4.2, 3.4), 4.5, o["key"], (1.0, 0.97, 0.92)),      # big soft light from the top left
        "fill": add_area("Fill", (3.2, -4.0, -2.2), 3.0, o["fill"], (0.80, 0.86, 1.0)),      # weak fill from the right below
        "rim": add_area("Rim", (1.8, 3.6, 2.4), 3.0, o["rim"], (1.0, 0.96, 0.90)),          # rim light from behind
    }
    wall = bpy.data.objects.new("Wall", bpy.data.meshes.new("Wall"))
    me = wall.data
    me.from_pydata([(-6, 0, -6), (6, 0, -6), (6, 0, 6), (-6, 0, 6)], [], [(0, 1, 2, 3)])
    sc.collection.objects.link(wall)
    wall.location = (0.0, 0.95, 0.0)
    wall.is_shadow_catcher = True
    rig = bpy.data.objects.new("Rig", None)
    sc.collection.objects.link(rig)
    return sc, lights, wall, rig


def render(sc, path, size, samples):
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.cycles.samples = samples
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def to_webp(png, keep_png):
    if keep_png:
        return png
    out = png[:-4] + ".webp"
    for tool in (["cwebp", "-quiet", "-q", "92", "-alpha_q", "100", "-exact", png, "-o", out], ["magick", png, "-quality", "92", "-define", "webp:alpha-quality=100", "-define", "webp:exact=true", out]):
        if shutil.which(tool[0]):
            try:
                subprocess.run(tool, check=True, capture_output=True)
                os.remove(png)
                return out
            except Exception:
                continue
    return png


def tint_shadow(png):
    """Shadow sprite: neutral bluish colour, low strength, a little softened (it must not colour the glass)."""
    if shutil.which("magick"):
        subprocess.run(["magick", png, "-channel", "A", "-evaluate", "multiply", "1.43", "-blur", "0x3.5", "+channel", "-fill", "#1b2648", "-colorize", "100%", png], check=False)
        fade_edges(png)


def fade_edges(png):
    """The shadow wall is bigger than the picture: fade the shadow out towards the borders so it never ends in a hard edge."""
    if shutil.which("magick"):
        subprocess.run(["magick", png, "-channel", "A", "-fx", "u.a*min(1,min(i,w-1-i)/(w*0.2))*min(1,min(j,h-1-j)/(h*0.2))", "+channel", png], check=False)


def helper_images(out, keep_png):
    """Three plain gradient helpers (made with ImageMagick, no 3D needed): the warm glow behind the sun, the light spot that follows the mouse,
    and the soft contact shadow below the small hour icons."""
    if not shutil.which("magick"):
        print("magick not found: glow / spot / shadow_small were not made", flush=True)
        return
    E = "hypot(i-(w-1)/2,(j-(h-1)/2)*(w/h))/((w-1)/2)"          # 0 in the middle, 1 at the border of the ellipse
    fx = lambda col, amp, p: ["xc:" + col, "-alpha", "set", "-channel", "A", "-fx", "(%s<1)?%s*pow(1-%s,%s):0" % (E, amp, E, p), "+channel"]
    for name, args in (("glow", ["-size", "256x256"] + fx("rgb(255,196,96)", "0.7", "2")),
                       ("spot", ["-size", "128x128"] + fx("white", "0.9", "2")),
                       ("shadow_small", ["-size", "128x43"] + fx("rgb(27,38,72)", "0.55", "1.5"))):
        subprocess.run(["magick"] + args + ["-strip", os.path.join(out, name + ".png")], check=False)


def main():
    o = parse()
    if o.get("helpers"):                       # only the plain gradient images (glow, spot, shadow_small)
        os.makedirs(o["out"], exist_ok=True)
        helper_images(o["out"], o["png"])
        return
    sc, lights, wall, rig = setup(o)
    mats = {n: make_material("M_" + n, s) for n, s in S.MATERIALS.items()}
    V = S.variants()
    names = [v for v in V if not o["only"] or v in o["only"]]
    yaw_n, pit_n = (1, 1) if o["quick"] else (o["yaw"], o["pitch"])
    yaws = [0.0] if yaw_n == 1 else [(-o["yaw_range"] + 2 * o["yaw_range"] * i / (yaw_n - 1)) for i in range(yaw_n)]
    pits = [0.0] if pit_n == 1 else [(-o["pitch_range"] + 2 * o["pitch_range"] * i / (pit_n - 1)) for i in range(pit_n)]
    samples = max(8, o["samples"] // 3) if o["quick"] else o["samples"]
    os.makedirs(o["out"], exist_ok=True)
    manifest = {"size": o["size"], "small": o["small"], "yaw": yaws, "pitch": pits, "variants": {}}
    for vname in names:
        layers = V[vname]
        objs = {ln: build_layer(vname + "_" + ln, layers[ln], mats) for ln in layers}
        for ob in objs.values():
            ob.parent = rig
        manifest["variants"][vname] = {"layers": list(layers.keys())}
        base = os.path.join(o["out"], vname)

        def frame(target, yi, pi, size, only=None, shadow=False):
            rig.rotation_euler = Euler((math.radians(pits[pi]), 0.0, math.radians(yaws[yi])), 'XYZ')
            for ln, ob in objs.items():
                ob.visible_camera = (not shadow) and (only is None or ln == only)     # hidden objects still cast shadows and occlude light
            wall.hide_render = not shadow
            lights["rim"].hide_render = shadow
            os.makedirs(os.path.dirname(target), exist_ok=True)
            render(sc, target, size, samples)
            if shadow:
                tint_shadow(target)
            return to_webp(target, o["png"])

        for yi in range(len(yaws)):
            for pi in range(len(pits)):
                # (the grid is a full yaw x pitch matrix: the widget blends the four neighbours)
                for ln in objs:
                    frame(os.path.join(base, ln, "%d_%d.png" % (yi, pi)), yi, pi, o["size"], only=ln)
                frame(os.path.join(base, "shadow", "%d_%d.png" % (yi, pi)), yi, pi, max(64, o["size"] // 2), shadow=True)     # the shadow is soft anyway
        # merged front view for the hour strip
        yi0, pi0 = len(yaws) // 2, len(pits) // 2
        frame(os.path.join(base, "small.png"), yi0, pi0, o["small"], only=None)
        print("done", vname, flush=True)
        for ob in objs.values():
            bpy.data.objects.remove(ob, do_unlink=True)
    helper_images(o["out"], o["png"])
    with open(os.path.join(o["out"], "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=1)
    print("icons written to", o["out"], flush=True)


main()
