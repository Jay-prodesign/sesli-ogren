package com.sesliogren.proof.r7_p1_runtime_proof

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.ConnectivityManager
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.speech.tts.Voice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private val channelName = "sesliogren/r7_native_tts_capture"
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var ttsInitError: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        tts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                ttsReady = true
                ttsInitError = null
            } else {
                ttsReady = false
                ttsInitError = "TextToSpeech init status=$status"
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listTurkishVoices" -> listTurkishVoices(result)
                "getNetworkState" -> result.success(networkState())
                "getEvidenceDirectory" -> result.success(evidenceDirectory().absolutePath)
                "synthesize" -> {
                    val text = call.argument<String>("text")
                    val item = call.argument<String>("item")
                    val voiceId = call.argument<String>("voiceId")
                    if (text.isNullOrBlank() || item.isNullOrBlank() || voiceId.isNullOrBlank()) {
                        result.error("BAD_ARGUMENTS", "text, item and voiceId are required", null)
                    } else {
                        synthesize(text, item, voiceId, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requireReady(result: MethodChannel.Result): TextToSpeech? {
        val engine = tts
        if (!ttsReady || engine == null) {
            result.error(
                "TTS_NOT_READY",
                ttsInitError ?: "TextToSpeech is still initializing; retry.",
                null,
            )
            return null
        }
        return engine
    }

    private fun listTurkishVoices(result: MethodChannel.Result) {
        val engine = requireReady(result) ?: return
        val rows = engine.voices
            .orEmpty()
            .filter { it.locale.language.equals("tr", ignoreCase = true) }
            .sortedWith(compareBy<Voice>({ it.isNetworkConnectionRequired }, { -it.quality }, { it.name }))
            .map { voice ->
                mapOf(
                    "platform" to "android",
                    "id" to voice.name,
                    "name" to voice.name,
                    "locale" to voice.locale.toLanguageTag(),
                    "qualityTier" to qualityLabel(voice.quality),
                    "qualityRaw" to voice.quality,
                    "latencyRaw" to voice.latency,
                    "networkRequired" to voice.isNetworkConnectionRequired,
                    "features" to voice.features.orEmpty().sorted(),
                    "ttsEngineOrPackage" to (engine.defaultEngine ?: "unknown"),
                    "providerModelVersion" to engineVersion(engine.defaultEngine),
                    "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                    "osVersion" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
                )
            }
        result.success(rows)
    }

    private fun networkState(): Map<String, Any> {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val active = manager.activeNetwork
        val capabilities = active?.let { manager.getNetworkCapabilities(it) }
        val internet = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) == true
        val validated = capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) == true
        val offline = active == null
        return mapOf(
            "offline" to offline,
            "method" to "Android ConnectivityManager active-network capability gate",
            "detail" to if (offline) {
                "No active network is reported."
            } else {
                "An active network is still present; disable Wi-Fi/cellular before capture."
            },
        )
    }

    private fun synthesize(
        text: String,
        item: String,
        voiceId: String,
        result: MethodChannel.Result,
    ) {
        val engine = requireReady(result) ?: return
        val state = networkState()
        if (state["offline"] != true) {
            result.error(
                "NETWORK_NOT_OFFLINE",
                "Native benchmark requires network-disabled capture. ${state["detail"]}",
                null,
            )
            return
        }

        if (text.length > TextToSpeech.getMaxSpeechInputLength()) {
            result.error(
                "TEXT_TOO_LONG",
                "Corpus item exceeds Android TextToSpeech max input length.",
                null,
            )
            return
        }

        val voice = engine.voices.orEmpty().firstOrNull { it.name == voiceId }
        if (voice == null) {
            result.error("VOICE_NOT_FOUND", "Voice $voiceId is no longer available.", null)
            return
        }
        if (!voice.locale.language.equals("tr", ignoreCase = true)) {
            result.error("VOICE_NOT_TURKISH", "Selected voice is not Turkish.", null)
            return
        }
        if (voice.isNetworkConnectionRequired) {
            result.error(
                "VOICE_REQUIRES_NETWORK",
                "Selected Android voice requires a network connection.",
                null,
            )
            return
        }
        if (engine.setVoice(voice) != TextToSpeech.SUCCESS) {
            result.error("VOICE_SET_FAILED", "Android TTS rejected voice $voiceId.", null)
            return
        }

        val startedWall = isoNow()
        val startedElapsed = SystemClock.elapsedRealtime()
        val safeVoice = voice.name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val file = File(
            evidenceDirectory(),
            "${item.uppercase(Locale.ROOT)}-${safeVoice}-${System.currentTimeMillis()}.wav",
        )
        val utteranceId = "r7-${item}-${System.nanoTime()}"

        engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(id: String?) = Unit

            override fun onDone(id: String?) {
                if (id != utteranceId) return
                val completionMs = SystemClock.elapsedRealtime() - startedElapsed
                try {
                    val durationMs = audioDurationMs(file)
                    val payload = mapOf(
                        "platform" to "android",
                        "deviceModel" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                        "osVersion" to "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})",
                        "ttsEngineOrPackage" to (engine.defaultEngine ?: "unknown"),
                        "providerModelVersion" to engineVersion(engine.defaultEngine),
                        "voiceId" to voice.name,
                        "locale" to voice.locale.toLanguageTag(),
                        "qualityTier" to qualityLabel(voice.quality),
                        "networkRequirement" to "offline_capable",
                        "captureMethod" to
                            "Android TextToSpeech.synthesizeToFile on physical device with network-disabled gate",
                        "format" to "wav/native-engine-output",
                        "durationMs" to durationMs,
                        "generationStartedAt" to startedWall,
                        "fullCompletionLatencyMs" to completionMs,
                        "inputTextSha256" to sha256(text.toByteArray(Charsets.UTF_8)),
                        "inputCharacterCount" to text.codePointCount(0, text.length),
                        "inputBytes" to text.toByteArray(Charsets.UTF_8).size,
                        "audioPath" to file.absolutePath,
                        "audioSha256" to sha256(file.readBytes()),
                    )
                    runOnUiThread { result.success(payload) }
                } catch (error: Throwable) {
                    runOnUiThread {
                        result.error("CAPTURE_FINALIZE_FAILED", error.message, null)
                    }
                }
            }

            @Deprecated("Deprecated in Java")
            override fun onError(id: String?) {
                if (id == utteranceId) {
                    runOnUiThread {
                        result.error("SYNTHESIS_FAILED", "Android TTS synthesis failed.", null)
                    }
                }
            }

            override fun onError(id: String?, errorCode: Int) {
                if (id == utteranceId) {
                    runOnUiThread {
                        result.error(
                            "SYNTHESIS_FAILED",
                            "Android TTS synthesis failed with errorCode=$errorCode.",
                            null,
                        )
                    }
                }
            }
        })

        val queued = engine.synthesizeToFile(text, Bundle(), file, utteranceId)
        if (queued != TextToSpeech.SUCCESS) {
            result.error("SYNTHESIS_QUEUE_FAILED", "Android TTS did not queue synthesis.", null)
        }
    }

    private fun evidenceDirectory(): File {
        return File(filesDir, "r7-native-tts").apply { mkdirs() }
    }

    private fun audioDurationMs(file: File): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
                ?: 1L
        } finally {
            retriever.release()
        }
    }

    private fun engineVersion(packageName: String?): String {
        if (packageName.isNullOrBlank()) return "unknown-engine-version"
        return try {
            @Suppress("DEPRECATION")
            val info = packageManager.getPackageInfo(packageName, 0)
            "$packageName@${info.versionName ?: "unknown"}"
        } catch (_: Throwable) {
            "$packageName@unknown"
        }
    }

    private fun qualityLabel(quality: Int): String {
        return when (quality) {
            Voice.QUALITY_VERY_HIGH -> "very_high"
            Voice.QUALITY_HIGH -> "high"
            Voice.QUALITY_NORMAL -> "normal"
            Voice.QUALITY_LOW -> "low"
            Voice.QUALITY_VERY_LOW -> "very_low"
            else -> "quality_$quality"
        }
    }

    private fun isoNow(): String {
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date())
    }

    private fun sha256(bytes: ByteArray): String {
        return MessageDigest.getInstance("SHA-256")
            .digest(bytes)
            .joinToString("") { "%02x".format(it) }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
