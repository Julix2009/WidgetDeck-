// Soft 3D objects for the weather icons: a small signed-distance-field ray marcher (orthographic, one ray per pixel).
// Objects are unions of rounded capsules / spheres with a smooth blend (soft, clay-like volume), minus optional spheres (moon crescent, craters).
// Lighting: soft key light from the top left, wrapped diffuse, cool shade colour in the dark half, a warm bounce from below right,
// ambient occlusion from the distance field, a small specular highlight and a faint rim. Output = premultiplied colour with an
// anti-aliased silhouette. This shader only runs inside tools/weather-icons/render.sh (offline); the widget uses the baked PNG sprites.
// Written for this project (own code, MIT).
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 a0;
    vec4 a1;
    vec4 a2;
    vec4 a3;
    vec4 a4;
    vec4 a5;
    vec4 a6;
    vec4 a7;
    vec4 a8;
    vec4 a9;
    vec4 a10;
    vec4 a11;
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 b4;
    vec4 b5;
    vec4 b6;
    vec4 b7;
    vec4 b8;
    vec4 b9;
    vec4 b10;
    vec4 b11;
    vec4 s0;
    vec4 s1;
    vec4 s2;
    vec4 s3;
    vec4 s4;
    vec4 s5;
    vec4 s6;
    vec4 s7;
    vec4 baseColor;
    vec4 shadeColor;
    vec4 hiColor;
    float k;        // smooth-union radius
    float gloss;    // strength of the specular highlight
    float occl;     // ambient occlusion strength
    float px;       // size of one pixel in object units
    float nCap;
    float nSub;
};

vec4 getA(int i) {
    if (i == 0) return a0;
    if (i == 1) return a1;
    if (i == 2) return a2;
    if (i == 3) return a3;
    if (i == 4) return a4;
    if (i == 5) return a5;
    if (i == 6) return a6;
    if (i == 7) return a7;
    if (i == 8) return a8;
    if (i == 9) return a9;
    if (i == 10) return a10;
    if (i == 11) return a11;
    return vec4(0.0);
}

vec4 getB(int i) {
    if (i == 0) return b0;
    if (i == 1) return b1;
    if (i == 2) return b2;
    if (i == 3) return b3;
    if (i == 4) return b4;
    if (i == 5) return b5;
    if (i == 6) return b6;
    if (i == 7) return b7;
    if (i == 8) return b8;
    if (i == 9) return b9;
    if (i == 10) return b10;
    if (i == 11) return b11;
    return vec4(0.0);
}

vec4 getS(int i) {
    if (i == 0) return s0;
    if (i == 1) return s1;
    if (i == 2) return s2;
    if (i == 3) return s3;
    if (i == 4) return s4;
    if (i == 5) return s5;
    if (i == 6) return s6;
    if (i == 7) return s7;
    return vec4(0.0);
}

float sdCap(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h) - r;
}
float smin(float a, float b, float kk) { float h = max(kk - abs(a - b), 0.0) / kk; return min(a, b) - h * h * kk * 0.25; }
float smax(float a, float b, float kk) { return -smin(-a, -b, kk); }

float map(vec3 p) {
    float d = 1e5;
    for (int i = 0; i < 12; i++) {
        if (float(i) >= nCap) break;
        vec4 A = getA(i); vec4 B = getB(i);
        float e = sdCap(p, A.xyz, B.xyz, A.w);
        d = (i == 0) ? e : smin(d, e, max(k, 1e-3));
    }
    for (int j = 0; j < 8; j++) {
        if (float(j) >= nSub) break;
        vec4 S = getS(j);
        d = smax(d, -(length(p - S.xyz) - S.w), max(k * 0.5, 1e-3));
    }
    return d;
}
vec3 calcNormal(vec3 p) {
    const vec2 e = vec2(0.0025, 0.0);
    return normalize(vec3(map(p + e.xyy) - map(p - e.xyy), map(p + e.yxy) - map(p - e.yxy), map(p + e.yyx) - map(p - e.yyx)));
}
float calcAO(vec3 p, vec3 n) {
    float o = 0.0, w = 1.0;
    for (int i = 1; i <= 5; i++) { float h = 0.035 * float(i); o += (h - max(map(p + n * h), 0.0)) * w; w *= 0.72; }
    return clamp(1.0 - 2.4 * o, 0.0, 1.0);
}

void main() {
    vec2 uv = (qt_TexCoord0 * 2.0 - 1.0) * vec2(1.0, -1.0);          // -1..1, y up
    vec3 ro = vec3(uv, 2.0), rd = vec3(0.0, 0.0, -1.0);
    float t = 0.0, dmin = 1e5; vec3 pmin = ro;
    for (int i = 0; i < 80; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if (d < dmin) { dmin = d; pmin = p; }
        if (d < 0.0004 || t > 4.0) break;
        t += max(d, 0.0006);
    }
    float alpha = 1.0 - smoothstep(0.35 * px, 1.15 * px, dmin);
    if (alpha <= 0.0) { fragColor = vec4(0.0); return; }
    vec3 n = calcNormal(pmin);
    pmin -= n * map(pmin);                       // put the point exactly on the surface (no banding in the occlusion)
    n = calcNormal(pmin);
    vec3 L = normalize(vec3(-0.55, 0.65, 0.62));
    vec3 V = vec3(0.0, 0.0, 1.0);
    float ndl = dot(n, L);
    float diff = clamp(ndl * 0.5 + 0.5, 0.0, 1.0); diff = diff * diff * (3.0 - 2.0 * diff);
    vec3 col = mix(shadeColor.rgb, baseColor.rgb, diff);
    float ao = calcAO(pmin, n);
    col *= mix(1.0 - 0.45 * occl, 1.0, ao);
    col += shadeColor.rgb * 0.16 * max(dot(n, normalize(vec3(0.55, -0.7, 0.3))), 0.0);     // warm / cool bounce from below right
    vec3 H = normalize(L + V);
    float spec = pow(max(dot(n, H), 0.0), 60.0) * gloss;
    float spot = smoothstep(0.82, 0.96, dot(n, normalize(vec3(-0.45, 0.55, 0.7)))) * gloss * 0.55;     // the small round gloss point
    col += hiColor.rgb * (spec * 0.7 + spot);
    col += hiColor.rgb * pow(1.0 - max(dot(n, V), 0.0), 3.0) * 0.16;
    col = clamp(col, 0.0, 1.0);
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
