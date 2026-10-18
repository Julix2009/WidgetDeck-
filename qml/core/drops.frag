#version 440
// Weather drops for Liquid Glass widgets (WidgetDeck). The refraction maths is taken over from glass.frag, which is derived from
// MacShell's liquidglass.frag (MIT, Copyright (c) 2026 Rickky - see NOTICE.md); the drop simulation and shading around it are new.
// Rain beads are small glass lenses: the same slab model as the panel (convex squircle bezel -> normal -> Snell's law),
// sampled from the SAME blurred wallpaper texture by absolute screen coordinates, with the same saturation / tint / rim light.
// Snow flakes are small soft frosted discs. Everything is computed from at most 40 circles; pixels that are not inside a
// circle (or its soft shadow) leave after the first loop, so the cost scales with the number of drops, not with the panel size.
//
// Build:  qsb --qt6 -o drops.frag.qsb drops.frag      (done by GlassBackend.qml, cached)
// Each drop d_i = (x, y, radius, signed alpha) in px inside the item; alpha < 0 marks a snow flake. count = drops in use.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;      // the shader item in px
    vec2 srcSize;       // backdrop texture size in px (= the screen)
    vec2 srcOffset;     // where the item's top-left sits on the screen, px
    vec2 lightDir;      // unit vector towards the light
    float thickness;    // refraction depth (same value the panel uses, scaled by the drop size below)
    float dispersion;
    float rim;          // specular rim strength
    float saturation;
    float dark;         // 1 = dark glass
    float tintMix;      // flat tint amount (the panel's translucency)
    float count;
    vec4 d0;
    vec4 d1;
    vec4 d2;
    vec4 d3;
    vec4 d4;
    vec4 d5;
    vec4 d6;
    vec4 d7;
    vec4 d8;
    vec4 d9;
    vec4 d10;
    vec4 d11;
    vec4 d12;
    vec4 d13;
    vec4 d14;
    vec4 d15;
    vec4 d16;
    vec4 d17;
    vec4 d18;
    vec4 d19;
    vec4 d20;
    vec4 d21;
    vec4 d22;
    vec4 d23;
    vec4 d24;
    vec4 d25;
    vec4 d26;
    vec4 d27;
    vec4 d28;
    vec4 d29;
    vec4 d30;
    vec4 d31;
    vec4 d32;
    vec4 d33;
    vec4 d34;
    vec4 d35;
    vec4 d36;
    vec4 d37;
    vec4 d38;
    vec4 d39;
};

layout(binding = 1) uniform sampler2D src;

