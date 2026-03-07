## 尚未完成

| 功能模組                    | 串接狀態    | 說明                                                                                            |
| ----------------------- | ------- | --------------------------------------------------------------------------------------------- |
| 使用者登入 (Login)          | 🟡 部分完成 | 已實作 API 呼叫架構 (`ApiService.login()`)，但目前使用 `devBypassLogin` 開發模式，登入流程使用假 token 直接登入，尚未完全依賴後端驗證 |
| WebSocket 即時連線          | ✅ 已完成   | 已實作 WebSocket 連線 (`WebSocketService`)，並可透過 token 與 uuid 連線至後端即時服務                             |
| 通話監控 (Call Monitoring)  | ✅ 已完成   | 前端可接收 WebSocket 事件，例如 `detectionStarted`、`detectionEnded`、`incomingCallRequest`、`callEnded` 等 |
| 詐騙偵測事件顯示             | ✅ 已完成   | 前端已能解析後端回傳的詐騙事件 (`scamDecision`) 並顯示於 UI                                                      |
| 通話結束 API                | ✅ 已完成   | 已實作 `/api/call/hangup/` API 呼叫                                                                |
| Butler AI 對話             | ❌ 尚未完成  | 目前為 UI Demo，對話內容為模擬資料，尚未串接 `/api/chat/` 後端服務                                                  |
| 語音回覆 (AI 語音)           | ❌ 尚未完成  | Butler 語音回覆尚未接入後端 TTS 或音訊回傳                                                                   |
| 食物辨識 (Food Recognition) |  🟡 部分完成 | 目前可開啟外部網址示範，尚未實作圖片上傳與 `/api/food-recognition/` API 呼叫                                         |                                                   |
| 音訊錄製與播放                | 🟡 部分完成 | 已整合 `flutter_sound` 與 `audioplayers`，但語音串流仍需後端完整整合                                            |



## 專案結構

```
├── README.md
├── analysis_options.yaml
├── android
│   ├── app
│   │   ├── build.gradle.kts
│   │   ├── libs
│   │   ├── src
│   │   └── upload-keystore.jks
│   ├── build.gradle.kts
│   ├── gradle
│   │   └── wrapper
│   ├── gradle.properties
│   ├── gradlew
│   ├── gradlew.bat
│   ├── key.properties
│   ├── local.properties
│   └── settings.gradle.kts
├── assets
│   ├── filtered_terms.json
│   ├── image
│   │   ├── Direct graph_1.png
│   │   ├── Direct graph_2.png
│   │   ├── Direct graph_3.png
│   │   ├── logo.png
│   │   └── logo_name.png
│   ├── mock_call.json
│   ├── mock_seq.json
│   └── sounds
│       ├── Fraud.mp3
│       ├── Not_Fraud.mp3
│       └── alert.mp3
├── build
│   ├── app
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── kotlin
│   │   ├── kotlinToolingMetadata
│   │   ├── outputs
│   │   └── tmp
│   ├── audioplayers_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── kotlin
│   │   ├── outputs
│   │   └── tmp
│   ├── device_info_plus
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── kotlin
│   │   ├── outputs
│   │   └── tmp
│   ├── flutter_plugin_android_lifecycle
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── flutter_secure_storage
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── flutter_sound
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── image_picker_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── native_assets
│   │   └── android
│   ├── path_provider_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── permission_handler_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── record_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── kotlin
│   │   ├── outputs
│   │   └── tmp
│   ├── url_launcher_android
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   ├── vibration
│   │   ├── generated
│   │   ├── intermediates
│   │   ├── outputs
│   │   └── tmp
│   └── webview_flutter_android
│       ├── generated
│       ├── intermediates
│       ├── kotlin
│       ├── outputs
│       └── tmp
├── devtools_options.yaml
├── ios
│   ├── Flutter
│   │   ├── AppFrameworkInfo.plist
│   │   ├── Debug.xcconfig
│   │   ├── Generated.xcconfig
│   │   ├── Release.xcconfig
│   │   ├── ephemeral
│   │   └── flutter_export_environment.sh
│   ├── Podfile
│   ├── Runner
│   │   ├── AppDelegate.swift
│   │   ├── Assets.xcassets
│   │   ├── Base.lproj
│   │   ├── GeneratedPluginRegistrant.h
│   │   ├── GeneratedPluginRegistrant.m
│   │   ├── Info.plist
│   │   └── Runner-Bridging-Header.h
│   ├── Runner.xcodeproj
│   │   ├── project.pbxproj
│   │   ├── project.xcworkspace
│   │   └── xcshareddata
│   ├── Runner.xcworkspace
│   │   ├── contents.xcworkspacedata
│   │   └── xcshareddata
│   └── RunnerTests
│       └── RunnerTests.swift
├── lib
│   ├── config
│   │   └── api_config.dart
│   ├── constants.dart
│   ├── di
│   │   └── service_locator.dart
│   ├── main.dart
│   ├── models
│   │   ├── login_models.dart
│   │   ├── scam_event.dart
│   │   ├── stats_record.dart
│   │   └── ws_message.dart
│   ├── pages
│   │   ├── butler_chat_page.dart
│   │   ├── call_page.dart
│   │   ├── food_recognition_page.dart
│   │   ├── login_page.dart
│   │   ├── menu_page.dart
│   │   ├── monitor_page.dart
│   │   ├── stats_page.dart
│   │   ├── webview_page.dart
│   │   └── welcome_page.dart
│   ├── providers
│   │   ├── auth_provider.dart
│   │   └── call_provider.dart
│   ├── services
│   │   ├── alert_service.dart
│   │   ├── api_service.dart
│   │   ├── audio_service.dart
│   │   ├── kebbi_service.dart
│   │   ├── secure_storage.dart
│   │   └── websocket_service.dart
│   └── widgets
│       └── auth_guard.dart
├── pubspec.lock
├── pubspec.yaml
├── test
└── web
    ├── favicon.png
    ├── icons
    │   ├── Icon-192.png
    │   ├── Icon-512.png
    │   ├── Icon-maskable-192.png
    │   └── Icon-maskable-512.png
    ├── index.html
    └── manifest.json
```

