import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:flutter_sound/flutter_sound.dart';

/// 簡易音訊服務：錄檔 / 播放 / 音量 / 即時串流（PCM16）
class AudioService {
  AudioService._();
  static final AudioService I = AudioService._();

  // 錄檔（record 套件）
  final _recorder = AudioRecorder();

  // 串流錄音（flutter_sound）
  final _fsRecorder = FlutterSoundRecorder();
  StreamSubscription<Uint8List>? _pcmSub;
  StreamController<Uint8List>? _pcmCtrl;
  bool _streaming = false;
  bool get isStreaming => _streaming;

  // 播放
  final _player = FlutterSoundPlayer();

  bool _inited = false;
  bool _recording = false;
  String? _lastFilePath;

  double _playerVolume = 1.0;
  double get playerVolume => _playerVolume;

  bool get isRecording => _recording;
  String? get lastFilePath => _lastFilePath;

  Future<void> init() async {
    if (_inited) return;
    await _player.openPlayer();
    await _player.setVolume(_playerVolume);
    _inited = true;
  }

  Future<bool> ensureMicPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> setPlayerVolume(double v) async {
    _playerVolume = v.clamp(0.0, 1.0);
    await init();
    await _player.setVolume(_playerVolume);
  }

  // ---------- 錄檔 ----------
  Future<void> startRecord() async {
    if (_recording) return;

    if (!await ensureMicPermission()) {
      throw '尚未取得麥克風權限';
    }

    await init();

    late final String recPath;
    if (kIsWeb) {
      recPath = 'web_record_${DateTime.now().millisecondsSinceEpoch}.wav';
    } else {
      final dir = (await getTemporaryDirectory()).path;
      recPath = '$dir/rec_${DateTime.now().millisecondsSinceEpoch}.wav';
    }

    const config = RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
    );

    await _recorder.start(config, path: recPath);
    _recording = true;
    _lastFilePath = kIsWeb ? null : recPath;
  }

  Future<File?> stopRecord() async {
    if (!_recording) return null;
    final filePath = await _recorder.stop();
    _recording = false;

    if (kIsWeb) return null;
    _lastFilePath = filePath;
    if (filePath == null) return null;

    return File(filePath);
  }

  // ---------- 播放 ----------
  Future<void> playBytes(Uint8List bytes) async {
    await init();
    await _player.setVolume(_playerVolume);
    await _player.startPlayer(
      fromDataBuffer: bytes,
      codec: Codec.pcm16WAV, 
      whenFinished: () {},
    );
  }

  Future<void> stopPlay() async {
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  // ---------- 即時串流錄音 ----------
  Future<void> startStreaming(void Function(Uint8List bytes) onChunk) async {
    if (_streaming) return;
    if (!await ensureMicPermission()) {
      throw '尚未取得麥克風權限';
    }
    await _fsRecorder.openRecorder();

    _pcmCtrl = StreamController<Uint8List>();
    _pcmSub = _pcmCtrl!.stream.listen(onChunk);

    await _fsRecorder.startRecorder(
      toStream: _pcmCtrl!.sink, 
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );

    _streaming = true;
  }

  Future<void> stopStreaming() async {
    if (!_streaming) return;
    try {
      await _fsRecorder.stopRecorder();
    } catch (_) {}
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _pcmCtrl?.close();
    _pcmCtrl = null;
    _streaming = false;
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    try {
      await _fsRecorder.closeRecorder();
    } catch (_) {}
    try {
      await _player.closePlayer();
    } catch (_) {}
    _inited = false;
  }
}
