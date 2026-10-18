// Dominant colour of an image (album cover): saturation-weighted average of a 16x16 downscale,
// pulled into a readable lightness range. Used by the music widget when "Farben aus dem Albumcover" is on.
import QtQuick

Item {
    id: cc
    property url source: ""
    property bool lightBackground: false       // glass is light -> darker accent
    property color color: "#8ab4ff"
    property bool valid: false
    visible: false
    width: 0; height: 0

    Canvas {
        id: cv
        width: 16; height: 16
        renderTarget: Canvas.Image
        onImageLoaded: requestPaint()
        onPaint: {
            var src = String(cc.source);
            if (src === "" || !isImageLoaded(src)) return;
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, 16, 16);
            ctx.drawImage(src, 0, 0, 16, 16);
            var d = ctx.getImageData(0, 0, 16, 16).data, r = 0, g = 0, b = 0, wsum = 0;
            for (var i = 0; i < d.length; i += 4) {
                var mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2]);
                var w = 0.05 + (mx - mn) / 255;                   // colourful pixels count more than grey ones
                r += d[i] * w; g += d[i + 1] * w; b += d[i + 2] * w; wsum += w;
            }
            if (wsum <= 0) { cc.valid = false; return; }
            var c = Qt.rgba(r / wsum / 255, g / wsum / 255, b / wsum / 255, 1);
            var h = c.hslHue < 0 ? 0 : c.hslHue, s = Math.max(c.hslSaturation, 0.45);
            var l = cc.lightBackground ? Math.min(0.40, Math.max(0.25, c.hslLightness)) : Math.max(0.62, Math.min(0.80, c.hslLightness + 0.2));
            cc.color = Qt.hsla(h, s, l, 1);
            cc.valid = true;
        }
    }
    onSourceChanged: { valid = false; if (String(source) !== "") cv.loadImage(String(source)); }
    Component.onCompleted: if (String(source) !== "") cv.loadImage(String(source))
}