vec3 backdrop(vec2 pItem)
{
    vec2 uv = (pItem + srcOffset) / srcSize;
    return texture(src, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    int n = int(count + 0.5);
    float best = 1.0e5;
    vec4 dd = vec4(0.0);
    if (0 < n) { float e = length(p - d0.xy) - d0.z; if (e < best) { best = e; dd = d0; } }
    if (1 < n) { float e = length(p - d1.xy) - d1.z; if (e < best) { best = e; dd = d1; } }
    if (2 < n) { float e = length(p - d2.xy) - d2.z; if (e < best) { best = e; dd = d2; } }
    if (3 < n) { float e = length(p - d3.xy) - d3.z; if (e < best) { best = e; dd = d3; } }
    if (4 < n) { float e = length(p - d4.xy) - d4.z; if (e < best) { best = e; dd = d4; } }
    if (5 < n) { float e = length(p - d5.xy) - d5.z; if (e < best) { best = e; dd = d5; } }
    if (6 < n) { float e = length(p - d6.xy) - d6.z; if (e < best) { best = e; dd = d6; } }
    if (7 < n) { float e = length(p - d7.xy) - d7.z; if (e < best) { best = e; dd = d7; } }
    if (8 < n) { float e = length(p - d8.xy) - d8.z; if (e < best) { best = e; dd = d8; } }
    if (9 < n) { float e = length(p - d9.xy) - d9.z; if (e < best) { best = e; dd = d9; } }
    if (10 < n) { float e = length(p - d10.xy) - d10.z; if (e < best) { best = e; dd = d10; } }
    if (11 < n) { float e = length(p - d11.xy) - d11.z; if (e < best) { best = e; dd = d11; } }
    if (12 < n) { float e = length(p - d12.xy) - d12.z; if (e < best) { best = e; dd = d12; } }
    if (13 < n) { float e = length(p - d13.xy) - d13.z; if (e < best) { best = e; dd = d13; } }
    if (14 < n) { float e = length(p - d14.xy) - d14.z; if (e < best) { best = e; dd = d14; } }
    if (15 < n) { float e = length(p - d15.xy) - d15.z; if (e < best) { best = e; dd = d15; } }
    if (16 < n) { float e = length(p - d16.xy) - d16.z; if (e < best) { best = e; dd = d16; } }
    if (17 < n) { float e = length(p - d17.xy) - d17.z; if (e < best) { best = e; dd = d17; } }
    if (18 < n) { float e = length(p - d18.xy) - d18.z; if (e < best) { best = e; dd = d18; } }
    if (19 < n) { float e = length(p - d19.xy) - d19.z; if (e < best) { best = e; dd = d19; } }
    if (20 < n) { float e = length(p - d20.xy) - d20.z; if (e < best) { best = e; dd = d20; } }
    if (21 < n) { float e = length(p - d21.xy) - d21.z; if (e < best) { best = e; dd = d21; } }
    if (22 < n) { float e = length(p - d22.xy) - d22.z; if (e < best) { best = e; dd = d22; } }
    if (23 < n) { float e = length(p - d23.xy) - d23.z; if (e < best) { best = e; dd = d23; } }
    if (24 < n) { float e = length(p - d24.xy) - d24.z; if (e < best) { best = e; dd = d24; } }
    if (25 < n) { float e = length(p - d25.xy) - d25.z; if (e < best) { best = e; dd = d25; } }
    if (26 < n) { float e = length(p - d26.xy) - d26.z; if (e < best) { best = e; dd = d26; } }
    if (27 < n) { float e = length(p - d27.xy) - d27.z; if (e < best) { best = e; dd = d27; } }
    if (28 < n) { float e = length(p - d28.xy) - d28.z; if (e < best) { best = e; dd = d28; } }
    if (29 < n) { float e = length(p - d29.xy) - d29.z; if (e < best) { best = e; dd = d29; } }
    if (30 < n) { float e = length(p - d30.xy) - d30.z; if (e < best) { best = e; dd = d30; } }
    if (31 < n) { float e = length(p - d31.xy) - d31.z; if (e < best) { best = e; dd = d31; } }
    if (32 < n) { float e = length(p - d32.xy) - d32.z; if (e < best) { best = e; dd = d32; } }
    if (33 < n) { float e = length(p - d33.xy) - d33.z; if (e < best) { best = e; dd = d33; } }
    if (34 < n) { float e = length(p - d34.xy) - d34.z; if (e < best) { best = e; dd = d34; } }
    if (35 < n) { float e = length(p - d35.xy) - d35.z; if (e < best) { best = e; dd = d35; } }
    if (36 < n) { float e = length(p - d36.xy) - d36.z; if (e < best) { best = e; dd = d36; } }
    if (37 < n) { float e = length(p - d37.xy) - d37.z; if (e < best) { best = e; dd = d37; } }
    if (38 < n) { float e = length(p - d38.xy) - d38.z; if (e < best) { best = e; dd = d38; } }
    if (39 < n) { float e = length(p - d39.xy) - d39.z; if (e < best) { best = e; dd = d39; } }
    if (best > 6.0) { fragColor = vec4(0.0); return; }

    bool  snow  = dd.w < 0.0;
    float alpha = abs(dd.w);
    float r     = dd.z;
    float cov   = clamp(0.5 - best, 0.0, 1.0);

    // soft contact shadow, slightly below the drop
    float sds    = length(p - dd.xy - vec2(0.0, 1.5)) - r;
    float shadow = 0.24 * (1.0 - smoothstep(-1.0, 4.5, sds));
    if (best > 1.0) { fragColor = vec4(0.0, 0.0, 0.0, shadow * alpha) * qt_Opacity; return; }

    vec2  q = p - dd.xy;
    float t = max(-best, 0.0);                         // distance to the edge, inside
    vec2  g = q / max(length(q), 1.0e-4);              // outward direction

    vec3 col;
    if (snow) {
        // frosted flake: bright, soft, hardly refracting
        float core = smoothstep(r, 0.0, length(q));
        col = mix(vec3(0.80, 0.86, 0.95), vec3(1.0), core) + backdrop(p) * 0.08;
        float hairS = exp(-t / 0.9);
        col += hairS * 0.18 * rim * vec3(1.0);
        float a = cov * alpha * (0.50 + 0.40 * core);
        fragColor = vec4(clamp(col, 0.0, 1.0) * a, a + shadow * alpha * (1.0 - cov) * 0.4) * qt_Opacity;
        return;
    }

    // ---- rain bead: a small glass lens -------------------------------------------------------------
    float bz   = max(r * 0.95, 1.0);
    float u    = clamp(t / bz, 0.0, 1.0);
    float om   = 1.0 - u;
    float om4  = om * om * om * om;
    float slope = (om * om * om) / pow(max(1.0 - om4, 1.0e-3), 0.75);
    slope = min(slope, 7.0);
    vec3 nrm = normalize(vec3(g * slope, 1.0));

    vec3 rd   = refract(vec3(0.0, 0.0, -1.0), nrm, 1.0 / 1.5);
    float th  = min(thickness, r * 1.15);              // the shift can never reach beyond the bead
    vec2 disp = rd.xy / max(-rd.z, 0.2) * th * 1.35;

    // a bead magnifies what is behind it: sample closer to its centre in the middle
    vec2 sp = dd.xy + q * mix(0.62, 1.0, smoothstep(0.0, 1.0, u * u));
    vec3 col3;
    col3.r = backdrop(sp + disp * (1.0 + dispersion * 0.6)).r;
    col3.g = backdrop(sp + disp).g;
    col3.b = backdrop(sp + disp * (1.0 - dispersion * 0.6)).b;
    col = col3;

    float l = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(l), col, saturation);
    vec3 tintC = mix(vec3(1.0), vec3(0.09, 0.09, 0.10), dark);
    col = mix(col, tintC, tintMix);
    col += mix(0.055, 0.020, dark);
    col *= 1.0 - 0.10 * exp(-t / (bz * 0.45));

    // specular rim (light from lightDir) and a small inner highlight like a real bead
    float facing = dot(g, lightDir);
    float spec   = pow(max(facing, 0.0), 1.6) + 0.55 * pow(max(-facing, 0.0), 2.2);
    float hair   = exp(-t / 0.9);
    float wide   = exp(-t / 2.4);
    float edgeHi = (hair * (0.20 + 0.80 * spec) + wide * 0.10 * (0.30 + spec)) * rim * mix(0.85, 1.0, dark);
    col += edgeHi * vec3(0.96, 0.98, 1.0);
    vec2  hp = (q - vec2(-0.30, -0.34) * r) / (r * 0.22);
    col += exp(-dot(hp, hp)) * 0.35 * rim * vec3(1.0);

    float a = cov * alpha;
    fragColor = vec4(clamp(col, 0.0, 1.0) * a, a + shadow * alpha * (1.0 - cov)) * qt_Opacity;     // premultiplied
}
