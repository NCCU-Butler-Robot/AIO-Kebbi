package tw.futuremedialab.frauddetect

import android.content.Context
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
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

    private fun ensureRobotApi() {
        if (robotApi != null) return
        try {
            val clazz = Class.forName("com.nuwarobotics.service.agent.NuwaRobotAPI")

            // 先試 constructor(Context)
            robotApi = try {
                val ctor1 = clazz.getConstructor(Context::class.java)
                ctor1.newInstance(applicationContext)
            } catch (e1: NoSuchMethodException) {
                // 再試 constructor(Context, IClientId)
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
            // 先試 motionPlay(String, boolean)
            try {
                val m = clazz.getMethod("motionPlay", String::class.java, Boolean::class.javaPrimitiveType)
                m.invoke(api, motionName, java.lang.Boolean.FALSE)
                Log.d(TAG, "motionPlay(String, boolean) => $motionName")
                true
            } catch (_: NoSuchMethodException) {
                // 再試 motionPlay(String)
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
            // 有些版本沒有 release()，忽略即可
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
