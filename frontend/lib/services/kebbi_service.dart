import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef STTResultCallback = void Function(String text, bool isFinal);
typedef VoskProgressCallback = void Function(int percent);

class KebbiService {
  static const MethodChannel _ch = MethodChannel('kebbi');

  static bool get _isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // STT result callback — set by ButlerChatPage
  static STTResultCallback? _sttCallback;

  // Vosk download progress callback — set by ButlerChatPage
  static VoskProgressCallback? _voskProgressCallback;

  /// Wire up incoming method calls from native.
  /// Must be called once before using STT or Vosk.
  static void setupCallbackHandler() {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onSTTResult') {
        final text = (call.arguments as Map)['text'] as String? ?? '';
        final isFinal = (call.arguments as Map)['isFinal'] as bool? ?? true;
        _sttCallback?.call(text, isFinal);
      } else if (call.method == 'onVoskProgress') {
        final percent = call.arguments as int? ?? 0;
        _voskProgressCallback?.call(percent);
      }
    });
  }

  static void setSTTCallback(STTResultCallback? cb) => _sttCallback = cb;
  static void setVoskProgressCallback(VoskProgressCallback? cb) =>
      _voskProgressCallback = cb;

  // ── Kebbi detection ────────────────────────────────────────────────────────

  /// Returns true if NuwaRobotAPI can be instantiated (i.e. running on Kebbi).
  static Future<bool> isKebbiAvailable() async {
    if (!_isAndroidNative) return false;
    try {
      final result = await _ch.invokeMethod<bool>('checkKebbi');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Kebbi NuwaSDK STT ──────────────────────────────────────────────────────

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

  // ── Vosk offline STT ───────────────────────────────────────────────────────

  /// Returns true if the Vosk model has already been downloaded.
  static Future<bool> isVoskModelReady() async {
    if (!_isAndroidNative) return false;
    try {
      final result = await _ch.invokeMethod<bool>('checkVoskModel');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Download (if needed) + load the Vosk model.
  /// Progress is reported via [setVoskProgressCallback]:
  ///   0–100 = download %, -1 = extracting.
  /// Throws on failure.
  static Future<void> initVosk() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('initVosk');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] initVosk error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[Kebbi] initVosk error: $e');
      rethrow;
    }
  }

  static Future<void> startVoskSTT() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('startVoskSTT');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] startVoskSTT error: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[Kebbi] startVoskSTT error: $e');
      rethrow;
    }
  }

  static Future<void> stopVoskSTT() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('stopVoskSTT');
    } catch (e) {
      debugPrint('[Kebbi] stopVoskSTT error: $e');
    }
  }

  // ── Robot actions ──────────────────────────────────────────────────────────

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
