// UI texts: English is the source language (the English text IS the key); German comes from i18n.js.
//   I18n.tr("Show grid")   I18n.trf("%1 of %2", a, b)
// Language = config.json "language" ("auto" = system language from LC_ALL / LC_MESSAGES / LANG, else English).
pragma Singleton
import QtQuick
import Quickshell
import "i18n.js" as T

QtObject {
    id: i18n
    property string setting: "auto"
    readonly property string system: {
        var e = Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "";
        var l = String(e).substring(0, 2).toLowerCase();
        return T.LANGS.indexOf(l) >= 0 ? l : "en";
    }
    readonly property string lang: T.LANGS.indexOf(setting) >= 0 ? setting : system
    function tr(s) {
        if (lang === "en") return s;
        var d = T.TABLES[lang];
        var v = d ? d[s] : undefined;
        return v !== undefined ? v : s;
    }
    function trf(s) {
        var r = tr(s);
        for (var i = 1; i < arguments.length; i++) r = r.split("%" + i).join(String(arguments[i]));
        return r;
    }
}
