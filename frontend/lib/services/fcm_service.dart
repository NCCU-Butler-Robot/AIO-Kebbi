import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// 背景訊息 handler — 必須是 top-level function
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.data}');
}

/// 最新一筆 FCM 通知資料
class FcmNotifData {
  final String? title;
  final String? body;
  final String? callToken;
  final String? callerName;

  const FcmNotifData({
    this.title,
    this.body,
    this.callToken,
    this.callerName,
  });
}

class FcmService {
  FcmService._();
  static final FcmService I = FcmService._();

  /// 最新通知資料（供 MonitorPage 等 UI 監聽）
  final ValueNotifier<FcmNotifData?> latestNotif = ValueNotifier(null);

  /// 用戶點通知後的 callback → (callToken, callerName)
  void Function(String callToken, String callerName)? onIncomingCall;

  Future<String?> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 前台收到：只存資料，不跳轉
    FirebaseMessaging.onMessage.listen(_storeMessage);

    // 背景 → 用戶點通知：存資料 + 跳轉
    FirebaseMessaging.onMessageOpenedApp.listen(_storeAndNavigate);

    // App 終止 → 點通知啟動：存資料 + 跳轉
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _storeAndNavigate(initial);

    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('[FCM] Token: $token');

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      _onTokenRefreshed?.call(newToken);
    });

    return token;
  }

  void Function(String newToken)? _onTokenRefreshed;

  void setTokenRefreshCallback(void Function(String) cb) {
    _onTokenRefreshed = cb;
  }

  void _storeMessage(RemoteMessage message) {
    debugPrint('[FCM] Message received: ${message.data}');
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      latestNotif.value = FcmNotifData(
        title: message.notification?.title,
        body: message.notification?.body,
        callToken: data['call_token'] as String?,
        callerName: data['caller_name'] as String?,
      );
    }
  }

  void _storeAndNavigate(RemoteMessage message) {
    _storeMessage(message);
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      final callToken = data['call_token'] as String? ?? '';
      final callerName = data['caller_name'] as String? ?? '未知來電';
      if (callToken.isNotEmpty) {
        onIncomingCall?.call(callToken, callerName);
      }
    }
  }
}
