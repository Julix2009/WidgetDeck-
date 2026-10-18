#version 440
// WidgetDeck Liquid Glass shader.
//
// DERIVED WORK. This file is based on `liquidglass.frag` from MacShell (https://github.com/0-ss/MacShell),
// MIT License, Copyright (c) 2026 Rickky. The licence text is in LICENSES/MIT-MacShell.txt and NOTICE.md; both must be kept
// with every copy of this file. Changes made for WidgetDeck:
//   * `lightDir`  (the original hard-codes the light direction; the default vector is the same one)
//   * optional smooth-union with neighbouring glass boxes (nbCount = 0 -> the original code path, unchanged)
//   * `themeTint` (a theme colour mixed into the flat tint)
//
// The shader treats the element as a slab of curved glass sitting on top of a pre-blurred backdrop texture:
//   * a rounded-rect signed distance field gives the distance to the edge and the edge direction
//   * a convex "squircle" bezel profile turns that into a surface normal
//   * Snell's law (refract) turns the normal into a lateral shift of the sampled backdrop
//   * the backdrop is sampled per colour channel (dispersion) through a small disk blur
//   * saturation / tint / milky lift, then specular rim, inner depth shading and a soft drop shadow
//
// Build:  qsb --qt6 -o glass.frag.qsb glass.frag      (done by GlassBackend.qml, cached)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // whole shader item in px (glass + pad on every side)
    vec2 glassSize;     // the glass rectangle in px
    vec2 srcSize;       // backdrop texture size in px
    vec2 srcOffset;     // where the item's top-left sits inside the backdrop texture, px
    vec2 lightDir;      // unit vector towards the light (screen coords, y down)
    float pad;          // item padding around the glass (room for the drop shadow)
    float radius;       // corner radius, px
    float bezel;        // width of the refracting rim, px
    float thickness;    // how far the rim shifts the backdrop, px
    float dispersion;   // chromatic split (0 = none)
    float blurPx;       // backdrop blur radius, px
    float tintMix;      // 0..1 amount of flat tint (the "translucency" slider)
    float saturation;   // backdrop saturation boost
    float dark;         // 0 = light mode, 1 = dark mode
    float debug;        // 1 = show the raw backdrop texture
    float rim;          // specular edge highlight strength
    float grain;        // fine noise amplitude over the whole glass
    float magnify;      // vertical lens magnification of the whole slab
    float shadowAmt;    // drop-shadow strength
    // --- additions (all neutral at their defaults) ---
    vec4 themeTint;     // rgb = theme colour, a = amount mixed into the flat tint (0 = the plain look)
    float nbCount;      // neighbouring glass boxes for the smooth union
    vec4 nb0;           // cx, cy, halfW, halfH (px, relative to this glass' centre)
    vec4 nb1;
    vec4 nb2;
    vec4 nb3;
    vec4 nbR;           // their corner radii
    vec4 nbK;           // their smooth-union strength
};

layout(binding = 1) uniform sampler2D src;

const int   TAPS   = 24;
const float GOLDEN = 2.39996323;

vec3 backdropLod(vec2 pItem, float lod)
{
    vec2 uv = (pItem + srcOffset) / srcSize;
    return textureLod(src, clamp(uv, vec2(0.001), vec2(0.999)), lod).rgb;
}

float ign(vec2 p)
{
    return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

vec3 blurredDisp(vec2 pItem, vec2 disp, float disperse, float rad)
{
    float R   = max(rad, 0.5) * 1.5;                       // Gaussian reaches further than a flat disk
    float gap = R * sqrt(3.14159265 / float(TAPS));        // spacing between neighbouring taps, px
    float lod = clamp(log2(max(gap, 1.0)) + 0.35, 0.0, 6.0);
    float rot = ign(gl_FragCoord.xy) * 6.2831853;
    vec3  acc = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < TAPS; ++i) {
        float fi = float(i) + 0.5;
        float r  = sqrt(fi / float(TAPS));
        float a  = fi * GOLDEN + rot;
        float w  = exp(-2.2 * r * r);
        vec2  o  = vec2(cos(a), sin(a)) * r * R;
        vec3  c;
        c.r = backdropLod(pItem + o + disp * (1.0 + disperse), lod).r;
        c.g = backdropLod(pItem + o + disp,                    lod).g;
        c.b = backdropLod(pItem + o + disp * (1.0 - disperse), lod).b;
        acc  += c * w;
        wsum += w;
    }
    return acc / wsum;
}

