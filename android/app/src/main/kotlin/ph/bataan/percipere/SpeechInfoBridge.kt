package ph.bataan.percipere

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * What the phone's speech recognition can do, for the voice listening plan
 * and the "Voice check" screen: which recognition service is the default,
 * whether on-device (offline) recognition exists, and which languages are
 * installed for it. The speech_to_text plugin only lists the languages the
 * on-device recognizer *supports* (downloadable or not), so it can't tell
 * whether a language works offline.
 */
class SpeechInfoBridge(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    init {
        MethodChannel(messenger, "ph.bataan.percipere/speech").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> info(result)
                "download" -> download(call.argument<String>("language"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun micAllowed() = context.checkSelfPermission(
        Manifest.permission.RECORD_AUDIO
    ) == PackageManager.PERMISSION_GRANTED

    private fun baseInfo(): MutableMap<String, Any?> {
        val sdk = Build.VERSION.SDK_INT
        val service = try {
            Settings.Secure.getString(context.contentResolver, "voice_recognition_service")
        } catch (e: Exception) {
            null
        }
        val onDevice = try {
            sdk >= Build.VERSION_CODES.S && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } catch (e: Exception) {
            false
        }
        val available = try {
            SpeechRecognizer.isRecognitionAvailable(context)
        } catch (e: Exception) {
            false
        }
        return mutableMapOf(
            "sdk" to sdk,
            "service" to service?.let { ComponentName.unflattenFromString(it)?.packageName ?: it },
            "available" to available,
            "onDevice" to onDevice,
        )
    }

    private fun info(result: MethodChannel.Result) {
        val base = baseInfo()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            base["onDevice"] != true || !micAllowed()
        ) {
            result.success(base)
            return
        }
        var answered = false
        fun answer(extra: Map<String, Any?>) {
            if (answered) return
            answered = true
            result.success(base + extra)
        }
        main.post {
            val recognizer = try {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } catch (e: Exception) {
                answer(mapOf("error" to "create: ${e.message}"))
                return@post
            }
            // Some recognizers never answer: don't let the app wait for them.
            main.postDelayed({
                answer(mapOf("error" to "timeout"))
                recognizer.destroy()
            }, 3000)
            try {
                recognizer.checkRecognitionSupport(
                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH),
                    executor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(support: RecognitionSupport) {
                            main.post {
                                answer(
                                    mapOf(
                                        "installed" to support.installedOnDeviceLanguages,
                                        "pending" to support.pendingOnDeviceLanguages,
                                        "supported" to support.supportedOnDeviceLanguages,
                                        "online" to support.onlineLanguages,
                                    )
                                )
                                recognizer.destroy()
                            }
                        }

                        override fun onError(error: Int) {
                            main.post {
                                answer(mapOf("error" to "support $error"))
                                recognizer.destroy()
                            }
                        }
                    })
            } catch (e: Exception) {
                answer(mapOf("error" to "check: ${e.message}"))
                recognizer.destroy()
            }
        }
    }

    /** Asks the on-device recognizer to download [language] (Android 13+). */
    private fun download(language: String?, result: MethodChannel.Result) {
        if (language == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            !micAllowed()
        ) {
            result.success(false)
            return
        }
        main.post {
            try {
                val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                recognizer.triggerModelDownload(
                    Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
                )
                main.postDelayed({ recognizer.destroy() }, 1000)
                result.success(true)
            } catch (e: Exception) {
                result.success(false)
            }
        }
    }

    fun dispose() {
        executor.shutdown()
    }
}
