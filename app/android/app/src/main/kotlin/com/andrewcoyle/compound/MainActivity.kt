package com.andrewcoyle.compound

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
        // The Label scanner's on-device text reading (`PlatformLabelTextReader`): ML Kit's
        // bundled Latin model, one line per printed line, as Vision does on iOS.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.andrewcoyle.compound/label_text")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> (call.arguments as? ByteArray)?.let { readLabelText(it, result) }
                        ?: result.notImplemented()
                    "readFrame" -> readLabelFrame(call.arguments as? Map<*, *>, result)
                    else -> result.notImplemented()
                }
            }
    }

    // One NV21 frame of the live camera (`DeviceLiveCamera`), with the clockwise turn that
    // stands it upright. NV21 rows carry no padding, so the width is the row length.
    private fun readLabelFrame(frame: Map<*, *>?, result: MethodChannel.Result) {
        val bytes = frame?.get("bytes") as? ByteArray
        val width = frame?.get("width") as? Int
        val height = frame?.get("height") as? Int
        val rotation = frame?.get("rotation") as? Int
        if (bytes == null || width == null || height == null || rotation == null) {
            result.notImplemented()
            return
        }
        val image = try {
            InputImage.fromByteArray(bytes, width, height, rotation, InputImage.IMAGE_FORMAT_NV21)
        } catch (error: Exception) {
            result.error("unreadable", error.message, null)
            return
        }
        recognise(image, result) {}
    }

    private fun recognise(image: InputImage, result: MethodChannel.Result, done: () -> Unit) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { text ->
                result.success(text.textBlocks.flatMap { it.lines }.joinToString("\n") { it.text })
            }
            .addOnFailureListener { error -> result.error("unreadable", error.message, null) }
            .addOnCompleteListener {
                recognizer.close()
                done()
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
        recognise(image, result) { file.delete() }
    }
}
