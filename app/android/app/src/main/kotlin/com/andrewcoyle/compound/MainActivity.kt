package com.andrewcoyle.compound

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// A FlutterFragmentActivity: the health package asks for Health Connect permissions through
// an ActivityResult contract, which needs a ComponentActivity host.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The rest-complete sound (`RestSound`): the default notification sound, which follows
        // the ringer mode as the iOS system sound follows the silent switch.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.andrewcoyle.compound/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "restComplete") {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    RingtoneManager.getRingtone(applicationContext, uri)?.play()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