---

# Flutter 基本設定檔

### README.md
專案說明文件，包含系統架構、功能介紹與使用方式。

### pubspec.yaml
Flutter 專案的核心設定檔，負責：

- 宣告依賴套件 (dependencies)
- 設定 assets 資源
- 設定版本資訊

### pubspec.lock
鎖定依賴套件版本，確保不同環境安裝的套件版本一致。

### analysis_options.yaml
Dart 靜態程式分析設定，例如：

- lint 規則
- 程式碼風格檢查

### devtools_options.yaml
Flutter DevTools 的設定檔。

---

# 平台相關程式

Flutter 是跨平台框架，因此會有 Android、iOS 與 Web 三種平台的設定。

---

## android/

Android 原生專案設定。

### android/app
Android App 的主要模組，包含：

- AndroidManifest
- App build 設定
- 原生 Android 程式碼

重要檔案：

| 檔案 | 用途 |
|-----|-----|
build.gradle.kts | Android App 編譯設定 |
upload-keystore.jks | APK 簽章憑證 |
src | Android 原生程式碼 |

---

### android/gradle
Gradle 建置系統設定。

---

### key.properties
Android 應用程式簽章設定。

---

### local.properties
本機 Android SDK 路徑設定。

---

## ios/

iOS 原生專案設定。

主要內容包含：

| 目錄 | 用途 |
|-----|-----|
Runner | iOS App 原生程式碼 |
Runner.xcodeproj | Xcode 專案設定 |
Podfile | iOS 套件管理 |

---

## web/

Flutter Web 版本相關檔案。

| 檔案 | 用途 |
|-----|-----|
index.html | Web App 入口頁面 |
manifest.json | PWA 設定 |
icons | Web App 圖示 |

---

# Assets 資源 (assets/)

用於存放應用程式所需的靜態資源。

---

## filtered_terms.json
詐騙關鍵字與過濾詞資料。

主要用途：

- 詐騙對話偵測
- 敏感詞分析

---

## mock_call.json
模擬電話對話資料，用於：

- 測試詐騙偵測
- Demo 展示

---

## mock_seq.json
模擬對話流程資料。

---

## image/

存放 UI 圖片資源：

| 檔案 | 用途 |
|-----|-----|
logo.png | App Logo |
logo_name.png | App 標題 Logo |
Direct graph_* | 系統流程圖或展示圖片 |

---

## sounds/

系統音效：

| 音效 | 用途 |
|-----|-----|
Fraud.mp3 | 偵測詐騙警告音 |
Not_Fraud.mp3 | 安全提示音 |
alert.mp3 | 系統提醒音 |

---

# build/

Flutter 編譯時自動產生的資料夾，例如：

- APK
- Plugin build
- 編譯暫存

此資料夾通常 **不會加入 Git 版本控制**。

---

# lib（主要程式碼）

這是 Flutter App 的核心程式碼所在。

---

## main.dart

Flutter App 入口程式。

主要負責：

- 啟動應用程式
- 初始化服務
- 設定 Router
- 建立 Provider

---

## constants.dart

定義全域常數，例如：

- API URL
- 系統常數
- UI 設定

---

# config/

系統設定。

### api_config.dart

定義：

- API endpoint
- WebSocket URL
- Backend server address

---

# di/

Dependency Injection（依賴注入）。

### service_locator.dart

使用 **GetIt** 管理：

- Service 實例
- 全域單例

讓整個 App 可以方便存取各種服務。

---

# models/

資料模型 (Data Models)。

用於表示系統資料結構。

| 檔案 | 用途 |
|-----|-----|
login_models.dart | 使用者登入資料 |
scam_event.dart | 詐騙事件資料 |
stats_record.dart | 統計資料 |
ws_message.dart | WebSocket 訊息格式 |

---

# pages/

App 各個畫面 (UI Screens)。

| Page | 功能 |
|-----|-----|
welcome_page.dart | App 歡迎畫面 |
menu_page.dart | 主選單 |
login_page.dart | 登入畫面 |
call_page.dart | 通話監控畫面 |
butler_chat_page.dart | AI Butler 對話 |
monitor_page.dart | 詐騙監控 |
stats_page.dart | 統計分析 |
food_recognition_page.dart | 食物辨識 Demo |
webview_page.dart | WebView 整合 |

---

# providers/

Flutter 狀態管理 (State Management)。

使用 Provider 管理應用狀態。

| Provider | 用途 |
|-----|-----|
auth_provider.dart | 使用者登入狀態 |
call_provider.dart | 通話狀態管理 |

---

# services/

系統服務層 (Business Logic Layer)。

負責與外部系統互動。

| Service | 功能 |
|-----|-----|
alert_service.dart | 系統警告 |
api_service.dart | REST API |
audio_service.dart | 音訊播放 |
kebbi_service.dart | Kebbi 機器人控制 |
secure_storage.dart | 安全資料儲存 |
websocket_service.dart | 即時通訊 |

---

# widgets/

可重複使用的 UI 元件。

### auth_guard.dart

用於：

- 檢查登入狀態
- 控制頁面存取權限

---

# test/

Flutter 測試資料夾，用於：

- Widget Test
- Unit Test

---


# 技術使用

本專案主要技術：

- Flutter
- Dart
- Provider
- WebSocket
- REST API
- Audio Processing
- Kebbi Robot Integration
