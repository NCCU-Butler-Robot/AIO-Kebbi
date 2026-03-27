import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kNotifHistoryKey = 'fcm_notif_history';

/// 背景訊息 handler — 必須是 top-level function，跑在獨立 isolate
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.data}');
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kNotifHistoryKey);
    final List<dynamic> history = existing != null ? jsonDecode(existing) : [];
    history.add({
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': data,
    });
    await prefs.setString(_kNotifHistoryKey, jsonEncode(history));
  }
}

/// FCM 通知資料（含完整 data map）
class FcmNotifData {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const FcmNotifData({this.title, this.body, required this.data});

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'data': data,
      };

  factory FcmNotifData.fromJson(Map<String, dynamic> json) => FcmNotifData(
        title: json['title'] as String?,
        body: json['body'] as String?,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
      );
}

class FcmService with WidgetsBindingObserver {
  FcmService._();
  static final FcmService I = FcmService._();

  /// 所有歷史通知（最新在最後）
  final ValueNotifier<List<FcmNotifData>> notifHistory =
      ValueNotifier(const []);

  /// 用戶點通知後的 callback → (callToken, callerName)
  void Function(String callToken, String callerName)? onIncomingCall;

  Future<String?> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // 監聽 App 生命週期，恢復前台時補讀 SharedPreferences
    WidgetsBinding.instance.addObserver(this);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 啟動時讀取歷史
    await loadPersistedNotif();

    // 前台收到：加入歷史，不跳轉
    FirebaseMessaging.onMessage.listen(_storeMessage);

    // 背景 → 用戶點通知：加入歷史 + 跳轉
    FirebaseMessaging.onMessageOpenedApp.listen(_storeAndNavigate);

    // App 終止 → 點通知啟動：加入歷史 + 跳轉
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App 從背景恢復時，補讀背景 isolate 寫入的通知
      loadPersistedNotif();
    }
  }

  /// 從 SharedPreferences 讀取歷史通知並更新 notifHistory
  Future<void> loadPersistedNotif() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // 強制從磁碟重讀，避免主 isolate 快取遮蔽背景 isolate 的寫入
    final raw = prefs.getString(_kNotifHistoryKey);
    if (raw == null) return;
    try {
      final List<dynamic> list = jsonDecode(raw);
      final parsed = list
          .map((e) => FcmNotifData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      notifHistory.value = parsed;
    } catch (e) {
      debugPrint('[FCM] Failed to parse notif history: $e');
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
        data: data,
      );
      final updated = [...notifHistory.value, notif];
      notifHistory.value = updated;

      // 同步寫入 SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kNotifHistoryKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
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
