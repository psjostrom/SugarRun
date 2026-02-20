import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;

module GraphRenderer {

    const DOT_RADIUS_LARGE = 4;
    const DOT_RADIUS_SMALL = 2;
    const LINE_WIDTH = 2;

    // Draw a BG graph in the given rectangle.
    // history: Array of {:bg => Float (mmol), :time => Long (unix ms)}, newest first.
    // durationMin: time window in minutes.
    function draw(dc as Dc, x as Number, y as Number, w as Number, h as Number,
                  history as Array, durationMin as Number,
                  bgLow as Float, bgHigh as Float) as Void {
        // Black background
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(x, y, w, h);

        // Auto-scale Y range from data with padding, always include ref lines
        var yMin = bgLow - 0.5f;   // at least show low line
        var yMax = bgHigh + 0.5f;   // at least show high line
        for (var i = 0; i < history.size(); i++) {
            var bg = (history[i] as Dictionary)[:bg] as Float;
            if (bg > 0.0f) {
                if (bg < yMin) { yMin = bg - 0.5f; }
                if (bg > yMax) { yMax = bg + 0.5f; }
            }
        }
        // Floor/ceil to whole numbers for clean bounds
        yMin = (yMin.toNumber()).toFloat();
        if (yMin < Conversions.GRAPH_Y_MIN) { yMin = Conversions.GRAPH_Y_MIN; }
        yMax = (yMax.toNumber() + 1).toFloat();
        if (yMax > Conversions.GRAPH_Y_MAX) { yMax = Conversions.GRAPH_Y_MAX; }
        var yRange = yMax - yMin;

        // Draw low zone fill (below low threshold)
        var lowLineY = mmolToPixelY(bgLow, y, h, yMin, yRange);
        dc.setColor(Conversions.COLOR_GRAPH_LOW_ZONE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, lowLineY, w, y + h - lowLineY);

        // Draw reference lines
        dc.setPenWidth(1);
        dc.setColor(Conversions.COLOR_LOW, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, lowLineY, x + w, lowLineY, 6, 4);

        var highLineY = mmolToPixelY(bgHigh, y, h, yMin, yRange);
        dc.setColor(Conversions.COLOR_GRAPH_HIGH_LINE, Graphics.COLOR_TRANSPARENT);
        drawDashedLine(dc, x, highLineY, x + w, highLineY, 6, 4);

        // Filter history to time window
        if (history.size() == 0) {
            return;
        }

        var newestTime = (history[0] as Dictionary)[:time] as Long;
        var durationMs = durationMin.toLong() * 60000l;
        var oldestTime = newestTime - durationMs;

        // Collect visible points (convert to pixel coords), oldest first for drawing
        var points = [] as Array;
        for (var i = history.size() - 1; i >= 0; i--) {
            var entry = history[i] as Dictionary;
            var t = entry[:time] as Long;
            if (t < oldestTime) {
                continue;
            }
            var bg = entry[:bg] as Float;
            var px = timeToPixelX(t, x, w, newestTime, durationMs);
            var py = mmolToPixelY(bg, y, h, yMin, yRange);
            points.add({:px => px, :py => py, :bg => bg});
        }

        if (points.size() == 0) {
            return;
        }

        // Draw connecting lines (gray)
        dc.setPenWidth(LINE_WIDTH);
        dc.setColor(Conversions.COLOR_GRAPH_LINE, Graphics.COLOR_TRANSPARENT);
        for (var i = 1; i < points.size(); i++) {
            var prev = points[i - 1] as Dictionary;
            var curr = points[i] as Dictionary;
            dc.drawLine(
                prev[:px] as Number, prev[:py] as Number,
                curr[:px] as Number, curr[:py] as Number
            );
        }
        dc.setPenWidth(1);

        // Draw colored dots (scale radius for small fields)
        var dotR = (h > 150) ? DOT_RADIUS_LARGE : DOT_RADIUS_SMALL;
        for (var i = 0; i < points.size(); i++) {
            var pt = points[i] as Dictionary;
            var bg = pt[:bg] as Float;
            var dotColor = Conversions.graphDotColor(bg, bgLow, bgHigh);
            dc.setColor(dotColor, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(pt[:px] as Number, pt[:py] as Number, dotR);
        }
    }

    function mmolToPixelY(mmol as Float, areaY as Number, areaH as Number,
                                  yMin as Float, yRange as Float) as Number {
        var ratio = (mmol - yMin) / yRange;
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
        return (areaY + areaH - (ratio * areaH)).toNumber();
    }

    function timeToPixelX(time as Long, areaX as Number, areaW as Number,
                                  newestTime as Long, durationMs as Long) as Number {
        var elapsed = newestTime - time;
        if (elapsed < 0) { elapsed = 0l; }
        var ratio = 1.0f - (elapsed.toFloat() / durationMs.toFloat());
        if (ratio < 0.0f) { ratio = 0.0f; }
        if (ratio > 1.0f) { ratio = 1.0f; }
        return (areaX + ratio * areaW).toNumber();
    }

    function drawDashedLine(dc as Dc, x1 as Number, y1 as Number,
                                    x2 as Number, y2 as Number,
                                    dashLen as Number, gapLen as Number) as Void {
        var dx = x2 - x1;
        var dy = y2 - y1;
        var len = Toybox.Math.sqrt((dx * dx + dy * dy).toFloat()).toNumber();
        if (len == 0) { return; }

        var ndx = dx.toFloat() / len;
        var ndy = dy.toFloat() / len;
        var pos = 0;
        var drawing = true;

        while (pos < len) {
            var segLen = drawing ? dashLen : gapLen;
            if (pos + segLen > len) {
                segLen = len - pos;
            }
            if (drawing) {
                var sx = (x1 + ndx * pos).toNumber();
                var sy = (y1 + ndy * pos).toNumber();
                var ex = (x1 + ndx * (pos + segLen)).toNumber();
                var ey = (y1 + ndy * (pos + segLen)).toNumber();
                dc.drawLine(sx, sy, ex, ey);
            }
            pos += segLen;
            drawing = !drawing;
        }
    }
}
