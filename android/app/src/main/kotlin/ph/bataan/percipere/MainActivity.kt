package ph.bataan.percipere

import android.os.StatFs
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: required by local_auth for the fingerprint dialog.
class MainActivity : FlutterFragmentActivity() {
    private val tones = TonePlayer()
    private var assistant: AssistantBridge? = null
    private var speechInfo: SpeechInfoBridge? = null
    private var audio: AudioBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The ElevenLabs voice assistant ("Percy").
        assistant = AssistantBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Recognition service, offline availability and installed languages.
        speechInfo = SpeechInfoBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // Microphone and playback for the offline voice engines (sherpa-onnx).
        audio = AudioBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
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
        // Short sounds: "heard you" the moment a voice command is recognized,
        // and a softer "listening" blip when the microphone opens after the
        // app has spoken. Fixed-length tones that always end (TonePlayer);
        // each call answers when its tone has ended. "stop" silences one.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ph.bataan.percipere/sound"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "heard", "listening", "stopped" -> tones.play(call.method) { ok ->
                    // No audio right now: the vibration still confirms.
                    result.success(ok)
                }
                "stop" -> {
                    tones.stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onPause() {
        // A tone never sounds on after the app leaves the screen.
        tones.stop()
        super.onPause()
    }

    override fun onDestroy() {
        assistant?.dispose()
        assistant = null
        speechInfo?.dispose()
        speechInfo = null
        audio?.dispose()
        audio = null
        tones.stop()
        super.onDestroy()
    }
}
