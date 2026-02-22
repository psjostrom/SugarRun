import Toybox.Activity;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class SugarRunView extends WatchUi.DataField {

    hidden var mFitField as Field?;
    hidden var mDisplayMode as Conversions.DisplayMode = Conversions.MODE_COMBINED;
    hidden var mGraphDuration as Number = 30;
    hidden var mBgLow as Float = 4.0f;
    hidden var mBgHigh as Float = 10.0f;
    hidden var mBgLargeFont as FontResource?;
    hidden var mPrevTimerState as Activity.TimerState = Activity.TIMER_STATE_OFF;
    hidden var mStopNotified as Boolean = false;

    function initialize() {
        DataField.initialize();
        loadSettings();
        if (mDisplayMode == Conversions.MODE_COMBINED) {
            mFitField = createField("Bloodglucose", 0,
                FitContributor.DATA_TYPE_FLOAT,
                {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "mg/dL"});
        }
    }

    function loadSettings() as Void {
        var mode = Properties.getValue("displayMode");
        if (mode != null && mode instanceof Number) {
            mDisplayMode = mode as Conversions.DisplayMode;
        }
        var dur = Properties.getValue("graphDuration");
        if (dur != null && dur instanceof Number) {
            mGraphDuration = dur as Number;
        }
        var low = Properties.getValue("bgLow");
        if (low != null && low instanceof Number) {
            mBgLow = (low as Number).toFloat() / 10.0f;
        }
        var high = Properties.getValue("bgHigh");
        if (high != null && high instanceof Number) {
            mBgHigh = (high as Number).toFloat() / 10.0f;
        }
    }

    function onLayout(dc as Dc) as Void {
        if (mDisplayMode == Conversions.MODE_COMBINED || mDisplayMode == Conversions.MODE_BG) {
            mBgLargeFont = WatchUi.loadResource($.Rez.Fonts.id_font_bg_large) as FontResource;
        }
    }

    function compute(info as Activity.Info) as Void {
        var service = (Application.getApp() as SugarRunApp).mService;
        if (service != null) {
            service.update();
            if (service.mHasData && mFitField != null) {
                mFitField.setData(service.mBgMgdl);
            }
        }

        // Detect activity stop → POST run data to Springa
        if (info.timerState != null) {
            var state = info.timerState as Activity.TimerState;
            if (state == Activity.TIMER_STATE_STOPPED && mPrevTimerState != Activity.TIMER_STATE_STOPPED && !mStopNotified) {
                mStopNotified = true;
                if (service != null) {
                    var distance = info.elapsedDistance as Float or Null;
                    var duration = (info.elapsedTime != null) ? (info.elapsedTime as Number).toLong() : null;
                    var avgHr = (info.averageHeartRate != null) ? (info.averageHeartRate as Number).toFloat() : null;
                    // Skip accidental starts: <100m or <60s
                    var tooShort = (distance != null && distance < 100.0f) || (duration != null && duration < 60000l);
                    if (!tooShort) {
                        service.postRunCompleted(distance, duration, avgHr);
                    }
                }
            }
            if (state == Activity.TIMER_STATE_ON) {
                mStopNotified = false;
            }
            mPrevTimerState = state;
        }
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var service = (Application.getApp() as SugarRunApp).mService;
        if (service == null || !service.mHasData) {
            drawNoData(dc);
            return;
        }

        if (mDisplayMode == Conversions.MODE_BG) {
            drawBg(dc, service);
        } else if (mDisplayMode == Conversions.MODE_ARROW) {
            drawArrow(dc, service);
        } else if (mDisplayMode == Conversions.MODE_DELTA) {
            drawDelta(dc, service);
        } else if (mDisplayMode == Conversions.MODE_TIME_SINCE) {
            drawTimeSince(dc, service);
        } else if (mDisplayMode == Conversions.MODE_GRAPH) {
            drawGraph(dc, service);
        } else {
            drawCombined(dc, service);
        }
    }

    // --- Display mode renderers ---

    hidden function drawNoData(dc as Dc) as Void {
        var service = (Application.getApp() as SugarRunApp).mService;
        var msg = "---";
        if (service != null && !service.mLastError.equals("")) {
            msg = service.mLastError;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2,
            Graphics.FONT_MEDIUM, msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawBg(dc as Dc, service as CgmService) as Void {
        var color = Conversions.bgColor(service.mBgMmol, mBgLow, mBgHigh);
        var text = service.mBgMmol.format("%.1f");
        var w = dc.getWidth();
        var h = dc.getHeight();
        var font = mBgLargeFont != null ? mBgLargeFont : pickBgFont(h);

        // If custom font is too wide, fall back to system fonts
        if (mBgLargeFont != null && dc.getTextWidthInPixels(text, font) > w) {
            font = pickBgFont(h);
        }

        // Step down until text fits both width and height
        if (font != mBgLargeFont) {
            for (var i = 0; i < 5; i++) {
                if (dc.getTextWidthInPixels(text, font) <= w && dc.getFontHeight(font) <= h) { break; }
                if (font == Graphics.FONT_MEDIUM) { break; }
                font = stepDownBgFont(font);
            }
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawArrow(dc as Dc, service as CgmService) as Void {
        var color = Conversions.bgColor(service.mBgMmol, mBgLow, mBgHigh);
        var size = dc.getHeight() < dc.getWidth() ? dc.getHeight() : dc.getWidth();
        size = (size * 0.6f).toNumber();
        ArrowRenderer.draw(dc, dc.getWidth() / 2, dc.getHeight() / 2,
            size, service.mDirection, color);
    }

    hidden function drawDelta(dc as Dc, service as CgmService) as Void {
        var color = Conversions.bgColor(service.mBgMmol, mBgLow, mBgHigh);
        var text = Conversions.formatDelta(service.mDeltaMmol);
        var font = pickSecondaryFont(dc.getHeight());

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawTimeSince(dc as Dc, service as CgmService) as Void {
        var minutes = service.getMinutesSinceLastReading();
        var text = (minutes >= 0) ? minutes.toString() + "'" : "-";
        var color = Conversions.staleColor(minutes);
        var font = pickSecondaryFont(dc.getHeight());

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawGraph(dc as Dc, service as CgmService) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var obscFlags = DataField.getObscurityFlags();
        var isCorner = ((obscFlags & OBSCURE_TOP) != 0) || ((obscFlags & OBSCURE_BOTTOM) != 0);
        var hPad = isCorner ? 0.22f : 0.04f;
        var vPad = isCorner ? 0.15f : 0.02f;
        var padL = (obscFlags & OBSCURE_LEFT) ? (w * hPad).toNumber() : 0;
        var padR = (obscFlags & OBSCURE_RIGHT) ? (w * hPad).toNumber() : 0;
        var padT = (obscFlags & OBSCURE_TOP) ? (h * vPad).toNumber() : 0;
        var padB = (obscFlags & OBSCURE_BOTTOM) ? (h * vPad).toNumber() : 0;
        GraphRenderer.draw(dc, padL, padT, w - padL - padR, h - padT - padB,
            service.mHistory, mGraphDuration, mBgLow, mBgHigh);
    }

    hidden function drawCombined(dc as Dc, service as CgmService) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var color = Conversions.bgColor(service.mBgMmol, mBgLow, mBgHigh);

        // Inset for circular screen clipping
        // Corner strips (near top/bottom of circle) have much shorter chord width
        var obscFlags = DataField.getObscurityFlags();
        var isCorner = ((obscFlags & OBSCURE_TOP) != 0) || ((obscFlags & OBSCURE_BOTTOM) != 0);
        var hPad = isCorner ? 0.22f : 0.02f;
        var padL = (obscFlags & OBSCURE_LEFT) ? (w * hPad).toNumber() : 0;
        var padR = (obscFlags & OBSCURE_RIGHT) ? (w * hPad).toNumber() : 0;
        var padT = (obscFlags & OBSCURE_TOP) ? (h * 0.08f).toNumber() : 0;
        var padB = (obscFlags & OBSCURE_BOTTOM) ? (h * 0.08f).toNumber() : 0;
        var usableW = w - padL - padR;
        var usableH = h - padT - padB;

        var bgText = service.mBgMmol.format("%.1f");
        var deltaText = Conversions.formatDelta(service.mDeltaMmol);
        var minutes = service.getMinutesSinceLastReading();
        var timeText = (minutes >= 0) ? minutes.toString() + "'" : "-";
        var deltaColor = Graphics.COLOR_WHITE;
        var timeColor = Conversions.staleColor(minutes);

        // Wide strip (aspect > 2:1) → single horizontal row
        if (usableW > usableH * 2) {
            drawCombinedHorizontal(dc, service, color, deltaColor, bgText, deltaText, timeText, timeColor, padL, padT, usableW, usableH);
        } else {
            drawCombinedStacked(dc, service, color, deltaColor, bgText, deltaText, timeText, timeColor, padL, padT, usableW, usableH);
        }
    }

    hidden function drawCombinedHorizontal(dc as Dc, service as CgmService, color as Number, deltaColor as Number,
            bgText as String, deltaText as String, timeText as String, timeColor as Number,
            padL as Number, padT as Number, usableW as Number, usableH as Number) as Void {
        // BG uses custom large bitmap font — let it clip vertically for max size
        var bgFont = mBgLargeFont != null ? mBgLargeFont : pickBgFont(usableH);
        var secFont = pickSecondaryFont(usableH);

        var bgW = dc.getTextWidthInPixels(bgText, bgFont);

        var arrowSize = (usableH * 0.35f).toNumber();
        if (arrowSize < 10) { arrowSize = 10; }
        var deltaW = dc.getTextWidthInPixels(deltaText, secFont);
        var timeW = dc.getTextWidthInPixels(timeText, secFont);

        // Layout: [time] [arrow] [BG] [delta] — time isolated on left
        var gap = (usableH * 0.12f).toNumber();
        if (gap < 3) { gap = 3; }
        var totalW = timeW + gap + arrowSize + gap + bgW + gap + deltaW;
        var x = padL + (usableW - totalW) / 2;
        if (x < padL) { x = padL; }

        var cy = padT + usableH / 2;

        // TimeSince — far left
        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy, secFont, timeText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += timeW + gap;

        // Arrow
        ArrowRenderer.draw(dc, x + arrowSize / 2, cy, arrowSize, service.mDirection, color);
        x += arrowSize + gap;

        // BG — custom large font
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy, bgFont, bgText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += bgW + gap;

        // Delta — far right
        dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, cy, secFont, deltaText,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    hidden function drawCombinedStacked(dc as Dc, service as CgmService, color as Number, deltaColor as Number,
            bgText as String, deltaText as String, timeText as String, timeColor as Number,
            padL as Number, padT as Number, usableW as Number, usableH as Number) as Void {
        // Two rows: Row 1 [Arrow][BG], Row 2 [Delta][TimeSince]
        var bgFont = pickBgFont(usableH);
        var secFont = pickSecondaryFont(usableH);
        var bgFontH = 0;
        var secFontH = 0;
        var rowGap = (usableH * 0.06f).toNumber();
        if (rowGap < 2) { rowGap = 2; }
        var totalH = 0;
        var arrowSize = 0;
        var row1W = 0;

        for (var i = 0; i < 5; i++) {
            bgFontH = dc.getFontHeight(bgFont);
            secFontH = dc.getFontHeight(secFont);
            totalH = bgFontH + rowGap + secFontH;
            arrowSize = (bgFontH * 0.55f).toNumber();
            if (arrowSize < 16) { arrowSize = 16; }
            row1W = arrowSize + 6 + dc.getTextWidthInPixels(bgText, bgFont);

            if (totalH <= usableH && row1W <= usableW) {
                break;
            }
            if (bgFont == Graphics.FONT_MEDIUM) {
                break;
            }
            bgFont = stepDownBgFont(bgFont);
        }

        var row1Y = padT + (usableH - totalH) / 2;
        var row1X = padL + (usableW - row1W) / 2;

        // Arrow
        ArrowRenderer.draw(dc, row1X + arrowSize / 2, row1Y + bgFontH / 2,
            arrowSize, service.mDirection, color);

        // BG
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(row1X + arrowSize + 6, row1Y, bgFont, bgText, Graphics.TEXT_JUSTIFY_LEFT);

        // Delta + TimeSince
        var row2Y = row1Y + bgFontH + rowGap;
        var deltaW = dc.getTextWidthInPixels(deltaText, secFont);
        var timeW = dc.getTextWidthInPixels(timeText, secFont);
        var gap = (usableW * 0.06f).toNumber();
        if (gap < 8) { gap = 8; }
        var row2W = deltaW + gap + timeW;
        var row2X = padL + (usableW - row2W) / 2;

        dc.setColor(deltaColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(row2X, row2Y, secFont, deltaText, Graphics.TEXT_JUSTIFY_LEFT);

        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(row2X + deltaW + gap, row2Y, secFont, timeText, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // --- Font helpers ---

    hidden function pickBgFont(fieldHeight as Number) as FontDefinition {
        // Always start with the biggest font. Step-down loops handle overflow.
        return Graphics.FONT_NUMBER_THAI_HOT;
    }

    hidden function stepDownBgFont(font as FontDefinition) as FontDefinition {
        if (font == Graphics.FONT_NUMBER_THAI_HOT) {
            return Graphics.FONT_NUMBER_HOT;
        } else if (font == Graphics.FONT_NUMBER_HOT) {
            return Graphics.FONT_NUMBER_MEDIUM;
        } else if (font == Graphics.FONT_NUMBER_MEDIUM) {
            return Graphics.FONT_LARGE;
        } else if (font == Graphics.FONT_LARGE) {
            return Graphics.FONT_MEDIUM;
        }
        return Graphics.FONT_MEDIUM;
    }

    hidden function pickSecondaryFont(fieldHeight as Number) as FontDefinition {
        if (fieldHeight >= 80) {
            return Graphics.FONT_MEDIUM;
        } else if (fieldHeight >= 50) {
            return Graphics.FONT_SMALL;
        } else if (fieldHeight >= 30) {
            return Graphics.FONT_TINY;
        }
        return Graphics.FONT_XTINY;
    }
}
