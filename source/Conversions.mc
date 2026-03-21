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

    const MGDL_TO_MMOL = 18.018f;
    const STALE_MINUTES = 11;

    const COLOR_IN_RANGE = 0x55FF55;
    const COLOR_HIGH = 0xFFDD00;
    const COLOR_LOW = 0xFF5555;
    const COLOR_STALE = 0xFF5555;
    const COLOR_STALE_WARNING = 0xFFAA00;

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

    function bgColor(mmol as Float, low as Float, high as Float) as Number {
        if (mmol < low) { return COLOR_LOW; }
        if (mmol > high) { return COLOR_HIGH; }
        return COLOR_IN_RANGE;
    }

    function staleColor(minutes as Number) as Number {
        if (minutes < 0) { return Graphics.COLOR_WHITE; }
        if (minutes < 6) { return Graphics.COLOR_WHITE; }
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
