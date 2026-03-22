import Toybox.Application;
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
    var mHasData as Boolean = false;
    var mLastError as String = "";

    hidden var mLastFetchTime as Number = 0;
    hidden var mFetching as Boolean = false;
    const FETCH_INTERVAL = 15;

    function initialize() {
    }

    function update() as Void {
        var now = Time.now().value();
        if (!mFetching && (mLastFetchTime == 0 || now - mLastFetchTime >= FETCH_INTERVAL)) {
            mLastFetchTime = now;
            fetchData();
        }
    }

    function fetchData() as Void {
        var rawUrl = Application.Properties.getValue("nightscoutUrl") as String?;
        var secret = Application.Properties.getValue("nightscoutSecret") as String?;
        if (rawUrl == null || rawUrl.equals("") || secret == null || secret.equals("")) {
            mLastError = "Set URL";
            return;
        }
        var url = normalizeUrl(rawUrl);
        mFetching = true;
        mLastError = "...";
        Communications.makeWebRequest(
            url + "/api/v1/entries/sgv.json?count=1",
            {},
            {
                :headers => { "api-secret" => secret },
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
        mDeltaMgdl = Conversions.parseFloat(latest["delta"]);
        mDeltaMmol = Conversions.mgdlToMmol(mDeltaMgdl);
        mDirection = Conversions.directionFromString(latest["direction"]);
        if (latest.hasKey("date")) {
            mLastReadingTime = Conversions.parseLong(latest["date"]);
        }

        mHasData = true;
        mLastError = "";
    }

    function getMinutesSinceLastReading() as Number {
        if (mLastReadingTime == 0l) {
            return -1;
        }
        var nowUnixMs = Time.now().value().toLong() * 1000l;
        return ((nowUnixMs - mLastReadingTime) / 60000l).toNumber();
    }

    hidden function normalizeUrl(raw as String) as String {
        if (raw.find("https://") == 0 || raw.find("http://") == 0) {
            // Strip trailing slash
            if (raw.length() > 8 && raw.substring(raw.length() - 1, raw.length()).equals("/")) {
                return raw.substring(0, raw.length() - 1);
            }
            return raw;
        }
        return "https://" + raw;
    }

    function postRunCompleted() as Void {
        var rawUrl = Application.Properties.getValue("nightscoutUrl") as String?;
        var secret = Application.Properties.getValue("nightscoutSecret") as String?;
        if (rawUrl == null || rawUrl.equals("") || secret == null || secret.equals("")) {
            return;
        }
        var url = normalizeUrl(rawUrl);

        Communications.makeWebRequest(
            url + "/api/run-completed",
            {} as Dictionary,
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => { "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON, "api-secret" => secret },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onRunCompletedResponse)
        );
    }

    function onRunCompletedResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
    }

    function stop() as Void {
    }
}
