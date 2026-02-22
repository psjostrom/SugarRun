import Toybox.Application.Properties;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.Time;

class CgmService {

    var mBgMgdl as Float = 0.0f;
    var mBgMmol as Float = 0.0f;
    var mDeltaMgdl as Float = 0.0f;
    var mDeltaMmol as Float = 0.0f;
    var mDirection as Conversions.Direction = Conversions.DIRECTION_NONE;
    var mLastReadingTime as Long = 0l;
    var mHistory as Array = [];
    var mHasData as Boolean = false;
    var mLastError as String = "";

    hidden var mLastFetchTime as Number = 0;
    hidden var mFetching as Boolean = false;
    const FETCH_INTERVAL = 60; // seconds

    function initialize() {
        loadMockData();
    }

    function loadMockData() as Void {
        var sgvs = [252,242,243,235,221,212,205,199,193,176,162,151,138,136,133,126,127,117,104,87,74,67,73,81];
        var deltas = [7.0f,7.0f,9.5f,9.5f,8.5f,8.5f,9.5f,11.0f,12.5f,10.0f,8.0f,6.0f,4.5f,5.0f,6.5f,7.5f,10.0f,9.5f,7.0f,1.5f,-3.5f,-6.5f,-6.5f,-6.5f];
        var dirs = ["FortyFiveDown","Flat","Flat","FortyFiveUp","FortyFiveUp","FortyFiveUp","SingleUp","SingleUp","FortyFiveUp","FortyFiveUp","FortyFiveUp","Flat","Flat","FortyFiveUp","FortyFiveUp","FortyFiveUp","FortyFiveUp","FortyFiveUp","FortyFiveUp","Flat","Flat","FortyFiveDown","FortyFiveDown","FortyFiveDown"];

        var nowMs = Time.now().value().toLong() * 1000l;

        mBgMgdl = (sgvs[0] as Number).toFloat();
        mBgMmol = Conversions.mgdlToMmol(mBgMgdl);
        mDeltaMgdl = deltas[0];
        mDeltaMmol = Conversions.mgdlToMmol(mDeltaMgdl);
        mDirection = Conversions.directionFromString(dirs[0]);
        mLastReadingTime = nowMs;
        mHasData = true;

        mHistory = [];
        for (var i = 0; i < sgvs.size(); i++) {
            var bg = Conversions.mgdlToMmol((sgvs[i] as Number).toFloat());
            var time = nowMs - (i.toLong() * 300000l);
            mHistory.add({:bg => bg, :time => time});
        }
    }

    function update() as Void {
        var now = Time.now().value();
        if (!mFetching && (mLastFetchTime == 0 || now - mLastFetchTime >= FETCH_INTERVAL)) {
            mLastFetchTime = now;
            fetchData();
        }
    }

    function fetchData() as Void {
        mFetching = true;
        mLastError = "...";
        Communications.makeWebRequest(
            "http://127.0.0.1:17580/sgv.json",
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onReceive)
        );
    }

    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        mFetching = false;

        if (responseCode != 200) {
            mLastError = "HTTP " + responseCode;
            return;
        }
        if (data == null) {
            mLastError = "null";
            return;
        }

        // CIQ delivers JSON arrays as Array at runtime even though the
        // callback type signature doesn't include Array. Skip instanceof
        // check (compiler optimizes it away) and cast directly.
        var readings = data as Array;
        if (readings.size() == 0) {
            mLastError = "empty";
            return;
        }

        var latest = readings[0] as Dictionary;

        if (latest.hasKey("sgv")) {
            mBgMgdl = Conversions.parseFloat(latest["sgv"]);
            mBgMmol = Conversions.mgdlToMmol(mBgMgdl);
        }
        // Compute delta from sgv[0]-sgv[1], normalized to 5-min interval
        // (same approach as SuperStable). Falls back to API delta field.
        if (readings.size() >= 2) {
            var prev = readings[1] as Dictionary;
            if (latest.hasKey("sgv") && prev.hasKey("sgv") &&
                latest.hasKey("date") && prev.hasKey("date")) {
                var t0 = Conversions.parseLong(latest["date"]);
                var t1 = Conversions.parseLong(prev["date"]);
                var dtMs = t0 - t1;
                if (dtMs > 0) {
                    var rawDelta = Conversions.parseFloat(latest["sgv"]) - Conversions.parseFloat(prev["sgv"]);
                    mDeltaMgdl = rawDelta / (dtMs.toFloat() / 300000.0f);
                    mDeltaMmol = Conversions.mgdlToMmol(mDeltaMgdl);
                }
            }
        } else if (latest.hasKey("delta")) {
            mDeltaMgdl = Conversions.parseFloat(latest["delta"]);
            mDeltaMmol = Conversions.mgdlToMmol(mDeltaMgdl);
        }
        mDirection = Conversions.directionFromDelta(mDeltaMgdl);
        if (latest.hasKey("date")) {
            mLastReadingTime = Conversions.parseLong(latest["date"]);
        }

        mHasData = true;
        mLastError = "";

        mHistory = [];
        for (var i = 0; i < readings.size(); i++) {
            var r = readings[i] as Dictionary;
            var bg = 0.0f;
            var time = 0l;
            if (r.hasKey("sgv")) {
                bg = Conversions.mgdlToMmol(Conversions.parseFloat(r["sgv"]));
            }
            if (r.hasKey("date")) {
                time = Conversions.parseLong(r["date"]);
            }
            mHistory.add({:bg => bg, :time => time});
        }
    }

    function getMinutesSinceLastReading() as Number {
        if (mLastReadingTime == 0l) {
            return -1;
        }
        return ((Time.now().value().toLong() - mLastReadingTime / 1000) / 60).toNumber();
    }

    function postRunCompleted(distance as Float or Null, duration as Long or Null, avgHr as Float or Null) as Void {
        var url = Properties.getValue("springaUrl") as String;
        var secret = Properties.getValue("springaSecret") as String;
        if (url == null || secret == null || url.equals("") || secret.equals("")) {
            return;
        }

        var body = {} as Dictionary;
        if (distance != null) {
            body.put("distance", distance);
        }
        if (duration != null) {
            body.put("duration", duration);
        }
        if (avgHr != null) {
            body.put("avgHr", avgHr);
        }

        Communications.makeWebRequest(
            url + "/api/run-completed",
            body,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON, "api-secret" => secret },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onRunCompletedResponse)
        );
    }

    function onRunCompletedResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        // Fire-and-forget — no action needed
    }

    function stop() as Void {
    }
}
