.pragma library
// Coordinates typed by the user. Decimal point or decimal comma; anything else (also an empty text) or out of range -> NaN.
// The shell scripts use the same rules (sysmon/common.sh: coord).
function parseCoord(text, max) {
    var s = String(text === undefined || text === null ? "" : text).trim();
    if (!/^[+-]?\d+([.,]\d+)?$/.test(s)) return NaN;
    var n = Number(s.replace(",", "."));
    return Math.abs(n) <= max ? n : NaN;
}
