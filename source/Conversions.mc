import Toybox.Graphics;
import Toybox.Lang;

module Conversions {

    enum Direction {
        DIRECTION_NONE = 0,
        DIRECTION_DOUBLE_UP = 1,
        DIRECTION_SINGLE_UP = 2,
        DIRECTION_FORTY_FIVE_UP = 3,
        DIRECTION_FLAT = 4,
        DIRECTION_FORTY_FIVE_DOWN = 5,
        DIRECTION_SINGLE_DOWN = 6,
        DIRECTION_DOUBLE_DOWN = 7
    }

    enum DisplayMode {
        MODE_COMBINED = 0,
        MODE_BG = 1,
        MODE_ARROW = 2,
        MODE_DELTA = 3,
        MODE_TIME_SINCE = 4,
        MODE_GRAPH = 5
    }

    const BG_LOW = 4.0f;
    const BG_HIGH = 10.0f;
    const GRAPH_Y_MIN = 2.0f;
    const GRAPH_Y_MAX = 20.0f;
    const MGDL_TO_MMOL = 18.018f;
    const STALE_MINUTES = 10;
    const GARMIN_EPOCH_OFFSET = 631065600;

    // All colors chosen for max visibility on black AMOLED while running.
    // Luminance priority: low BG (critical) must pop hardest.
    const COLOR_IN_RANGE = 0x55FF55;    // soft green — easy on eyes, high luminance
    const COLOR_HIGH = 0xFFDD00;        // warm yellow — very bright
    const COLOR_LOW = 0xFF5555;         // bright red — 2x luminance vs pure red
    const COLOR_GRAPH_LINE = 0x888888;  // mid gray — visible but not distracting
    const COLOR_GRAPH_DOT_IN_RANGE = 0x00CCFF; // bright cyan — pops on black
    const COLOR_GRAPH_DOT_HIGH = 0xFFAA00;     // orange — distinct from yellow
    const COLOR_GRAPH_DOT_LOW = 0xFF5555;      // bright red — matches text color
    const COLOR_GRAPH_LOW_ZONE = 0x441111;     // dark maroon — visible but subtle
    const COLOR_GRAPH_HIGH_LINE = 0xFFAA00;    // orange
    const COLOR_STALE = 0xFF5555;              // bright red — matches low alert
    const COLOR_STALE_WARNING = 0xFFAA00;     // amber — distinct from BG yellow

    function mgdlToMmol(mgdl as Float) as Float {
        return mgdl / MGDL_TO_MMOL;
    }

    function directionFromString(dir as String?) as Direction {
        if (dir == null) { return DIRECTION_NONE; }
        if (dir.equals("DoubleUp")) { return DIRECTION_DOUBLE_UP; }
        if (dir.equals("SingleUp")) { return DIRECTION_SINGLE_UP; }
        if (dir.equals("FortyFiveUp")) { return DIRECTION_FORTY_FIVE_UP; }
        if (dir.equals("Flat")) { return DIRECTION_FLAT; }
        if (dir.equals("FortyFiveDown")) { return DIRECTION_FORTY_FIVE_DOWN; }
        if (dir.equals("SingleDown")) { return DIRECTION_SINGLE_DOWN; }
        if (dir.equals("DoubleDown")) { return DIRECTION_DOUBLE_DOWN; }
        return DIRECTION_NONE;
    }

    // Derive trend direction from computed delta (mg/dL per 5 min).
    function directionFromDelta(deltaMgdl as Float) as Direction {
        if (deltaMgdl <= -17.5f) { return DIRECTION_DOUBLE_DOWN; }
        if (deltaMgdl <= -10.0f) { return DIRECTION_SINGLE_DOWN; }
        if (deltaMgdl <= -5.0f) { return DIRECTION_FORTY_FIVE_DOWN; }
        if (deltaMgdl <= 5.0f) { return DIRECTION_FLAT; }
        if (deltaMgdl <= 10.0f) { return DIRECTION_FORTY_FIVE_UP; }
        if (deltaMgdl <= 17.5f) { return DIRECTION_SINGLE_UP; }
        return DIRECTION_DOUBLE_UP;
    }

    function bgColor(mmol as Float, low as Float, high as Float) as Number {
        if (mmol < low) { return COLOR_LOW; }
        if (mmol > high) { return COLOR_HIGH; }
        return COLOR_IN_RANGE;
    }

    function graphDotColor(mmol as Float, low as Float, high as Float) as Number {
        if (mmol < low) { return COLOR_GRAPH_DOT_LOW; }
        if (mmol > high) { return COLOR_GRAPH_DOT_HIGH; }
        return COLOR_GRAPH_DOT_IN_RANGE;
    }

    function staleColor(minutes as Number) as Number {
        if (minutes < 0) { return Graphics.COLOR_WHITE; }
        if (minutes < 5) { return Graphics.COLOR_WHITE; }
        if (minutes < STALE_MINUTES) { return COLOR_STALE_WARNING; }
        return COLOR_STALE;
    }

    function parseFloat(value) as Float {
        if (value instanceof Float) {
            return value as Float;
        } else if (value instanceof Double) {
            return (value as Double).toFloat();
        } else if (value instanceof Number) {
            return (value as Number).toFloat();
        }
        return 0.0f;
    }

    function parseLong(value) as Long {
        if (value instanceof Long) {
            return value as Long;
        } else if (value instanceof Double) {
            return (value as Double).toLong();
        } else if (value instanceof Float) {
            // Float has only ~7 digits of precision, not enough for epoch ms.
            // Convert via Double for full precision.
            return (value as Float).toDouble().toLong();
        } else if (value instanceof Number) {
            return (value as Number).toLong();
        }
        return 0l;
    }

    function formatDelta(deltaMmol as Float) as String {
        if (deltaMmol >= 0) {
            return "+" + deltaMmol.format("%.1f");
        }
        return deltaMmol.format("%.1f");
    }
}
