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
        // app has spoken. ToneGenerator starts at once (no file to load).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ph.bataan.percipere/sound"
        ).setMethodCallHandler { call, result ->
            val (tone, millis) = when (call.method) {
                "heard" -> ToneGenerator.TONE_PROP_BEEP to 70
                "listening" -> ToneGenerator.TONE_PROP_ACK to 40
                "stopped" -> ToneGenerator.TONE_PROP_NACK to 60
                else -> null to 0
            }
            if (tone == null) {
                result.notImplemented()
            } else {
                try {
                    val generator = tones
                        ?: ToneGenerator(AudioManager.STREAM_MUSIC, 70).also { tones = it }
                    generator.startTone(tone, millis)
                    result.success(true)
                } catch (e: RuntimeException) {
                    // No audio right now: the vibration still confirms.
                    result.success(false)
                }
            }
        }
    }

    override fun onDestroy() {
        assistant?.dispose()
        assistant = null
        speechInfo?.dispose()
        speechInfo = null
        audio?.dispose()
        audio = null
        tones?.release()
        tones = null
        super.onDestroy()
    }
}
