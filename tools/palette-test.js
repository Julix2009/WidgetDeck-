// node tools/palette-test.js: the colour file formats of core/Palette.js
const fs = require("fs"), path = require("path"), vm = require("vm");
const ctx = {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(__dirname, "../qml/core/Palette.js"), "utf8").replace(".pragma library", ""), ctx);
let bad = 0;
function check(name, ok) { if (!ok) bad++; console.log((ok ? "ok   " : "FAIL ") + name); }
const roles = Object.keys(ctx.fromSeed("#3366cc", "dark"));
const full = (o) => !!o && roles.every((r) => /^#[0-9a-f]{6}$/.test(o[r]));
const p = (o, m) => ctx.parse(o, m || "dark");
check("flat roles", p({ primary: "#a2b0e0", surface: "#19191f" }).primary === "#a2b0e0" && full(p({ primary: "#a2b0e0", surface: "#19191f" })));
check("m-prefix camelCase", p({ mPrimary: "#ff8800", mSurface: "#101010", mOnSurface: "#eeeeee" }).on_surface === "#eeeeee");
check("nested colours without #", p({ colours: { primary: "88c0d0", surface: "2e3440" } }).primary === "#88c0d0");
check("dark / light blocks", p({ colors: { dark: { primary: "#111111", surface: "#000000" }, light: { primary: "#222222", surface: "#ffffff" } } }, "light").primary === "#222222");
check("pywal", p({ special: { background: "#101216", foreground: "#e0e0e0" }, colors: { color0: "#101216", color4: "#5588ff", color7: "#cccccc" } }).primary === "#5588ff");
check("catppuccin", p({ base: "#1e1e2e", text: "#cdd6f4", blue: "#89b4fa" }).on_surface === "#cdd6f4");
check("dark file, light mode", full(p({ primary: "#a2b0e0", surface: "#19191f" }, "light")) && p({ primary: "#a2b0e0", surface: "#19191f" }, "light").surface !== "#19191f");
check("not a colour file", p({ a: 1 }) === null && p(null) === null);
check("from the wallpaper", full(ctx.fromColors(["#202020", "#c0392b", "#f0f0f0"], "dark")) && full(ctx.fromColors(["#808080"], "light")));
check("no colours", ctx.fromColors([], "dark") === null);
console.log(bad ? bad + " FAILED" : "ALL OK");
process.exit(bad ? 1 : 0);
