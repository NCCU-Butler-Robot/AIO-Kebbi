import 'package:flutter/foundation.dart'; // kIsWeb, TargetPlatform
import 'package:flutter/services.dart'; // MethodChannel, PlatformException, MissingPluginException

class KebbiService {
  static const MethodChannel _ch = MethodChannel('kebbi');

  static bool get _isAndroidNative =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> init() async {
    if (!_isAndroidNative) {
      debugPrint(
          '[Kebbi] init skipped (platform=${kIsWeb ? 'web' : defaultTargetPlatform.name})');
      return;
    }
    try {
      await _ch.invokeMethod<void>('init');
    } on MissingPluginException {
      debugPrint('[Kebbi] init skipped: kebbi channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] init PlatformException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] init error: $e');
    }
  }

  static Future<void> doFraudAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('fraud');
    } on MissingPluginException {
      debugPrint('[Kebbi] fraud skipped: kebbi channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] fraud PlatformException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] fraud error: $e');
    }
  }

  static Future<void> doSafeAction() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('safe');
    } on MissingPluginException {
      debugPrint('[Kebbi] safe skipped: kebbi channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] safe PlatformException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] safe error: $e');
    }
  }

  static Future<void> release() async {
    if (!_isAndroidNative) return;
    try {
      await _ch.invokeMethod<void>('release');
    } on MissingPluginException {
      debugPrint('[Kebbi] release skipped: kebbi channel not registered.');
    } on PlatformException catch (e) {
      debugPrint('[Kebbi] release PlatformException: ${e.code} ${e.message}');
    } catch (e) {
      debugPrint('[Kebbi] release error: $e');
    }
  }
}
