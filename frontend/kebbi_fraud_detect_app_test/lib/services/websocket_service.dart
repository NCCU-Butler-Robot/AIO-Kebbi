import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import '../models/scam_event.dart';
import '../models/ws_message.dart';

class WebSocketService {
  WebSocketChannel? _ch;
  bool _connected = false;

  // streams
  final _scamCtrl = StreamController<ScamEvent>.broadcast();
  final _msgCtrl  = StreamController<WsMessage>.broadcast();
  final _audioCtrl = StreamController<Uint8List>.broadcast();

  Stream<ScamEvent> get events   => _scamCtrl.stream;
  Stream<WsMessage> get messages => _msgCtrl.stream;
  Stream<Uint8List> get audioFrames => _audioCtrl.stream;
  bool get connected => _connected;

  // heartbeat / reconnect
  Timer? _heartbeat;
  Timer? _reconnect;
  DateTime _lastRx = DateTime.now();
  final _rng = Random();
  int _retries = 0;
  bool _manuallyClosed = false;

  // keep for reconnect
  String? _pendingToken;
  String? _pendingUuid;

  // =============== CONNECT ===============
  Future<void> connect({required String token, required String uuid}) async {
    if (_connected) return;
    _manuallyClosed = false;
    _pendingToken = token;
    _pendingUuid  = uuid;

    if (ApiConfig.mockWs) {
      // --- mock: 播放 assets/mock_seq.json 或 mock_call.json ---
      try {
        final rawSeq = await rootBundle.loadString('assets/mock_seq.json');
        final List seq = json.decode(rawSeq) as List;
        int i = 0;
        Timer.periodic(ApiConfig.mockWsInterval, (_) {
          final Map<String, dynamic> m =
              Map<String, dynamic>.from(seq[i % seq.length] as Map);
          i++;
          final msg = WsMessage.fromJson(m);
          _msgCtrl.add(msg);
          if (msg.type == WsType.fraudAssessment) {
            _scamCtrl.add(ScamEvent.fromJson(m));
          }
        });
      } catch (_) {}
      _msgCtrl.add(WsMessage.fromJson({
        'type': 'connection_success',
        'connection_id': 'mock',
        'client_uuid': uuid,
      }));
      _connected = true;
      _startHeartbeat();
      return;
    }

    try {
      final base = Uri.parse(ApiConfig.wsBase);
      final basePath = base.path.endsWith('/')
          ? base.path.substring(0, base.path.length - 1)
          : base.path;

      final bool isEcho = base.host == 'echo.websocket.events';
      final String path = isEcho ? (basePath.isEmpty ? '/' : basePath)
                                 : '$basePath/ws/$uuid';

      final uri = Uri(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: path,
        queryParameters: {'token': token},
      );

      debugPrint('[WS] connecting $uri');

      _ch = WebSocketChannel.connect(uri);
      _connected = true;
      _reconnect?.cancel();
      _retries = 0;
      _lastRx = DateTime.now();
      _startHeartbeat();

      _ch!.stream.listen(
        (data) {
          _lastRx = DateTime.now();
          try {
            if (data is Uint8List) {
              _audioCtrl.add(data);
              return;
            }
            if (data is List<int>) {
              final s = utf8.decode(data);
              final t = s.trimLeft();
              if (t.isNotEmpty && (t.startsWith('{') || t.startsWith('['))) {
                final j = json.decode(s) as Map<String, dynamic>;
                final m = WsMessage.fromJson(j);
                _msgCtrl.add(m);
                if (m.type == WsType.fraudAssessment) {
                  _scamCtrl.add(ScamEvent.fromJson(j));
                }
              } else {
                _audioCtrl.add(Uint8List.fromList(data));
              }
              return;
            }
            if (data is String) {
              final t = data.trimLeft();
              if (t.isEmpty || !(t.startsWith('{') || t.startsWith('['))) {
                debugPrint('[WS] <= (text) $data');
                return;
              }
              final j = json.decode(data) as Map<String, dynamic>;
              final m = WsMessage.fromJson(j);
              _msgCtrl.add(m);
              if (m.type == WsType.fraudAssessment) {
                _scamCtrl.add(ScamEvent.fromJson(j));
              }
              return;
            }
            if (data is Map) {
              final j = Map<String, dynamic>.from(data);
              final m = WsMessage.fromJson(j);
              _msgCtrl.add(m);
              if (m.type == WsType.fraudAssessment) {
                _scamCtrl.add(ScamEvent.fromJson(j));
              }
              return;
            }
          } catch (_) {}
        },
        onError: (e, st) {
          _msgCtrl.add(WsMessage.fromJson({'type': 'error', 'error': e.toString()}));
          _onClosed();
        },
        onDone: _onClosed,
        cancelOnError: true,
      );
    } catch (_) {
      await disconnect();
    }
  }

  void _onClosed() {
    _stopHeartbeat();
    try {
      _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    _connected = false;
    _scheduleReconnect();
  }

  // =============== SEND ===============
  void send(String data) {
    if (_ch == null) {
      debugPrint('[WS] send skipped: not connected');
      return;
    }
    _ch!.sink.add(data);
  }

  void sendJson(Object data) => send(jsonEncode(data));

  Future<void> sendMessage(Map<String, dynamic> data) async {
    sendJson(data);
  }

  Future<void> sendAudio(Uint8List bytes) async {
    try {
      _ch?.sink.add(bytes);
    } catch (_) {}
  }

  // =============== LIFECYCLE ===============
  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnect?.cancel();
    _stopHeartbeat();
    try {
      await _ch?.sink.close();
    } catch (_) {}
    _ch = null;
    _connected = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _scamCtrl.close();
    await _msgCtrl.close();
    await _audioCtrl.close();
  }

  // =============== HEARTBEAT / RECONNECT ===============
  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
      final since = DateTime.now().difference(_lastRx);
      if (since > const Duration(seconds: 45)) {
        _onClosed();
        return;
      }
      try {
        _ch?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {}
    });
  }

  void _stopHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  void _scheduleReconnect() {
    _reconnect?.cancel();
    if (_manuallyClosed || ApiConfig.mockWs) return;

    final exp = _retries.clamp(0, 4);
    final backoff = min(30, 1 << exp);
    final jitterMs = _rng.nextInt(500);
    final delay = Duration(seconds: backoff) + Duration(milliseconds: jitterMs);

    _reconnect = Timer(delay, () async {
      _retries++;
      final t = _pendingToken, u = _pendingUuid;
      if (t != null && u != null) {
        await connect(token: t, uuid: u);
      }
    });
  }
}
