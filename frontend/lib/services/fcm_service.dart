import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 背景訊息 handler — 必須是 top-level function
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.data}');
  // 只能記錄，無法導航；foreground / tap 才處理 UI
}

class FcmService {
  FcmService._();
  static final FcmService I = FcmService._();

  /// 收到 incoming_call 時的 callback → (callToken, callerName)
  void Function(String callToken, String callerName)? onIncomingCall;

  /// 任何 FCM 訊息到達時的 callback → title, body, data（供 UI 顯示 alert）
  void Function(String? title, String? body, Map<String, dynamic> data)? onRawMessage;

  /// 初始化 FCM，回傳 FCM token（供後端註冊用）
  Future<String?> initialize() async {
    // 背景 handler 必須在 Firebase.initializeApp 之後立即設定
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // 請求通知權限（Android 13+ 需要）
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 前台訊息
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // 背景 → 用戶點通知開 App
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

    // App 終止狀態 → 點通知啟動
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessage(initial);

    // 取得 FCM token
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] Token: $token');

    // Token 更新時重新取得
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      // 由外部決定是否重新註冊
      _onTokenRefreshed?.call(newToken);
    });

    return token;
  }

  void Function(String newToken)? _onTokenRefreshed;

  void setTokenRefreshCallback(void Function(String) cb) {
    _onTokenRefreshed = cb;
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint('[FCM] Message received: ${message.data}');
    final data = message.data;

    // 通知所有 UI 顯示收到的完整內容
    onRawMessage?.call(
      message.notification?.title,
      message.notification?.body,
      data,
    );

    if (data['type'] == 'incoming_call') {
      final callToken = data['call_token'] as String? ?? '';
      final callerName = data['caller_name'] as String? ?? '未知來電';
      if (callToken.isNotEmpty) {
        onIncomingCall?.call(callToken, callerName);
      }
    }
  }
}
