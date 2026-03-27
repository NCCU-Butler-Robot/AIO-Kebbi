import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kNotifTitle = 'fcm_notif_title';
const _kNotifBody = 'fcm_notif_body';
const _kNotifCallToken = 'fcm_notif_call_token';
const _kNotifCallerName = 'fcm_notif_caller_name';

/// 背景訊息 handler — 必須是 top-level function，跑在獨立 isolate
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.data}');
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    // 用 SharedPreferences 跨 isolate 持久化，讓 foreground 恢復後能讀到
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNotifTitle, message.notification?.title ?? '來電通知');
    await prefs.setString(_kNotifBody, message.notification?.body ?? '');
    await prefs.setString(_kNotifCallToken, data['call_token'] ?? '');
    await prefs.setString(_kNotifCallerName, data['caller_name'] ?? '');
  }
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

    // App 啟動時從 SharedPreferences 恢復背景收到的通知
    await loadPersistedNotif();

    // 前台收到：存資料，不跳轉
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

  /// 從 SharedPreferences 讀取背景 isolate 寫入的通知資料（可從外部呼叫）
  Future<void> loadPersistedNotif() async {
    final prefs = await SharedPreferences.getInstance();
    final callToken = prefs.getString(_kNotifCallToken);
    if (callToken != null && callToken.isNotEmpty) {
      latestNotif.value = FcmNotifData(
        title: prefs.getString(_kNotifTitle),
        body: prefs.getString(_kNotifBody),
        callToken: callToken,
        callerName: prefs.getString(_kNotifCallerName),
      );
    }
  }

  void Function(String newToken)? _onTokenRefreshed;

  void setTokenRefreshCallback(void Function(String) cb) {
    _onTokenRefreshed = cb;
  }

  Future<void> _storeMessage(RemoteMessage message) async {
    debugPrint('[FCM] Message received: ${message.data}');
    final data = message.data;
    if (data['type'] == 'incoming_call') {
      final notif = FcmNotifData(
        title: message.notification?.title,
        body: message.notification?.body,
        callToken: data['call_token'] as String?,
        callerName: data['caller_name'] as String?,
      );
      latestNotif.value = notif;

      // 同步寫入 SharedPreferences 確保持久化
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kNotifTitle, notif.title ?? '');
      await prefs.setString(_kNotifBody, notif.body ?? '');
      await prefs.setString(_kNotifCallToken, notif.callToken ?? '');
      await prefs.setString(_kNotifCallerName, notif.callerName ?? '');
    }
  }

  Future<void> _storeAndNavigate(RemoteMessage message) async {
    await _storeMessage(message);
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
