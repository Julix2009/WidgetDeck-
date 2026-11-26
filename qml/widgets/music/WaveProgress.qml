// Progress as a line: the part already played is a wave, the rest is straight; a round head marks "now".
import QtQuick

Canvas {
    id: v
    property real value: 0                    // 0..1
    property color played: "#8ab4ff"
    property color rest: "#40ffffff"
    property real thickness: 3
    onValueChanged: requestPaint()
    onPlayedChanged: requestPaint()
    onRestChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var c = getContext("2d"); c.reset();
        var mid = height / 2, x1 = Math.max(thickness, Math.min(width - thickness, value * width)), amp = Math.max(1, height / 2 - thickness), len = Math.max(14, height * 1.6);
        c.lineWidth = thickness; c.lineCap = "round"; c.lineJoin = "round";
        c.strokeStyle = rest; c.beginPath(); c.moveTo(x1, mid); c.lineTo(width - thickness / 2, mid); c.stroke();
        c.strokeStyle = played; c.beginPath(); c.moveTo(thickness / 2, mid);
        for (var x = thickness / 2; x <= x1; x += 2) c.lineTo(x, mid + Math.sin(x / len * 2 * Math.PI) * amp * Math.min(1, (x1 - x) / len + 0.25));
        c.lineTo(x1, mid); c.stroke();
        c.fillStyle = played; c.beginPath(); c.arc(x1, mid, thickness * 1.5, 0, 2 * Math.PI); c.fill();
    }
}
