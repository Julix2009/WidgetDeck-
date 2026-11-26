.pragma library
// Colour sources other than WidgetDeck's own matugen file:
//   parse(object, mode)      a colour file written by a shell or a theming tool  -> { role: "#rrggbb" } or null
//   fromColors(list, mode)   the dominant colours of the wallpaper               -> { role: "#rrggbb" }
// parse() does not depend on one tool: it understands flat Material roles (snake_case or camelCase, with or without the "m" prefix),
// the same nested under "colors" / "colours" and / or "dark" / "light", hex values with or without "#", pywal's colors.json
// and Catppuccin names.

function hex(v) {
    if (v && typeof v === "object") v = v.hex || v["default"] || v.color;
    if (typeof v !== "string") return null;
    var m = v.trim().match(/^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/);
    return m ? "#" + m[1].toLowerCase() : null;
}
function rgb(h) { return [parseInt(h.substr(1, 2), 16) / 255, parseInt(h.substr(3, 2), 16) / 255, parseInt(h.substr(5, 2), 16) / 255]; }
function luma(h) { var c = rgb(h); return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]; }
function hsl(h) {
    var c = rgb(h), mx = Math.max(c[0], c[1], c[2]), mn = Math.min(c[0], c[1], c[2]), l = (mx + mn) / 2, d = mx - mn, hu = 0, s = 0;
    if (d > 0) {
        s = d / (1 - Math.abs(2 * l - 1));
        if (mx === c[0]) hu = ((c[1] - c[2]) / d + 6) % 6; else if (mx === c[1]) hu = (c[2] - c[0]) / d + 2; else hu = (c[0] - c[1]) / d + 4;
        hu /= 6;
    }
    return { h: hu, s: Math.min(1, s), l: l };
}
function fromHsl(h, s, l) {
    h = ((h % 1) + 1) % 1;
    var c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h * 6) % 2 - 1)), m = l - c / 2, i = Math.floor(h * 6) % 6;
    var t = [[c, x, 0], [x, c, 0], [0, c, x], [0, x, c], [x, 0, c], [c, 0, x]][i];
    return "#" + t.map(function (v) { var n = Math.round(Math.max(0, Math.min(1, v + m)) * 255).toString(16); return n.length < 2 ? "0" + n : n; }).join("");
}

// every Material role from one accent colour
function fromSeed(seed, mode) {
    var d = mode !== "light", b = hsl(seed), h = b.h;
    var s = b.s < 0.08 ? 0.04 : Math.max(0.45, Math.min(0.85, b.s));       // a grey wallpaper stays grey
    var n = b.s < 0.08 ? 0.02 : 0.12;                                      // how strongly the neutrals are tinted
    var N = function (dl, ll) { return fromHsl(h, n, d ? dl : ll); };
    var A = function (hue, sat, dl, ll) { return fromHsl(hue, sat, d ? dl : ll); };
    var o = {
        background: N(0.08, 0.98), surface: N(0.08, 0.98), surface_dim: N(0.07, 0.87), surface_bright: N(0.23, 0.98),
        surface_container_lowest: N(0.05, 1.0), surface_container_low: N(0.10, 0.96), surface_container: N(0.13, 0.94),
        surface_container_high: N(0.17, 0.91), surface_container_highest: N(0.22, 0.89), surface_variant: N(0.28, 0.89),
        on_background: N(0.90, 0.11), on_surface: N(0.90, 0.11), on_surface_variant: N(0.78, 0.29),
        outline: N(0.59, 0.47), outline_variant: N(0.29, 0.80), inverse_surface: N(0.90, 0.19), inverse_on_surface: N(0.19, 0.95),
        shadow: "#000000", scrim: "#000000",
        error: d ? "#ffb4ab" : "#ba1a1a", on_error: d ? "#690005" : "#ffffff",
        error_container: d ? "#93000a" : "#ffdad6", on_error_container: d ? "#ffdad6" : "#410002"
    };
    [["primary", h, s], ["secondary", h, s * 0.45], ["tertiary", h + 0.17, s * 0.7]].forEach(function (r) {
        o[r[0]] = A(r[1], r[2], 0.80, 0.38);
        o["on_" + r[0]] = A(r[1], r[2], 0.18, 1.0);
        o[r[0] + "_container"] = A(r[1], r[2], 0.30, 0.90);
        o["on_" + r[0] + "_container"] = A(r[1], r[2], 0.90, 0.12);
    });
    o.surface_tint = o.primary;
    o.inverse_primary = A(h, s, 0.38, 0.80);
    return o;
}

