import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SugarRunApp extends Application.AppBase {

    var mService as CgmService?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        mService = new CgmService();
    }

    function onStop(state as Dictionary?) as Void {
        if (mService != null) {
            mService.stop();
            mService = null;
        }
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        return [new SugarRunView()];
    }
}

function getApp() as SugarRunApp {
    return Application.getApp() as SugarRunApp;
}
