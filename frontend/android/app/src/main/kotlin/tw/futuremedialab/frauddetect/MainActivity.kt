package tw.futuremedialab.frauddetect

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "kebbi"
        private const val TAG = "[KebbiMain]"
        private const val ACTION_RAISE_RIGHT_ARM = "666_BA_RArmS90"
        private const val VOSK_MODEL_NAME = "vosk-model-small-en-us-0.15"
        private const val VOSK_MODEL_URL =
            "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
    }

    private var robotApi: Any? = null
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // Vosk
    private var voskModel: Model? = null
    private var voskSpeechService: SpeechService? = null
    @Volatile private var voskDownloading = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = ch

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    try {
                        ensureRobotApi()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "init error", t)
                        result.error("INIT_FAIL", t.message, null)
                    }
                }

                "fraud", "safe" -> {
                    try {
                        ensureRobotApi()
                        val ok = playMotion(ACTION_RAISE_RIGHT_ARM)
                        if (ok) result.success(null)
                        else result.error("ACTION_FAIL", "Robot API not ready", null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "action error", t)
                        result.error("ACTION_FAIL", t.message, null)
                    }
                }

                "checkKebbi" -> {
                    ensureRobotApi()
                    result.success(robotApi != null)
                }

                "startSTT" -> {
                    try {
                        ensureRobotApi()
                        val api = robotApi
                        if (api == null) {
                            result.error("NOT_READY", "Robot API not initialized", null)
                        } else {
                            startSTT(api)
                            result.success(null)
                        }
                    } catch (t: Throwable) {
                        Log.e(TAG, "startSTT error", t)
                        result.error("STT_START_FAIL", t.message, null)
                    }
                }

                "stopSTT" -> {
                    try {
                        val api = robotApi
                        if (api != null) stopSTT(api)
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "stopSTT error", t)
                        result.error("STT_STOP_FAIL", t.message, null)
                    }
                }

                "release" -> {
                    try {
                        releaseRobotApi()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "release error", t)
                        result.error("RELEASE_FAIL", t.message, null)
                    }
                }

                // ── Vosk ──────────────────────────────────────────────────────────

                "checkVoskModel" -> {
                    val modelDir = File(filesDir, VOSK_MODEL_NAME)
                    result.success(modelDir.exists() && modelDir.isDirectory)
                }

                "initVosk" -> {
                    initVosk(result)
                }

                "startVoskSTT" -> {
                    try {
                        startVoskSTT()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "startVoskSTT error", t)
                        result.error("VOSK_STT_FAIL", t.message, null)
                    }
                }

                "stopVoskSTT" -> {
                    try {
                        stopVoskSTT()
                        result.success(null)
                    } catch (t: Throwable) {
                        result.error("VOSK_STOP_FAIL", t.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Kebbi STT ──────────────────────────────────────────────────────────────

    private fun startSTT(api: Any) {
        val listenerClass = try {
            Class.forName("com.nuwarobotics.service.agent.VoiceEventListener")
        } catch (t: Throwable) {
            Log.e(TAG, "VoiceEventListener class not found", t)
            throw t
        }

        val proxy = java.lang.reflect.Proxy.newProxyInstance(
            listenerClass.classLoader,
            arrayOf(listenerClass)
        ) { _, method, args ->
            when (method.name) {
                "onSpeech2TextComplete" -> {
                    val text = args?.getOrNull(0) as? String ?: ""
                    val isFinal = args?.getOrNull(1) as? Boolean ?: true
                    Log.d(TAG, "onSpeech2TextComplete: text=$text isFinal=$isFinal")
                    mainHandler.post {
                        methodChannel?.invokeMethod(
                            "onSTTResult",
                            mapOf("text" to text, "isFinal" to isFinal)
                        )
                    }
                }
                "onSpeechState" -> {
                    Log.d(TAG, "onSpeechState: ${args?.getOrNull(0)}")
                }
            }
            null
        }

        try {
            val reg = api.javaClass.getMethod("registerVoiceEventListener", listenerClass)
            reg.invoke(api, proxy)
            Log.d(TAG, "registerVoiceEventListener OK")
        } catch (t: Throwable) {
            Log.w(TAG, "registerVoiceEventListener failed", t)
        }

        try {
            api.javaClass.getMethod("startSpeech2Text").invoke(api)
            Log.d(TAG, "startSpeech2Text OK")
        } catch (_: NoSuchMethodException) {
            try {
                api.javaClass.getMethod("speech2Txt").invoke(api)
                Log.d(TAG, "speech2Txt OK")
            } catch (t: Throwable) {
                Log.e(TAG, "No STT start method found", t)
                throw t
            }
        }
    }

    private fun stopSTT(api: Any) {
        try {
            api.javaClass.getMethod("stopListen").invoke(api)
            Log.d(TAG, "stopListen OK")
        } catch (t: Throwable) {
            Log.w(TAG, "stopListen failed: ${t.message}")
        }
    }

    // ── Vosk offline STT ───────────────────────────────────────────────────────

    private fun initVosk(result: MethodChannel.Result) {
        val modelDir = File(filesDir, VOSK_MODEL_NAME)

        if (modelDir.exists() && modelDir.isDirectory) {
            // Already on disk — just load
            Thread {
                try {
                    if (voskModel == null) {
                        voskModel = Model(modelDir.absolutePath)
                    }
                    Log.d(TAG, "Vosk model loaded from cache")
                    mainHandler.post { result.success(null) }
                } catch (e: Exception) {
                    Log.e(TAG, "Vosk model load error", e)
                    mainHandler.post { result.error("VOSK_LOAD_FAIL", e.message, null) }
                }
            }.start()
            return
        }

        // Guard against concurrent downloads
        if (voskDownloading) {
            result.error("VOSK_BUSY", "Model is already downloading", null)
            return
        }
        voskDownloading = true

        // Download → unzip → load
        Thread {
            val zipFile = File(cacheDir, "$VOSK_MODEL_NAME.zip")
            try {
                // ── Download ─────────────────────────────────────────
                Log.d(TAG, "Downloading Vosk model from $VOSK_MODEL_URL")
                val conn = URL(VOSK_MODEL_URL).openConnection() as HttpURLConnection
                conn.connectTimeout = 15_000
                conn.readTimeout = 60_000
                conn.connect()
                val total = conn.contentLength.toLong()
                Log.d(TAG, "Vosk model size: $total bytes")

                FileOutputStream(zipFile).use { fos ->
                    conn.inputStream.use { input ->
                        val buf = ByteArray(16_384)
                        var downloaded = 0L
                        var lastProgress = -1
                        var n: Int
                        while (input.read(buf).also { n = it } != -1) {
                            fos.write(buf, 0, n)
                            downloaded += n
                            if (total > 0) {
                                val progress = (downloaded * 100 / total).toInt()
                                if (progress != lastProgress) {
                                    lastProgress = progress
                                    mainHandler.post {
                                        methodChannel?.invokeMethod("onVoskProgress", progress)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Unzip ─────────────────────────────────────────────
                Log.d(TAG, "Extracting Vosk model…")
                mainHandler.post { methodChannel?.invokeMethod("onVoskProgress", -1) }
                unzip(zipFile, filesDir)
                zipFile.delete()
                Log.d(TAG, "Vosk model extracted")

                // ── Load ──────────────────────────────────────────────
                voskModel = Model(File(filesDir, VOSK_MODEL_NAME).absolutePath)
                Log.d(TAG, "Vosk model loaded successfully")
                voskDownloading = false
                mainHandler.post { result.success(null) }

            } catch (e: Exception) {
                Log.e(TAG, "initVosk failed", e)
                zipFile.delete()
                voskDownloading = false
                mainHandler.post { result.error("VOSK_INIT_FAIL", e.message, null) }
            }
        }.start()
    }

    private fun startVoskSTT() {
        val model = voskModel ?: throw IllegalStateException("Vosk model not loaded")

        voskSpeechService?.apply { stop(); shutdown() }
        voskSpeechService = null

        val recognizer = Recognizer(model, 16000.0f)
        val service = SpeechService(recognizer, 16000.0f)
        voskSpeechService = service

        service.startListening(object : RecognitionListener {
            override fun onPartialResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "partial") ?: return
                if (text.isBlank()) return
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to false)
                    )
                }
            }

            override fun onResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "text") ?: ""
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to true)
                    )
                }
            }

            override fun onFinalResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "text") ?: ""
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to true)
                    )
                }
            }

            override fun onError(exception: Exception?) {
                Log.e(TAG, "Vosk recognition error", exception)
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to "", "isFinal" to true)
                    )
                }
            }

            override fun onTimeout() {
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to "", "isFinal" to true)
                    )
                }
            }
        })
        Log.d(TAG, "Vosk STT started")
    }

    private fun stopVoskSTT() {
        voskSpeechService?.apply { stop(); shutdown() }
        voskSpeechService = null
        Log.d(TAG, "Vosk STT stopped")
    }

    private fun unzip(zipFile: File, destDir: File) {
        ZipInputStream(zipFile.inputStream()).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val outFile = File(destDir, entry.name)
                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { fos -> zis.copyTo(fos) }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    /** Simple regex-based JSON field extractor for Vosk output. */
    private fun parseVoskJson(json: String?, key: String): String? {
        if (json == null) return null
        return "\"$key\"\\s*:\\s*\"([^\"]*)\"".toRegex().find(json)?.groupValues?.getOrNull(1)
    }

    // ── Robot API ──────────────────────────────────────────────────────────────

    private fun ensureRobotApi() {
        if (robotApi != null) return
        try {
            val clazz = Class.forName("com.nuwarobotics.service.agent.NuwaRobotAPI")

            robotApi = try {
                val ctor1 = clazz.getConstructor(Context::class.java)
                ctor1.newInstance(applicationContext)
            } catch (e1: NoSuchMethodException) {
                try {
                    val idClazz = Class.forName("com.nuwarobotics.service.agent.IClientId")
                    val idCtor = idClazz.getConstructor(String::class.java)
                    val clientId = idCtor.newInstance(applicationContext.packageName)
                    val ctor2 = clazz.getConstructor(Context::class.java, idClazz)
                    ctor2.newInstance(applicationContext, clientId)
                } catch (e2: Throwable) {
                    Log.e(TAG, "No suitable NuwaRobotAPI constructor", e2)
                    null
                }
            }

            Log.d(TAG, "ensureRobotApi: instance=${robotApi != null}")
        } catch (t: Throwable) {
            Log.e(TAG, "ensureRobotApi failed", t)
            robotApi = null
        }
    }

    private fun playMotion(motionName: String): Boolean {
        val api = robotApi ?: return false
        return try {
            val clazz = api.javaClass
            try {
                val m = clazz.getMethod("motionPlay", String::class.java, Boolean::class.javaPrimitiveType)
                m.invoke(api, motionName, java.lang.Boolean.FALSE)
                Log.d(TAG, "motionPlay(String, boolean) => $motionName")
                true
            } catch (_: NoSuchMethodException) {
                val m2 = clazz.getMethod("motionPlay", String::class.java)
                m2.invoke(api, motionName)
                Log.d(TAG, "motionPlay(String) => $motionName")
                true
            }
        } catch (t: Throwable) {
            Log.e(TAG, "motionPlay failed: $motionName", t)
            false
        }
    }

    private fun releaseRobotApi() {
        val api = robotApi ?: return
        try {
            val m = api.javaClass.getMethod("release")
            m.invoke(api)
        } catch (_: NoSuchMethodException) {
        } catch (t: Throwable) {
            Log.w(TAG, "releaseRobotApi invoke error", t)
        } finally {
            robotApi = null
        }
    }

    override fun onDestroy() {
        voskSpeechService?.apply { stop(); shutdown() }
        voskModel?.close()
        releaseRobotApi()
        super.onDestroy()
    }
}
