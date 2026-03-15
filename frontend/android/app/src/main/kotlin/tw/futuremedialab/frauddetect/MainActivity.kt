package tw.futuremedialab.frauddetect

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "kebbi"
        private const val TAG = "[KebbiMain]"
        private const val ACTION_RAISE_RIGHT_ARM = "666_BA_RArmS90"
    }

    private var robotApi: Any? = null
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

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

                else -> result.notImplemented()
            }
        }
    }

    // ── STT ────────────────────────────────────────────────────────────────────

    private fun startSTT(api: Any) {
        val listenerClass = try {
            Class.forName("com.nuwarobotics.service.agent.VoiceEventListener")
        } catch (t: Throwable) {
            Log.e(TAG, "VoiceEventListener class not found", t)
            throw t
        }

        // Create a dynamic proxy that implements VoiceEventListener
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
                // All other interface methods — return null (no-op)
            }
            null
        }

        // Register the listener
        try {
            val reg = api.javaClass.getMethod("registerVoiceEventListener", listenerClass)
            reg.invoke(api, proxy)
            Log.d(TAG, "registerVoiceEventListener OK")
        } catch (t: Throwable) {
            Log.w(TAG, "registerVoiceEventListener failed", t)
        }

        // Start STT — try startSpeech2Text first, fallback to speech2Txt
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
        releaseRobotApi()
        super.onDestroy()
    }
}
