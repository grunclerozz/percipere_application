package ph.bataan.percipere

import android.app.Activity
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.elevenlabs.AgentOverrides
import io.elevenlabs.ConversationClient
import io.elevenlabs.ConversationConfig
import io.elevenlabs.ConversationSession
import io.elevenlabs.Language
import io.elevenlabs.Overrides
import io.elevenlabs.TtsOverrides
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Bridge between the Flutter app and the ElevenLabs voice agent ("Percy").
 *
 * The agent's client tools are all answered in Dart: every tool call is
 * forwarded as an event (no tool is registered here, so the SDK reports them
 * as "unhandled") and Dart sends the result back with `toolResult`. This
 * keeps the app's commands in one place (the Dart command bus).
 *
 * Channels: `ph.bataan.percipere/assistant` (start, end, toolResult,
 * context) and `ph.bataan.percipere/assistant_events` (status, mode,
 * toolCall, user, agent, disconnected, error).
 */
class AssistantBridge(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val main = Handler(Looper.getMainLooper())
    private var session: ConversationSession? = null
    private var events: EventChannel.EventSink? = null

    init {
        MethodChannel(messenger, "ph.bataan.percipere/assistant").setMethodCallHandler(this)
        EventChannel(messenger, "ph.bataan.percipere/assistant_events").setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> start(call, result)
            "end" -> scope.launch {
                try {
                    session?.endSession()
                } catch (e: Exception) {
                    Log.w(TAG, "endSession failed", e)
                }
                session = null
                result.success(null)
            }
            "toolResult" -> {
                val id = call.argument<String>("id")
                val text = call.argument<String>("result") ?: ""
                val isError = call.argument<Boolean>("isError") ?: false
                val s = session
                if (id == null || s == null) {
                    result.success(false)
                } else {
                    try {
                        s.sendToolResult(id, text, isError)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.w(TAG, "sendToolResult failed", e)
                        result.success(false)
                    }
                }
            }
            "context" -> {
                val text = call.argument<String>("text")
                if (text != null) {
                    try {
                        session?.sendContextualUpdate(text)
                    } catch (e: Exception) {
                        Log.w(TAG, "sendContextualUpdate failed", e)
                    }
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        if (session != null) {
            result.error("busy", "A conversation is already running", null)
            return
        }
        val agentId = call.argument<String>("agentId")?.takeIf { it.isNotBlank() }
        val token = call.argument<String>("conversationToken")?.takeIf { it.isNotBlank() }
        if (agentId == null && token == null) {
            result.error("config", "No agent id or conversation token", null)
            return
        }
        val language = call.argument<String>("language")?.let { Language.fromCode(it) }
        val firstMessage = call.argument<String>("firstMessage")?.takeIf { it.isNotBlank() }
        val voiceId = call.argument<String>("voiceId")?.takeIf { it.isNotBlank() }
        val variables = call.argument<Map<String, Any>>("dynamicVariables")

        val config = ConversationConfig(
            agentId = if (token == null) agentId else null,
            conversationToken = token,
            userId = call.argument<String>("userId"),
            overrides = Overrides(
                agent = AgentOverrides(firstMessage = firstMessage, language = language),
                tts = voiceId?.let { TtsOverrides(voiceId = it) },
            ),
            dynamicVariables = variables,
            onConnect = { id -> emit(mapOf("type" to "connected", "id" to id)) },
            onStatusChange = { status ->
                emit(mapOf("type" to "status", "value" to status.name.lowercase()))
            },
            onModeChange = { mode ->
                emit(mapOf("type" to "mode", "value" to mode.name.lowercase()))
            },
            onUnhandledClientToolCall = { tool ->
                emit(
                    mapOf(
                        "type" to "toolCall",
                        "id" to tool.toolCallId,
                        "name" to tool.toolName,
                        "parameters" to plain(tool.parameters),
                        "expectsResponse" to tool.expectsResponse,
                    )
                )
            },
            onUserTranscriptEvent = { text, _ -> emit(mapOf("type" to "user", "text" to text)) },
            onAgentResponseEvent = { text, _ -> emit(mapOf("type" to "agent", "text" to text)) },
            onDisconnect = { details ->
                session = null
                emit(mapOf("type" to "disconnected", "reason" to details.reason))
            },
            onError = { code, message ->
                emit(mapOf("type" to "error", "code" to code, "message" to (message ?: "")))
            },
        )
        scope.launch {
            try {
                session = ConversationClient.startSession(config, activity)
                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "startSession failed", e)
                session = null
                result.error("start_failed", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    /** SDK callbacks may run on other threads; events go out on the main one. */
    private fun emit(event: Map<String, Any?>) {
        main.post { events?.success(event) }
    }

    /** Tool parameters as plain maps, lists, strings, numbers and booleans. */
    private fun plain(value: Any?): Any? = when (value) {
        null, is String, is Boolean, is Int, is Long, is Double -> value
        is Number -> value.toDouble()
        is Map<*, *> -> value.entries.associate { (k, v) -> k.toString() to plain(v) }
        is Iterable<*> -> value.map { plain(it) }
        else -> value.toString()
    }

    /** Ends any conversation; call when the activity is destroyed. */
    fun dispose() {
        val s = session
        session = null
        if (s != null) {
            scope.launch {
                try {
                    s.endSession()
                } catch (e: Exception) {
                    Log.w(TAG, "endSession on dispose failed", e)
                }
                scope.cancel()
            }
        } else {
            scope.cancel()
        }
    }

    companion object {
        private const val TAG = "PercipereAssistant"
    }
}
