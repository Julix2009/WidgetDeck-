// Base of the GitHub widget: the usual widget properties and one data feed per user name (github.py), so
// several instances make one request.
import QtQuick
import QtQuick.Window
import "../../core"

Item {
    id: w
    property var style: ({})
    property var props: ({})
    property real innerRadius: 8
    property var palette: ({})

    readonly property real fs: style.font_size || 16
    function s(v) { return v * fs / 16; }
    readonly property color cFg: style.fg || "#f2f4f8"
    readonly property color cAcc: style.accent || "#8ab4ff"
    readonly property bool live: Window.window !== null && Window.window.visible
    // one name for all GitHub widgets: config.json "github_user" (builder: Settings); props.user is only for previews ("demo")
    property int configRev: 0
    property var appConfig: ({})
    readonly property string user: String(props.user || (appConfig && appConfig.github_user) || "").trim().replace(/^@/, "")
    readonly property string dir: decodeURIComponent(Qt.resolvedUrl("./").toString().replace("file://", ""))

    property var d: null
    readonly property bool has: d !== null && d.state === "ok"
    readonly property string problem: d === null ? I18n.tr("Loading …")
        : d.state === "ok" ? ""
        : d.error === "nouser" ? I18n.tr("Enter your GitHub user name in the settings.")
        : d.error === "notfound" ? I18n.tr("This GitHub user does not exist.")
        : d.error === "ratelimit" ? I18n.tr("GitHub limit reached, trying again later.")
        : I18n.tr("GitHub is not reachable.")
    function num(v) { return v === null || v === undefined ? "–" : Number(v).toLocaleString(Qt.locale(I18n.lang), "f", 0); }

    onUserChanged: d = null
    Feed {
        key: "github:" + w.user
        command: ["python3", "-I", w.dir + "github.py", w.user]
        interval: 600000                       // the helper answers from its cache for 30 minutes
        active: w.live
        onGot: text => { try { var o = JSON.parse(text); if (o && o.state) w.d = o; } catch (e) { } }
    }

    GText {
        visible: !w.has
        anchors.centerIn: parent; width: parent.width - w.s(32)
        horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        wstyle: w.style; opacity: 0.8; font.pixelSize: w.s(13); text: w.problem
    }
}
