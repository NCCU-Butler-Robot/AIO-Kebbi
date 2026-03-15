import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef STTResultCallback = void Function(String text, bool isFinal);

class KebbiService {
  static const MethodChannel _ch = MethodChannel('kebbi');

  static bool get _isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // STT result callback — set by ButlerChatPage
  static STTResultCallback? _sttCallback;

  /// Call once at app start (or before using STT) to wire up the incoming
  /// method handler that receives onSTTResult events from native.
  static void setupCallbackHandler() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onSTTResult') {
        final text = (call.arguments as Map)['text'] as String? ?? '';
        final isFinal = (call.arguments as Map)['isFinal'] as bool? ?? true;
        _sttCallback?.call(text, isFinal);
      }
    });
  }

  static void setSTTCallback(STTResultCallback? cb) {
    _sttCallback = cb;
  }

  static Future<void> init() async {
    if (!_isAndroidNative) {
      debugPrint('[Kebbi] init skipped (${kIsWeb ? 'web' : defaultTargetPlatform.name})');
      return;
    }
    try {
      await _ch.invokeMethod<void>('init');
    } on MissingPluginException {
      debugPrint('[Kebbi] init skipped: channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] init error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] init error: $e');
    }
  }

  static Future<void> startSTT() async {
    if (!_isAndroidNative) {
      debugPrint('[Kebbi] startSTT skipped (not Android)');
      return;
    }
    try {
      await _ch.invokeMethod<void>('startSTT');
    } on MissingPluginException {
      debugPrint('[Kebbi] startSTT skipped: channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] startSTT error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[Kebbi] startSTT error: $e');
      rethrow;
    }
  }

  static Future<void> stopSTT() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('stopSTT');
    } on MissingPluginException {
      debugPrint('[Kebbi] stopSTT skipped.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] stopSTT error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] stopSTT error: $e');
    }
  }

  static Future<void> doFraudAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('fraud');
    } on MissingPluginException {
      debugPrint('[Kebbi] fraud skipped: channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] fraud error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] fraud error: $e');
    }
  }

  static Future<void> doSafeAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('safe');
    } on MissingPluginException {
      debugPrint('[Kebbi] safe skipped: channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] safe error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] safe error: $e');
    }
  }

  static Future<void> release() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('release');
    } on MissingPluginException {
      debugPrint('[Kebbi] release skipped: channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] release error: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] release error: $e');
    }
  }
}
