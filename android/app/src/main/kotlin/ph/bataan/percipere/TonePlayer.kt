package ph.bataan.percipere

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import kotlin.math.PI
import kotlin.math.min
import kotlin.math.sin

/**
 * The app's short tones ("heard", "listening", "stopped"), made here as a
 * fixed number of samples and played from a static buffer, so a tone always
 * ends: it is released after its own length at the latest. (2026-10-18:
 * Android's `ToneGenerator` sometimes kept sounding on the tablet — the
 * "stuck" listening tone.) [play] answers once the tone has ended, so the
 * app can keep the microphone muted until then.
 */
class TonePlayer {
    private val main = Handler(Looper.getMainLooper())
    private val cache = HashMap<String, ShortArray>()
    private var track: AudioTrack? = null
    private var generation = 0

    /** Plays tone [name]; [done] is called once, when it ended (or failed). */
    fun play(name: String, done: (Boolean) -> Unit) {
        val parts = TONES[name]
        if (parts == null) {
            done(false)
            return
        }
        stop()
        val pcm = cache.getOrPut(name) { synth(parts) }
        val mine = ++generation
        val out = try {
            AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(RATE)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build()
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(pcm.size * 2)
                .build()
        } catch (e: Exception) {
            null
        }
        if (out == null) {
            done(false)
            return
        }
        try {
            out.write(pcm, 0, pcm.size)
            out.play()
            track = out
        } catch (e: Exception) {
            out.release()
            done(false)
            return
        }
        // Released after its own length whatever happens: it can't go on.
        val millis = pcm.size * 1000L / RATE
        main.postDelayed({
            if (mine == generation) release()
            done(true)
        }, millis + 30)
    }

    /** Silences the tone that is playing, if any. */
    fun stop() {
        generation++
        release()
    }

    private fun release() {
        val out = track ?: return
        track = null
        try {
            out.stop()
        } catch (e: Exception) {
            // Not playing any more.
        }
        out.release()
    }

    private companion object {
        const val RATE = 22050
        const val VOLUME = 0.32

        /** Each tone: (frequency in Hz, 0 for a pause; length in ms). */
        val TONES = mapOf(
            "heard" to listOf(880 to 70),
            "listening" to listOf(1320 to 18, 0 to 12, 1320 to 18),
            "stopped" to listOf(440 to 60)
        )

        /** The samples, each part faded in and out (no clicks). */
        fun synth(parts: List<Pair<Int, Int>>): ShortArray {
            val total = parts.sumOf { it.second } * RATE / 1000
            val out = ShortArray(total)
            var offset = 0
            for ((freq, ms) in parts) {
                val n = ms * RATE / 1000
                val fade = min(n / 4, RATE / 200) // up to 5 ms
                for (i in 0 until n) {
                    if (offset + i >= total) break
                    if (freq == 0) continue
                    val edge = min(i, n - 1 - i)
                    val gain = if (fade > 0 && edge < fade) edge.toDouble() / fade else 1.0
                    val s = sin(2 * PI * freq * i / RATE) * VOLUME * gain
                    out[offset + i] = (s * Short.MAX_VALUE).toInt().toShort()
                }
                offset += n
            }
            return out
        }
    }
}
