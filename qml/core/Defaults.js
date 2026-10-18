.pragma library
// Style model shared by the desktop widgets and the builder.
// The same keys are stored in widgets.json (style: {...}); anything missing falls back to these defaults.

var MODES = [["frosted", "Frosted Glass"], ["liquid", "Liquid Glass"]];

// kind: color | range | int | bool | font | choice   (only: show the control only for that glass mode)
// Liquid defaults are the look of the MacShell widget layer the shader is derived from (see LIQUID_DEFAULTS); the sliders only offset from it.
var STYLE_PROPS = [
    { key: "mode",         label: "Glas-Stil",             kind: "choice", def: "frosted", options: MODES },
    { key: "bg",           label: "Hintergrund-Tint",      kind: "color",  def: "theme:surface", only: "frosted" },
    { key: "border_color", label: "Rahmenfarbe",           kind: "color",  def: "theme:outline", only: "frosted" },
    { key: "bg_alpha",     label: "Deckkraft",             kind: "range",  def: 0.55, min: 0,   max: 1,   step: 0.01 },
    { key: "refraction",   label: "Brechungsstärke",       kind: "range",  def: 1.0,  min: 0,   max: 2,   step: 0.01, only: "liquid" },
    { key: "bezel",        label: "Rand-Dicke",            kind: "range",  def: 1.0,  min: 0.3, max: 2,   step: 0.01, only: "liquid" },
    { key: "aberration",   label: "Farbsaum",              kind: "range",  def: 1.0,  min: 0,   max: 3,   step: 0.01, only: "liquid" },
    { key: "blur",         label: "Blur (px)",             kind: "range",  def: 16,   min: 0,   max: 48,  step: 1,    only: "liquid" },
    { key: "saturation",   label: "Sättigung",             kind: "range",  def: 1.25, min: 1,   max: 2,   step: 0.01, only: "liquid" },
    { key: "highlight",    label: "Highlight-Stärke",      kind: "range",  def: 0.45, min: 0,   max: 1.5, step: 0.01, only: "liquid" },
    { key: "light_angle",  label: "Lichtwinkel (°)",       kind: "range",  def: 236.46, min: 0, max: 359, step: 1,    only: "liquid" },
    { key: "grain",        label: "Körnung",               kind: "range",  def: 0.03, min: 0,   max: 0.15, step: 0.005, only: "liquid" },
    { key: "dark",         label: "Glas hell/dunkel",      kind: "choice", def: "auto", only: "liquid", options: [["auto", "Auto (Theme)"], ["dark", "Dunkel"], ["light", "Hell"]] },
    { key: "tint_color",   label: "Theme-Tint: Farbe",     kind: "color",  def: "theme:primary_container", only: "liquid" },
    { key: "theme_tint",   label: "Theme-Tint: Anteil",    kind: "range",  def: 0.20, min: 0, max: 1, step: 0.01, only: "liquid" },
    { key: "light_follow", label: "Highlight folgt Maus",  kind: "bool",   def: false, only: "liquid" },
    { key: "hover_on",     label: "Hover-Effekt",          kind: "bool",   def: true, only: "liquid" },
    { key: "hover_strength", label: "Hover-Stärke",        kind: "range",  def: 1.0,  min: 0, max: 2, step: 0.05, only: "liquid" },
    { key: "hover_duration", label: "Hover-Dauer (ms)",    kind: "range",  def: 440,  min: 150, max: 900, step: 10, only: "liquid" },
    { key: "merge",        label: "Verschmelzung (px)",    kind: "range",  def: 0,    min: 0,   max: 40,  step: 1,    only: "liquid" },
    { key: "fg",           label: "Textfarbe",             kind: "color",  def: "theme:on_surface" },
    { key: "accent",       label: "Akzentfarbe",           kind: "color",  def: "theme:primary" },
    { key: "font",         label: "Schriftart",            kind: "font",   def: "Adwaita Sans" },
    { key: "font_size",    label: "Schriftgröße",          kind: "int",    def: 16,   min: 8,   max: 64,  step: 1 },
    { key: "radius",       label: "Eckenradius",           kind: "int",    def: 24,   min: 0,   max: 80,  step: 1 },
    { key: "border_alpha", label: "Rahmen",                kind: "range",  def: 0.14, min: 0,   max: 0.6, step: 0.01, only: "frosted" },
    { key: "shadow",       label: "Schatten",              kind: "range",  def: 0.35, min: 0,   max: 1.5, step: 0.01 },
    { key: "glass",        label: "Glas-Glanz",            kind: "bool",   def: true, only: "frosted" }
];

