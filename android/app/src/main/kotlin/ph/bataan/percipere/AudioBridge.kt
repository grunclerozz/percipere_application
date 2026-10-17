package ph.bataan.percipere

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Raw audio for the app's own offline voice engines (sherpa-onnx):
 *
 * - **Microphone**: 16 kHz mono PCM16 in ~100 ms chunks on the event channel
 *   `ph.bataan.percipere/mic`, for the offline command spotter. Uses the
 *   voice-recognition source and the phone's echo canceller when it has one,
 *   so commands said while the app reads aloud are heard over its own voice.
 * - **Playback**: plays the samples the offline voices generate
 *   (`play` answers true when the sound finished, false when it was stopped).
 */
class AudioBridge(private val context: Context, messenger: BinaryMessenger) {
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile private var recording = false
    private var recorder: AudioRecord? = null
    private var recordThread: Thread? = null
    private var echo: AcousticEchoCanceler? = null
    private var noise: NoiseSuppressor? = null
    private var gain: AutomaticGainControl? = null

    @Volatile private var playGeneration = 0
    private var track: AudioTrack? = null
    private var focus: AudioFocusRequest? = null

    init {
        EventChannel(messenger, "ph.bataan.percipere/mic").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                }
            }
        )
        MethodChannel(messenger, "ph.bataan.percipere/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "micStart" -> result.success(
                    micStart(
                        call.argument<Int>("sampleRate") ?: 16000,
                        call.argument<Boolean>("noiseSuppressor") ?: false,
                        call.argument<Boolean>("autoGain") ?: false
                    )
                )
                "micStop" -> {
                    micStop()
                    result.success(true)
                }
                "play" -> play(
                    call.argument<FloatArray>("samples"),
                    call.argument<Int>("sampleRate") ?: 16000,
                    result
                )
                "playStop" -> {
                    playStop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Microphone ─────────────────────────────────────────────────────────

    private fun micStart(sampleRate: Int, suppressNoise: Boolean, autoGain: Boolean): Boolean {
        if (recording) return true
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        return try {
            val chunk = sampleRate / 10 // 100 ms of samples
            val minBuffer = AudioRecord.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) return false
            val rec = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                max(minBuffer, chunk * 2 * 4)
            )
            if (rec.state != AudioRecord.STATE_INITIALIZED) {
                rec.release()
                return false
            }
            echo = try {
                if (AcousticEchoCanceler.isAvailable()) {
                    AcousticEchoCanceler.create(rec.audioSessionId)?.also { it.enabled = true }
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }
            // The phone's own noise suppressor and gain control, when it has
            // them and Dart asks (VoiceConfig.micNoiseSuppressor / micAutoGain).
            noise = try {
                if (suppressNoise && NoiseSuppressor.isAvailable()) {
                    NoiseSuppressor.create(rec.audioSessionId)?.also { it.enabled = true }
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }
            gain = try {
                if (autoGain && AutomaticGainControl.isAvailable()) {
                    AutomaticGainControl.create(rec.audioSessionId)?.also { it.enabled = true }
                } else {
                    null
                }
            } catch (e: Exception) {
                null
            }
            rec.startRecording()
            recorder = rec
            recording = true
            recordThread = Thread {
                val buffer = ByteArray(chunk * 2)
                while (recording) {
                    val read = try {
                        rec.read(buffer, 0, buffer.size)
                    } catch (e: Exception) {
                        -1
                    }
                    if (read < 0) {
                        main.post { sink?.error("mic", "read failed: $read", null) }
                        break
                    }
                    if (read > 0) {
                        val copy = buffer.copyOf(read)
                        main.post { sink?.success(copy) }
                    }
                }
            }.also {
                it.name = "percipere-mic"
                it.start()
            }
            true
        } catch (e: Exception) {
            micStop()
            false
        }
    }

    private fun micStop() {
        recording = false
        try {
            recordThread?.join(300)
        } catch (e: InterruptedException) {
            // Closing anyway.
        }
        recordThread = null
        try {
            recorder?.stop()
        } catch (e: Exception) {
            // Already stopped.
        }
        recorder?.release()
        recorder = null
        echo?.release()
        echo = null
        noise?.release()
        noise = null
        gain?.release()
        gain = null
    }

    // ── Playback ───────────────────────────────────────────────────────────

    private fun play(samples: FloatArray?, sampleRate: Int, result: MethodChannel.Result) {
        if (samples == null || samples.isEmpty()) {
            result.success(true)
            return
        }
        playStop()
        val generation = ++playGeneration
        Thread {
            var finished = false
            val out = try {
                AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setTransferMode(AudioTrack.MODE_STREAM)
                    .setBufferSizeInBytes(
                        max(
                            AudioTrack.getMinBufferSize(
                                sampleRate,
                                AudioFormat.CHANNEL_OUT_MONO,
                                AudioFormat.ENCODING_PCM_16BIT
                            ),
                            sampleRate / 5 * 2
                        )
                    )
                    .build()
            } catch (e: Exception) {
                null
            }
            if (out == null) {
                main.post { result.success(false) }
                return@Thread
            }
            synchronized(this) {
                if (generation != playGeneration) {
                    out.release()
                    main.post { result.success(false) }
                    return@Thread
                }
                track = out
            }
            requestFocus()
            try {
                val pcm = ShortArray(samples.size) {
                    (samples[it].coerceIn(-1f, 1f) * 32767f).roundToInt().toShort()
                }
                out.play()
                var offset = 0
                val step = sampleRate / 10
                // Non-blocking writes: a stopped track never leaves this
                // thread waiting.
                while (offset < pcm.size && generation == playGeneration) {
                    val n = minOf(step, pcm.size - offset)
                    val written = out.write(pcm, offset, n, AudioTrack.WRITE_NON_BLOCKING)
                    if (written < 0) break
                    if (written == 0) Thread.sleep(10) else offset += written
                }
                // Wait for the last samples to be heard (at most the sound's
                // length plus a second, should the device stall).
                val deadline = System.currentTimeMillis() + pcm.size * 1000L / sampleRate + 1000
                while (generation == playGeneration &&
                    out.playbackHeadPosition < pcm.size &&
                    System.currentTimeMillis() < deadline
                ) {
                    Thread.sleep(15)
                }
                finished = generation == playGeneration && offset >= pcm.size
            } catch (e: Exception) {
                finished = false
            } finally {
                synchronized(this) {
                    if (track === out) track = null
                }
                try {
                    out.stop()
                } catch (e: Exception) {
                    // Stopped already.
                }
                out.release()
                if (generation == playGeneration) abandonFocus()
            }
            main.post { result.success(finished) }
        }.also { it.name = "percipere-play" }.start()
    }

    private fun playStop() {
        playGeneration++
        synchronized(this) {
            try {
                track?.pause()
                track?.flush()
            } catch (e: Exception) {
                // Not playing.
            }
        }
        abandonFocus()
    }

    private fun requestFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .build()
            manager.requestAudioFocus(request)
            focus = request
        } catch (e: Exception) {
            // Plays without focus.
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val request = focus ?: return
        focus = null
        try {
            val manager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            manager.abandonAudioFocusRequest(request)
        } catch (e: Exception) {
            // Nothing to give back.
        }
    }

    fun dispose() {
        micStop()
        playStop()
    }
}