float hash12(vec2 p)
{
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float roundBox(vec2 q, vec2 hs, float r)
{
    vec2 d = abs(q) - (hs - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// ---- additions: smooth union with neighbouring boxes (only used when nbCount > 0) ----
float smin(float a, float b, float k)
{
    if (k <= 0.0) return min(a, b);
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}
vec4 nbBox(int i) { return i == 0 ? nb0 : (i == 1 ? nb1 : (i == 2 ? nb2 : nb3)); }
float field(vec2 q, vec2 hs, float r)
{
    float d = roundBox(q, hs, r);
    int n = int(nbCount + 0.5);
    for (int i = 0; i < 4; i++) {
        if (i >= n) break;
        vec4 B = nbBox(i);
        d = smin(d, roundBox(q - B.xy, B.zw, nbR[i]), nbK[i]);
    }
    return d;
}

void main()
{
    vec2 p  = qt_TexCoord0 * itemSize;
    vec2 hs = glassSize * 0.5;
    vec2 q  = p - itemSize * 0.5;                  // glass is centred in the item (== p - pad - hs when item = glass + 2*pad)
    float r = min(radius, min(hs.x, hs.y));
    int nn = int(nbCount + 0.5);

    float sd  = roundBox(q, hs, r);               // < 0 inside the glass
    if (nn > 0) {
        // each pixel is drawn by exactly one glass: the one whose own box is nearest
        for (int i = 0; i < 4; i++) {
            if (i >= nn) break;
            if (roundBox(q - nbBox(i).xy, nbBox(i).zw, nbR[i]) < sd - 0.01) { fragColor = vec4(0.0); return; }
        }
        sd = field(q, hs, r);
    }
    float cov = clamp(0.5 - sd, 0.0, 1.0);        // anti-aliased coverage

    if (debug > 0.5) {
        vec4 s = texture(src, clamp((p + srcOffset) / srcSize, vec2(0.001), vec2(0.999)));
        fragColor = (s.a < 0.01 ? vec4(1.0, 0.0, 1.0, 1.0) : vec4(s.rgb / max(s.a, 1e-3), 1.0)) * cov * qt_Opacity;
        return;
    }

    // ── soft drop shadow (only visible outside the glass) ──
    float sds    = (nn > 0) ? field(q - vec2(0.0, 3.0), hs, r) : roundBox(q - vec2(0.0, 3.0), hs, r);
    float shadow = 0.30 * shadowAmt * (1.0 - smoothstep(-2.0, 9.0, sds));
    if (sd > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, shadow) * qt_Opacity;
        return;
    }

    // ── distance to edge + outward edge direction ──
    float t = max(-sd, 0.0);
    vec2 d2 = abs(q) - (hs - r);
    vec2 sg = vec2(q.x >= 0.0 ? 1.0 : -1.0, q.y >= 0.0 ? 1.0 : -1.0);
    vec2 m  = max(d2, 0.0);
    vec2 g  = (length(m) > 1e-4) ? normalize(m) * sg
                                 : ((d2.x > d2.y) ? vec2(sg.x, 0.0) : vec2(0.0, sg.y));
    float neck = 1.0;
    if (nn > 0) {                                  // merged glass: numeric gradient of the union field
        vec2 e = vec2(1.0, 0.0);
        vec2 gn = vec2(field(q + e.xy, hs, r) - field(q - e.xy, hs, r), field(q + e.yx, hs, r) - field(q - e.yx, hs, r));
        neck = smoothstep(0.30, 0.85, length(gn) * 0.5);
        g = gn / max(length(gn), 1e-4);
    }

    // ── convex squircle bezel → surface normal ──
    float bz   = max(bezel, 1.0) * 1.45;           // wider bezel: the glass reads thicker
    float u    = clamp(t / bz, 0.0, 1.0);
    float om   = 1.0 - u;
    float om4  = om * om * om * om;
    float slope = (om * om * om) / pow(max(1.0 - om4, 1e-3), 0.75);
    slope = min(slope, 7.0) * neck;
    vec3 n = normalize(vec3(g * slope, 1.0));

    // ── refraction: glass n≈1.5, ray enters straight down ──
    vec3 rd   = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / 1.5);
    vec2 disp = rd.xy / max(-rd.z, 0.2) * thickness * 1.35;

    // the whole slab acts as a gentle vertical lens; blur is crisper right at the curved rim
    vec2 ps = vec2(p.x, (p.y - itemSize.y * 0.5) * (1.0 - magnify * 1.5) + itemSize.y * 0.5);
    float rad = blurPx * mix(0.45, 1.0, smoothstep(0.0, bz, t));

    vec3 col = blurredDisp(ps, disp, dispersion * 0.6, rad);

    // ── colour grading: vibrancy, tint, milky lift ──
    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(l), col, saturation);
    vec3 tintC = mix(vec3(1.0), vec3(0.09, 0.09, 0.10), dark);
    tintC = mix(tintC, themeTint.rgb, themeTint.a);          // addition: subtle theme colour in the tint
    col = mix(col, tintC, tintMix);
    col += mix(0.055, 0.020, dark);

    // ── depth: soft top sheen, darker lower inner edge ──
    float ty = clamp((q.y + hs.y) / glassSize.y, 0.0, 1.0);
    col += (1.0 - ty) * mix(0.040, 0.030, dark);
    col *= 1.0 - 0.12 * exp(-t / 6.0) * clamp(g.y, 0.0, 1.0);
    col *= 1.0 - 0.10 * exp(-t / (bz * 0.45));          // thick glass absorbs light toward the edge (heavier feel)

    // ── specular rim, light from the top-left ──
    vec2  L      = lightDir;
    float facing = dot(g, L);
    float spec   = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
    float hair   = exp(-t / 1.1);
    float wide   = exp(-t / 5.0);
    float edgeHi = hair * (0.18 + 0.78 * spec) + wide * 0.10 * (0.30 + spec);
    edgeHi *= rim * mix(0.85, 1.0, dark);
    col += edgeHi * vec3(0.96, 0.98, 1.0);

    // meniscus: a soft second highlight inside the rim, like surface tension pulling the liquid together
    float mx  = (t - bz * 0.5) / (bz * 0.2 + 1.0);
    float men = exp(-mx * mx);
    col += men * 0.07 * (0.35 + spec) * rim * vec3(0.96, 0.98, 1.0);

    // fine triangular-distribution grain, same on every channel so it reads as texture, not colour noise
    float gn = hash12(gl_FragCoord.xy) + hash12(gl_FragCoord.xy * 1.7 + 17.0) - 1.0;
    col += gn * grain;

    col = clamp(col, 0.0, 1.0);

    float a = cov + shadow * (1.0 - cov);
    fragColor = vec4(col * cov, a) * qt_Opacity;   // premultiplied alpha
}
