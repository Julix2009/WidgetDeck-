.pragma library
// Style model shared by the desktop widgets and the builder.
// The same keys are stored in widgets.json (style: {...}); anything missing falls back to these defaults.

var MODES = [["frosted", "Frosted Glass"], ["liquid", "Liquid Glass"]];

// kind: color | range | int | bool | font | choice   (only: show the control only for that glass mode)
// Liquid defaults are the look of the MacShell widget layer the shader is derived from (see LIQUID_DEFAULTS); the sliders only offset from it.
var STYLE_PROPS = [
    { key: "mode",         label: "Glass style",             kind: "choice", def: "frosted", options: MODES },
    { key: "bg",           label: "Background tint",      kind: "color",  def: "theme:surface", only: "frosted" },
    { key: "border_color", label: "Border colour",           kind: "color",  def: "theme:outline", only: "frosted" },
    { key: "bg_alpha",     label: "Opacity",             kind: "range",  def: 0.55, min: 0,   max: 1,   step: 0.01 },
    { key: "refraction",   label: "Refraction",       kind: "range",  def: 1.0,  min: 0,   max: 2,   step: 0.01, only: "liquid" },
    { key: "bezel",        label: "Edge thickness",            kind: "range",  def: 1.0,  min: 0.3, max: 2,   step: 0.01, only: "liquid" },
    { key: "aberration",   label: "Colour fringe",              kind: "range",  def: 1.0,  min: 0,   max: 3,   step: 0.01, only: "liquid" },
    { key: "blur",         label: "Blur (px)",             kind: "range",  def: 16,   min: 0,   max: 48,  step: 1,    only: "liquid" },
    { key: "saturation",   label: "Saturation",             kind: "range",  def: 1.25, min: 1,   max: 2,   step: 0.01, only: "liquid" },
    { key: "highlight",    label: "Highlight strength",      kind: "range",  def: 0.45, min: 0,   max: 1.5, step: 0.01, only: "liquid" },
    { key: "light_angle",  label: "Light angle (°)",       kind: "range",  def: 236.46, min: 0, max: 359, step: 1,    only: "liquid" },
    { key: "grain",        label: "Grain",               kind: "range",  def: 0.03, min: 0,   max: 0.15, step: 0.005, only: "liquid" },
    { key: "dark",         label: "Glass light/dark",      kind: "choice", def: "auto", only: "liquid", options: [["auto", "Auto (theme)"], ["dark", "Dark"], ["light", "Light"]] },
    { key: "tint_color",   label: "Theme tint: colour",     kind: "color",  def: "theme:primary_container", only: "liquid" },
    { key: "theme_tint",   label: "Theme tint: amount",    kind: "range",  def: 0.20, min: 0, max: 1, step: 0.01, only: "liquid" },
    { key: "light_follow", label: "Highlight follows the mouse",  kind: "bool",   def: false, only: "liquid" },
    { key: "hover_on",     label: "Hover effect",          kind: "bool",   def: true, only: "liquid" },
    { key: "hover_strength", label: "Hover strength",        kind: "range",  def: 1.0,  min: 0, max: 2, step: 0.05, only: "liquid" },
    { key: "hover_duration", label: "Hover duration (ms)",    kind: "range",  def: 440,  min: 150, max: 900, step: 10, only: "liquid" },
    { key: "merge",        label: "Merge (px)",    kind: "range",  def: 0,    min: 0,   max: 40,  step: 1,    only: "liquid" },
    { key: "fg",           label: "Text colour",             kind: "color",  def: "theme:on_surface" },
    { key: "accent",       label: "Accent colour",           kind: "color",  def: "theme:primary" },
    { key: "font",         label: "Font",            kind: "font",   def: "" },
    { key: "font_size",    label: "Font size",          kind: "int",    def: 16,   min: 8,   max: 64,  step: 1 },
    { key: "radius",       label: "Corner radius",           kind: "int",    def: 24,   min: 0,   max: 80,  step: 1 },
    { key: "border_alpha", label: "Border",                kind: "range",  def: 0.14, min: 0,   max: 0.6, step: 0.01, only: "frosted" },
    { key: "shadow",       label: "Shadow",              kind: "range",  def: 0.35, min: 0,   max: 1.5, step: 0.01 },
    { key: "glass",        label: "Glass shine",            kind: "bool",   def: true, only: "frosted" }
];

// The default look: tint 0.42, blur 16 px, rim 0.45, grain 0.03, shadow 1, corner radius ~29.8 px, light from the top left
// (the values of MacShell's widget layer, which the shader is derived from).
var LIQUID_DEFAULTS = {
    bg_alpha: 0.42, refraction: 1.0, bezel: 1.0, aberration: 1.0, blur: 16, saturation: 1.25, highlight: 0.45,
    light_angle: 236.46, grain: 0.03, dark: "auto", light_follow: false, merge: 0, shadow: 1.0, radius: 29.77,
    tint_color: "theme:primary_container", theme_tint: 0.20
};

var LIQUID_PRESETS = {
    // "Pearl" = the default look
    "Pearl":  { bg_alpha: 0.42, refraction: 1.0, bezel: 1.0, aberration: 1.0, blur: 16, saturation: 1.25, highlight: 0.45, grain: 0.03, shadow: 1.0, light_angle: 236.46 },
    "Clear":   { bg_alpha: 0.18, refraction: 1.3, bezel: 1.0, aberration: 1.3, blur: 6,  saturation: 1.20, highlight: 0.60, grain: 0.03, shadow: 0.8, light_angle: 236.46 },
    "Subtle": { bg_alpha: 0.75, refraction: 0.6, bezel: 0.8, aberration: 0.6, blur: 24, saturation: 1.15, highlight: 0.35, grain: 0.03, shadow: 0.8, light_angle: 236.46 }
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
