import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

typedef VoskResultCallback = void Function(String text, bool isFinal);

/// Offline STT via vosk_flutter — fallback for non-Kebbi Android devices.
///
/// Model is downloaded once to the app's documents directory on first use.
/// Default: vosk-model-small-en-us (≈40 MB).
///
/// To use a different language, change [modelUrl] and [modelDirName].
class VoskSttService {
  static const String modelUrl =
      'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip';
  static const String modelDirName = 'vosk-model-small-en-us-0.15';

  static final VoskFlutterPlugin _vosk = VoskFlutterPlugin.instance();

  static Model? _model;
  static Recognizer? _recognizer;
  static SpeechService? _speechService;

  static VoskResultCallback? _callback;

  static bool get isInitialized => _model != null;

  /// Prepare model (download if needed). Reports progress via [onProgress].
  static Future<void> prepare({
    void Function(String status)? onProgress,
  }) async {
    if (_model != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/$modelDirName');

    if (!modelDir.existsSync()) {
      onProgress?.call('Downloading voice model (~40 MB)…');
      await _downloadAndExtract(dir.path, onProgress: onProgress);
    }

    onProgress?.call('Loading voice model…');
    _model = await _vosk.createModel(modelDir.path);
    debugPrint('[Vosk] model loaded from ${modelDir.path}');
  }

  static Future<void> _downloadAndExtract(
    String destDir, {
    void Function(String)? onProgress,
  }) async {
    final zipPath = '$destDir/vosk_model.zip';
    final zipFile = File(zipPath);

    // Download
    final response = await http.get(Uri.parse(modelUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download vosk model (${response.statusCode})');
    }
    await zipFile.writeAsBytes(response.bodyBytes);
    onProgress?.call('Extracting voice model…');

    // Extract using system unzip
    final result = await Process.run('unzip', ['-o', zipPath, '-d', destDir]);
    if (result.exitCode != 0) {
      throw Exception('Failed to extract vosk model: ${result.stderr}');
    }
    await zipFile.delete();
  }

  /// Start listening. Results delivered via [callback].
  static Future<void> start(VoskResultCallback callback) async {
    if (_model == null) throw StateError('VoskSttService not prepared');

    _callback = callback;

    _recognizer ??= await _vosk.createRecognizer(
      model: _model!,
      sampleRate: 16000,
    );

    _speechService = await _vosk.initSpeechService(_recognizer!);

    _speechService!.onPartial().forEach((partial) {
      final text = _parseVoskText(partial);
      _callback?.call(text, false);
    });

    _speechService!.onResult().forEach((result) {
      final text = _parseVoskText(result);
      _callback?.call(text, true);
    });

    debugPrint('[Vosk] listening started');
  }

  /// Stop listening.
  static Future<void> stop() async {
    await _speechService?.stop();
    _speechService = null;
    _callback = null;
    debugPrint('[Vosk] listening stopped');
  }

  /// Dispose everything (call when no longer needed).
  static Future<void> dispose() async {
    await stop();
    _recognizer?.dispose();
    _recognizer = null;
    _model?.dispose();
    _model = null;
  }

  /// Vosk results are JSON: {"text": "hello"} or {"partial": "hel"}
  static String _parseVoskText(String json) {
    final match = RegExp(r'"(?:text|partial)"\s*:\s*"([^"]*)"').firstMatch(json);
    return match?.group(1)?.trim() ?? '';
  }
}