// The default look: tint 0.42, blur 16 px, rim 0.45, grain 0.03, shadow 1, corner radius ~29.8 px, light from the top left
// (the values of MacShell's widget layer, which the shader is derived from).
var LIQUID_DEFAULTS = {
    bg_alpha: 0.42, refraction: 1.0, bezel: 1.0, aberration: 1.0, blur: 16, saturation: 1.25, highlight: 0.45,
    light_angle: 236.46, grain: 0.03, dark: "auto", light_follow: false, merge: 0, shadow: 1.0, radius: 29.77,
    tint_color: "theme:primary_container", theme_tint: 0.20
};

var LIQUID_PRESETS = {
    // "Perle" = the default look
    "Perle":  { bg_alpha: 0.42, refraction: 1.0, bezel: 1.0, aberration: 1.0, blur: 16, saturation: 1.25, highlight: 0.45, grain: 0.03, shadow: 1.0, light_angle: 236.46 },
    "Klar":   { bg_alpha: 0.18, refraction: 1.3, bezel: 1.0, aberration: 1.3, blur: 6,  saturation: 1.20, highlight: 0.60, grain: 0.03, shadow: 0.8, light_angle: 236.46 },
    "Dezent": { bg_alpha: 0.75, refraction: 0.6, bezel: 0.8, aberration: 0.6, blur: 24, saturation: 1.15, highlight: 0.35, grain: 0.03, shadow: 0.8, light_angle: 236.46 }
};

// applied when the glass mode of a widget is switched
var MODE_PRESETS = {
    frosted: { bg_alpha: 0.55, radius: 24, border_alpha: 0.14, shadow: 0.35, glass: true },
    liquid:  Object.assign({}, LIQUID_DEFAULTS)
};

var BUILDER_DEFAULT = { glass: "frosted", opacity: 0.78, liveCapture: false,
                        themeEnabled: true, themeMode: "dark", themeScheme: "scheme-tonal-spot" };
var SCHEMES = [["scheme-tonal-spot", "Tonal Spot"], ["scheme-vibrant", "Vibrant"], ["scheme-expressive", "Expressive"], ["scheme-content", "Content"],
               ["scheme-monochrome", "Monochrome"], ["scheme-fidelity", "Fidelity"], ["scheme-fruit-salad", "Fruit Salad"],
               ["scheme-neutral", "Neutral"], ["scheme-rainbow", "Rainbow"]];

function styleDefaults() {
    var d = {};
    for (var i = 0; i < STYLE_PROPS.length; i++) d[STYLE_PROPS[i].key] = STYLE_PROPS[i].def;
    return d;
}
function resolveStyle(partial, typeDefaults) {
    var d = styleDefaults(), k, mode = (partial && partial.mode) || (typeDefaults && typeDefaults.mode) || d.mode;
    if (mode === "liquid") for (k in LIQUID_DEFAULTS) d[k] = LIQUID_DEFAULTS[k];     // per-mode defaults for missing keys
    if (typeDefaults && mode !== "liquid") for (k in typeDefaults) d[k] = typeDefaults[k];   // type tweaks are for the frosted look
    if (partial) for (k in partial) d[k] = partial[k];
    return d;
}
function hexRgb(h) {
    h = String(h || "#ffffff").replace("#", "");
    return [parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255];
}
