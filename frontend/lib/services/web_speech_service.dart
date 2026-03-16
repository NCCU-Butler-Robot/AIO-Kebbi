import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

typedef WebSTTCallback = void Function(String text, bool isFinal);

class WebSpeechService {
  static final WebSpeechService I = WebSpeechService._();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  WebSTTCallback? _callback;

  WebSpeechService._();

  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: (status) {
        debugPrint('[WebSpeech] Status: $status');
      },
      onError: (error) {
        debugPrint('[WebSpeech] Error: $error');
        _callback?.call('', true);
      },
    );
    debugPrint('[WebSpeech] Initialized: $_initialized');
    return _initialized;
  }

  void setCallback(WebSTTCallback? cb) {
    _callback = cb;
  }

  Future<bool> startListening() async {
    if (!_initialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    return await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords;
        final isFinal = result.finalResult;
        _callback?.call(text, isFinal);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;

  bool get isAvailable => _initialized;
}
