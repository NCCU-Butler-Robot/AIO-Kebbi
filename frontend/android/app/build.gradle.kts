// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 讀取 key.properties（若存在）
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) {
        load(FileInputStream(f))
    }
}

android {
    // 依你的專案
    namespace = "tw.futuremedialab.frauddetect"
    compileSdk = flutter.compileSdkVersion

    // 固定到相容的 NDK 版本
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = JavaVersion.VERSION_11.toString() }

    defaultConfig {
        applicationId = "tw.futuremedialab.frauddetect"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // —— 只有在 keystore 檔案與參數齊全時才建立 release 簽章 ——
    signingConfigs {
        // 取得 storeFile 路徑字串
        val rawPath = keystoreProperties.getProperty("storeFile")?.trim().orEmpty()

        // 嘗試在常見位置找檔案
        val candidates = listOfNotNull(
            if (rawPath.isNotEmpty()) file(rawPath) else null,                // android/app/<path>
            if (rawPath.isNotEmpty()) rootProject.file(rawPath) else null,   // <root>/<path>
            if (rawPath.isNotEmpty()) rootProject.file("android/$rawPath") else null,
            if (rawPath.isNotEmpty()) rootProject.file("android/app/$rawPath") else null
        )

        val storeFileCandidate = candidates.firstOrNull { it.exists() }
        val hasAllProps = listOf("storePassword", "keyAlias", "keyPassword")
            .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

        if (storeFileCandidate != null && hasAllProps) {
            create("release") {
                storeFile = storeFileCandidate
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            // 若有 release 簽章就共用，沒有就用預設 debug 簽章
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
        getByName("release") {
            // 若沒有成功建立 release 簽章，fallback 到 debug 簽章（可先出測試包）
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            // 之後要開混淆再加：
            // proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }
}

flutter { source = "../.." }

repositories {
    // 你有自家 AAR（NuwaSDK），就保留
    flatDir { dirs("libs") }
}

dependencies {
    implementation(files("libs/NuwaSDK.aar"))
    implementation("com.alphacephei:vosk-android:0.3.47")
    // 其餘依賴由 Flutter 插件自動處理
}
