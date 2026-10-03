package com.sesliogren.proof.r7_p1_runtime_proof

import android.os.Bundle
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val channelName = "sesliogren/native_speech"
    private var channel: MethodChannel? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text")
                        if (text.isNullOrBlank()) {
                            result.error("BAD_ARGUMENTS", "A non-empty text value is required.", null)
                        } else {
                            speak(text, result)
                        }
                    }

                    "stop" -> {
                        tts?.stop()
                        emitSpeaking(false, "stopped")
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        tts = TextToSpeech(applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
        }
    }

    private fun speak(text: String, result: MethodChannel.Result) {
        val engine = tts
        if (!ttsReady || engine == null) {
            result.error("TTS_NOT_READY", "Android TextToSpeech is still initializing.", null)
            return
        }

        val languageResult = engine.setLanguage(Locale.forLanguageTag("tr-TR"))
        if (languageResult == TextToSpeech.LANG_MISSING_DATA ||
            languageResult == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            result.error("TURKISH_VOICE_UNAVAILABLE", "No Turkish system voice is available.", null)
            return
        }

        val utteranceId = "learning-app-${System.nanoTime()}"
        engine.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {
                override fun onStart(id: String?) {
                    if (id == utteranceId) emitSpeaking(true, "started")
                }

                override fun onDone(id: String?) {
                    if (id == utteranceId) emitSpeaking(false, "completed")
                }

                @Deprecated("Deprecated in Java")
                override fun onError(id: String?) {
                    if (id == utteranceId) emitSpeaking(false, "error")
                }

                override fun onError(id: String?, errorCode: Int) {
                    if (id == utteranceId) emitSpeaking(false, "error_$errorCode")
                }
            },
        )

        val queued = engine.speak(text, TextToSpeech.QUEUE_FLUSH, Bundle(), utteranceId)
        if (queued == TextToSpeech.SUCCESS) {
            result.success(null)
        } else {
            result.error("TTS_QUEUE_FAILED", "Android TextToSpeech could not queue the utterance.", null)
        }
    }

    private fun emitSpeaking(speaking: Boolean, reason: String) {
        runOnUiThread {
            channel?.invokeMethod(
                "speechState",
                mapOf(
                    "speaking" to speaking,
                    "reason" to reason,
                ),
            )
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        channel = null
        super.onDestroy()
    }
}