// dominant colours (most colourful of the usual brightness wins as accent)
function fromColors(list, mode) {
    var best = null, score = -1;
    for (var i = 0; i < (list || []).length; i++) {
        var c = hex(String(list[i]).length === 9 ? "#" + String(list[i]).substr(3) : String(list[i]));   // Qt gives #aarrggbb for translucent colours
        if (!c) continue;
        var v = hsl(c), sc = v.s * (1 - Math.abs(v.l - 0.55) * 1.4);
        if (sc > score) { score = sc; best = c; }
    }
    return best ? fromSeed(best, mode) : null;
}

function roleName(k) {
    if (/^m[A-Z]/.test(k)) k = k.charAt(1).toLowerCase() + k.substr(2);
    return k.replace(/([a-z0-9])([A-Z])/g, "$1_$2").toLowerCase();
}

var CATPPUCCIN = { surface: "base", surface_container: "mantle", surface_container_lowest: "crust", on_surface: "text", on_surface_variant: "subtext0",
                   surface_container_high: "surface0", surface_container_highest: "surface1", outline: "overlay1", outline_variant: "surface2",
                   primary: "blue", secondary: "green", tertiary: "mauve", error: "red" };

function parse(o, mode) {
    if (!o || typeof o !== "object") return null;
    var given = {}, k, v;
    var root = o.colors || o.colours || o;
    if (root[mode] && typeof root[mode] === "object") root = root[mode];
    else if (root.dark && typeof root.dark === "object") root = root.dark;
    else if (root.light && typeof root.light === "object") root = root.light;

    if (root.color0 !== undefined) {                       // pywal: special.background / foreground + 16 terminal colours
        var sp = o.special || {};
        var pairs = [["surface", sp.background || root.color0], ["on_surface", sp.foreground || root.color7], ["primary", root.color4], ["secondary", root.color2], ["tertiary", root.color5], ["error", root.color1]];
        for (var i = 0; i < pairs.length; i++) { v = hex(pairs[i][1]); if (v) given[pairs[i][0]] = v; }
    } else if (root.base !== undefined && root.text !== undefined) {
        for (k in CATPPUCCIN) { v = hex(root[CATPPUCCIN[k]]); if (v) given[k] = v; }
    } else {
        for (k in root) { v = hex(root[k]); if (v) given[roleName(k)] = v; }
    }
    if (!given.surface && given.background) given.surface = given.background;
    if (!given.primary || !given.surface) return null;

    // a file with only one brightness: for the other one only the accent can be used
    var out = fromSeed(given.primary, mode);
    if ((luma(given.surface) < 0.5) !== (mode !== "light")) return out;
    for (k in given) out[k] = given[k];
    if (!given.background) out.background = out.surface;
    if (!given.surface_container) {                        // few colours only: derive the card shades from the surface
        var s = hsl(given.surface), up = mode !== "light" ? 1 : -1;
        [["surface_container_lowest", -0.025], ["surface_container_low", 0.02], ["surface_container", 0.045], ["surface_container_high", 0.085], ["surface_container_highest", 0.13]].forEach(function (r) {
            if (!given[r[0]]) out[r[0]] = fromHsl(s.h, s.s, Math.max(0, Math.min(1, s.l + r[1] * up)));
        });
    }
    if (!given.on_primary) out.on_primary = luma(given.primary) > 0.5 ? "#101216" : "#ffffff";
    return out;
}
