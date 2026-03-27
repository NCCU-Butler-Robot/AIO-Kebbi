import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../config/api_config.dart';
import '../models/scam_event.dart';
import '../models/ws_message.dart';

class WebSocketService {
  sio.Socket? _socket;
  bool _connected = false;

  // streams
  final _scamCtrl = StreamController<ScamEvent>.broadcast();
  final _msgCtrl = StreamController<WsMessage>.broadcast();
  final _audioCtrl = StreamController<Uint8List>.broadcast();

  Stream<ScamEvent> get events => _scamCtrl.stream;
  Stream<WsMessage> get messages => _msgCtrl.stream;
  Stream<Uint8List> get audioFrames => _audioCtrl.stream;
  bool get connected => _connected;


  // =============== CONNECT ===============
  Future<void> connect({
    required String token,
    required String uuid,
    String? callToken,
  }) async {
    if (_connected) return;

    if (ApiConfig.mockWs) {
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
      return;
    }

    // Socket.IO auth — 後端需要 access_token + call_token
    final auth = <String, dynamic>{'access_token': token};
    if (callToken != null && callToken.isNotEmpty) {
      auth['call_token'] = callToken;
    }

    _socket = sio.io(
      ApiConfig.socketBaseUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(auth)
          .disableAutoConnect()
          .setTimeout(10000)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(5)
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
      debugPrint('[SIO] connected, id=${_socket?.id}');
      _msgCtrl.add(WsMessage.fromJson({
        'type': 'connection_success',
        'connection_id': _socket?.id ?? '',
        'client_uuid': uuid,
      }));
    });

    _socket!.onConnectError((err) {
      debugPrint('[SIO] connect error: $err');
      _connected = false;
      _msgCtrl.add(WsMessage.fromJson({
        'type': 'error',
        'error': 'Connection failed: $err',
      }));
    });

    _socket!.onDisconnect((reason) {
      debugPrint('[SIO] disconnected: $reason');
      _connected = false;
    });

    _socket!.onError((err) {
      debugPrint('[SIO] error: $err');
      _msgCtrl.add(WsMessage.fromJson({
        'type': 'error',
        'error': err.toString(),
      }));
    });

    // 音訊轉發 — 後端 emit("audio_chunk", {"metadata": ..., "chunk": ...})
    _socket!.on('audio_chunk', (data) {
      try {
        if (data is Map) {
          final chunk = data['chunk'];
          if (chunk is List<int>) {
            _audioCtrl.add(Uint8List.fromList(chunk));
          } else if (chunk is Uint8List) {
            _audioCtrl.add(chunk);
          }
        }
      } catch (e) {
        debugPrint('[SIO] audio_chunk parse error: $e');
      }
    });

    _socket!.connect();
  }

  // =============== SEND ===============
  void send(String data) {
    _socket?.emit('message', data);
  }

  void sendJson(Object data) {
    _socket?.emit('message', data);
  }

  Future<void> sendMessage(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? 'message';
    _socket?.emit(type, data);
  }

  /// 傳送音訊至對方
  /// 後端 handler: handle_audio_chunk(sid, metadata, chunk)
  Future<void> sendAudio(Uint8List bytes) async {
    try {
      _socket?.emit('audio_chunk', [
        {'timestamp': DateTime.now().millisecondsSinceEpoch},
        bytes,
      ]);
    } catch (_) {}
  }

  // =============== LIFECYCLE ===============
  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _scamCtrl.close();
    await _msgCtrl.close();
    await _audioCtrl.close();
  }
}
