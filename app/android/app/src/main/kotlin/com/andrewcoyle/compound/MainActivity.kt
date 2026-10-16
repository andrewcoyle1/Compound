package com.andrewcoyle.compound

import android.media.RingtoneManager
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

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
        // The Label scanner's on-device text reading (`PlatformLabelTextReader`): ML Kit's
        // bundled Latin model, one line per printed line, as Vision does on iOS.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.andrewcoyle.compound/label_text")
            .setMethodCallHandler { call, result ->
                val jpeg = call.arguments as? ByteArray
                if (call.method != "read" || jpeg == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                readLabelText(jpeg, result)
            }
    }

    // Read from a file, so ML Kit applies the photo's EXIF rotation.
    private fun readLabelText(jpeg: ByteArray, result: MethodChannel.Result) {
        val file = File.createTempFile("label", ".jpg", cacheDir)
        val image = try {
            file.writeBytes(jpeg)
            InputImage.fromFilePath(applicationContext, Uri.fromFile(file))
        } catch (error: Exception) {
            file.delete()
            result.error("unreadable", error.message, null)
            return
        }
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                result.success(text.textBlocks.flatMap { it.lines }.joinToString("\n") { it.text })
            }
            .addOnFailureListener { error -> result.error("unreadable", error.message, null) }
            .addOnCompleteListener {
                recognizer.close()
                file.delete()
            }
    }
}
