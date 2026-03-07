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