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
import android.media.MediaCodec
import android.media.MediaDataSource
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaRecorder
import android.media.PlaybackParams
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
 *   audio source Dart asks for (voice recognition by default, voice
 *   communication as the other choice) with the phone's echo canceller and
 *   noise suppressor when it has them, and says which are really on.
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

    /** The play generation that holds [focus]. */
    private var focusOwner = -1

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
                        call.argument<String>("source") ?: SOURCE_RECOGNITION,
                        call.argument<Boolean>("echoCanceller") ?: true,
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
                "playClip" -> playClip(
                    call.argument<ByteArray>("bytes"),
                    (call.argument<Double>("rate") ?: 1.0).toFloat(),
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

    /**
     * Opens the microphone on the audio [source] asked for
     * (`voiceRecognition` / `voiceCommunication`; the other one if it can't
     * be opened) with the phone's echo canceller, noise suppressor and gain
     * control as asked and available. Answers a map: `ok`, the `source` used
     * and which effects are really on (`aec`, `ns`, `agc`).
     */
    private fun micStart(
        sampleRate: Int,
        source: String,
        cancelEcho: Boolean,
        suppressNoise: Boolean,
        autoGain: Boolean
    ): Map<String, Any> {
        if (recording) return captureInfo(true)
        if (context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf("ok" to false)
        }
        return try {
            val chunk = sampleRate / 10 // 100 ms of samples
            val minBuffer = AudioRecord.getMinBufferSize(
                sampleRate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuffer <= 0) return mapOf("ok" to false)
            val wanted = if (source == SOURCE_COMMUNICATION) SOURCE_COMMUNICATION else SOURCE_RECOGNITION
            val other = if (wanted == SOURCE_RECOGNITION) SOURCE_COMMUNICATION else SOURCE_RECOGNITION
            val size = max(minBuffer, chunk * 2 * 4)
            val first = openRecorder(wanted, sampleRate, size)
            val rec = first ?: openRecorder(other, sampleRate, size) ?: return mapOf("ok" to false)
            usedSource = if (first != null) wanted else other
            echo = try {
                if (cancelEcho && AcousticEchoCanceler.isAvailable()) {
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
            captureInfo(true)
        } catch (e: Exception) {
            micStop()
            mapOf("ok" to false)
        }
    }

    private var usedSource = SOURCE_RECOGNITION

    /** The open microphone's source and the effects that are really on. */
    private fun captureInfo(ok: Boolean): Map<String, Any> = mapOf(
        "ok" to ok,
        "source" to usedSource,
        "aec" to (try { echo?.enabled == true } catch (e: Exception) { false }),
        "ns" to (try { noise?.enabled == true } catch (e: Exception) { false }),
        "agc" to (try { gain?.enabled == true } catch (e: Exception) { false })
    )

    private fun openRecorder(source: String, sampleRate: Int, bufferSize: Int): AudioRecord? {
        return try {
            val rec = AudioRecord(
                if (source == SOURCE_COMMUNICATION) {
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION
                } else {
                    MediaRecorder.AudioSource.VOICE_RECOGNITION
                },
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
            if (rec.state == AudioRecord.STATE_INITIALIZED) {
                rec
            } else {
                rec.release()
                null
            }
        } catch (e: Exception) {
            null
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
            val code = playPcm(samples, sampleRate, 1f, generation)
            main.post { result.success(code == PLAY_DONE) }
        }.also { it.name = "percipere-play" }.start()
    }

    /**
     * Plays a bundled voice clip (mp3 bytes): decodes it, then plays it
     * through the same track as the offline voices, [rate] times normal speed
     * with the pitch kept. Answers [PLAY_DONE] (finished), [PLAY_STOPPED]
     * (stopped by [playStop]) or [PLAY_FAILED] (could not decode or play: the
     * caller speaks the text with another voice).
     */
    private fun playClip(bytes: ByteArray?, rate: Float, result: MethodChannel.Result) {
        if (bytes == null || bytes.isEmpty()) {
            result.success(PLAY_FAILED)
            return
        }
        playStop()
        val generation = ++playGeneration
        Thread {
            var code = PLAY_FAILED
            try {
                val clip = decodeClip(bytes)
                code = when {
                    generation != playGeneration -> PLAY_STOPPED
                    clip == null -> PLAY_FAILED
                    else -> playPcm(clip.first, clip.second, rate, generation)
                }
            } catch (e: Exception) {
                code = PLAY_FAILED
            }
            main.post { result.success(code) }
        }.also { it.name = "percipere-clip" }.start()
    }

    /** Decodes mp3 (or any format Android knows) to mono floats and its sample rate. */
    private fun decodeClip(bytes: ByteArray): Pair<FloatArray, Int>? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(object : MediaDataSource() {
                override fun readAt(position: Long, buffer: ByteArray, offset: Int, size: Int): Int {
                    if (position >= bytes.size) return -1
                    val n = minOf(size, bytes.size - position.toInt())
                    System.arraycopy(bytes, position.toInt(), buffer, offset, n)
                    return n
                }

                override fun getSize(): Long = bytes.size.toLong()

                override fun close() {}
            })
            var index = -1
            var format: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    index = i
                    format = f
                    break
                }
            }
            if (index < 0 || format == null) return null
            extractor.selectTrack(index)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            val decoder = MediaCodec.createDecoderByType(mime)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()

            var sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            var out = ShortArray(sampleRate * 4)
            var count = 0
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            val deadline = System.currentTimeMillis() + 10_000
            while (!outputDone && System.currentTimeMillis() < deadline) {
                if (!inputDone) {
                    val inIndex = decoder.dequeueInputBuffer(10_000)
                    if (inIndex >= 0) {
                        val buf = decoder.getInputBuffer(inIndex)!!
                        val n = extractor.readSampleData(buf, 0)
                        if (n < 0) {
                            decoder.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(inIndex, 0, n, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val outIndex = decoder.dequeueOutputBuffer(info, 10_000)
                if (outIndex >= 0) {
                    val buf = decoder.getOutputBuffer(outIndex)!!
                    buf.position(info.offset)
                    buf.limit(info.offset + info.size)
                    val shorts = buf.order(java.nio.ByteOrder.nativeOrder()).asShortBuffer()
                    val n = shorts.remaining()
                    if (count + n > out.size) out = out.copyOf(max(out.size * 2, count + n))
                    shorts.get(out, count, n)
                    count += n
                    decoder.releaseOutputBuffer(outIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                } else if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = decoder.outputFormat
                    sampleRate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = f.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                }
            }
            if (!outputDone || count == 0 || channels < 1) return null
            val frames = count / channels
            val mono = FloatArray(frames) { frame ->
                var sum = 0f
                for (c in 0 until channels) sum += out[frame * channels + c] / 32768f
                sum / channels
            }
            return Pair(mono, sampleRate)
        } catch (e: Exception) {
            return null
        } finally {
            try {
                codec?.stop()
            } catch (e: Exception) {
                // Not started.
            }
            codec?.release()
            extractor.release()
        }
    }

    /**
     * Plays [samples] on this thread until they are heard or [playStop] is
     * called. Returns [PLAY_DONE], [PLAY_STOPPED] or [PLAY_FAILED].
     */
    private fun playPcm(samples: FloatArray, sampleRate: Int, rate: Float, generation: Int): Int {
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
        } ?: return PLAY_FAILED
        synchronized(this) {
            if (generation != playGeneration) {
                out.release()
                return PLAY_STOPPED
            }
            track = out
            // Under the same lock as the generation check: a stop that
            // lands in between can't leave the focus held (it used to stay
            // requested, ducking other sound until the next play).
            requestFocus(generation)
        }
        val speed = rate.coerceIn(0.5f, 2f)
        try {
            if (speed != 1f && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    out.playbackParams = PlaybackParams().setSpeed(speed)
                } catch (e: Exception) {
                    // Normal speed.
                }
            }
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
            val deadline = System.currentTimeMillis() +
                (pcm.size * 1000L / sampleRate / speed).toLong() + 1000
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
            synchronized(this) {
                if (focusOwner == generation) abandonFocus()
            }
        }
        return if (finished) PLAY_DONE else PLAY_STOPPED
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
            abandonFocus()
        }
    }

    private fun requestFocus(generation: Int) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        abandonFocus() // never two requests held at once
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
            focusOwner = generation
        } catch (e: Exception) {
            // Plays without focus.
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val request = focus ?: return
        focus = null
        focusOwner = -1
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

    private companion object {
        const val SOURCE_RECOGNITION = "voiceRecognition"
        const val SOURCE_COMMUNICATION = "voiceCommunication"
        const val PLAY_DONE = 1
        const val PLAY_STOPPED = 0
        const val PLAY_FAILED = -1
    }
}
