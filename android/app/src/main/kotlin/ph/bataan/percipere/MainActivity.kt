package ph.bataan.percipere

import android.media.AudioManager
import android.media.ToneGenerator
import android.os.StatFs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: required by local_auth for the fingerprint dialog.
class MainActivity : FlutterFragmentActivity() {
    private var tones: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Free space for the Library's "low storage" warning before a download.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ph.bataan.percipere/storage"
        ).setMethodCallHandler { call, result ->
            if (call.method == "freeBytes") {
                try {
                    result.success(StatFs(filesDir.absolutePath).availableBytes)
                } catch (e: Exception) {
                    result.error("storage", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
        // The short "heard you" sound played the moment a voice command is
        // recognized. ToneGenerator starts at once (no file to load).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ph.bataan.percipere/sound"
        ).setMethodCallHandler { call, result ->
            if (call.method == "heard") {
                try {
                    val generator = tones
                        ?: ToneGenerator(AudioManager.STREAM_MUSIC, 70).also { tones = it }
                    generator.startTone(ToneGenerator.TONE_PROP_BEEP, 70)
                    result.success(true)
                } catch (e: RuntimeException) {
                    // No audio right now: the vibration still confirms.
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        tones?.release()
        tones = null
        super.onDestroy()
    }
}
