// lib/services/api_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';
import '../models/login_models.dart';

class ChatResult {
  final Uint8List? audioBytes;
  final String text;
  final String conversationId;
  final String messageId;

  ChatResult({
    this.audioBytes,
    required this.text,
    required this.conversationId,
    required this.messageId,
  });
}

class ApiService {
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final skipAuth = options.extra['skipAuth'] == true;

          if (!skipAuth && _accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          options.headers[ApiConfig.installationIdHeader] =
              ApiConfig.defaultInstallationId;

          handler.next(options);
        },
      ),
    );
  }

  late final Dio _dio;

  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// 登入：成功回傳 LoginResponse，失敗丟 Exception
  /// 後端 /auth/login 使用 OAuth2 form-encoded，僅回傳 access_token。
  /// 需再呼叫 /auth/status 取得 uuid / name / username。
  Future<LoginResponse> login(LoginRequest req) async {
    if (ApiConfig.mockLogin) return _mockLogin(req);

    debugPrint('[API] POST ${_dio.options.baseUrl}${ApiConfig.loginPath}');

    // Step 1: 取得 access_token（x-www-form-urlencoded）
    final loginResp = await _dio.post(
      ApiConfig.loginPath,
      data: {
        'username': req.username,
        'password': req.password,
        'grant_type': 'password',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        extra: const {'skipAuth': true},
      ),
    );

    if (loginResp.statusCode != 200) {
      final body = loginResp.data is String
          ? loginResp.data
          : jsonEncode(loginResp.data);
      throw Exception('Login failed (${loginResp.statusCode}) $body');
    }

    final accessToken =
        (loginResp.data as Map)['access_token'] as String;

    // Step 2: 注入 token，讓下一個請求帶上 Authorization header
    setAccessToken(accessToken);

    // Step 3: 取得使用者資訊（uuid / name / username）
    debugPrint('[API] GET ${_dio.options.baseUrl}${ApiConfig.statusPath}');
    final statusResp = await _dio.get(ApiConfig.statusPath);

    if (statusResp.statusCode != 200) {
      throw Exception(
          'Failed to get user info (${statusResp.statusCode})');
    }

    final info = Map<String, dynamic>.from(statusResp.data as Map);
    return LoginResponse(
      accessToken: accessToken,
      uuid: info['uuid'] as String,
      name: info['name'] as String,
      username: info['username'] as String,
    );
  }

  Future<LoginResponse> _mockLogin(LoginRequest req) async {
    await Future.delayed(ApiConfig.mockDelay);
    return LoginResponse(
      accessToken: 'dev-token-${DateTime.now().millisecondsSinceEpoch}',
      uuid: 'u-${req.username.isEmpty ? 'guest' : req.username}',
      name: req.username.isEmpty ? 'Guest' : req.username,
      username: req.username.isEmpty ? 'guest' : req.username,
    );
  }

  /// Butler chat：傳文字 → 回傳 MP3 bytes + 文字
  Future<ChatResult> sendChat({
    required String prompt,
    String? conversationId,
  }) async {
    final resp = await _dio.post(
      ApiConfig.chatPath,
      data: {
        'prompt': prompt,
        'initiate_conversation': conversationId == null,
      },
      options: Options(responseType: ResponseType.bytes),
    );

    if (resp.statusCode != 200) {
      throw Exception('Chat failed (${resp.statusCode})');
    }

    final contentType = resp.headers.value('content-type') ?? '';
    if (contentType.contains('audio')) {
      final rawText = resp.headers.value('x-response-text') ?? '';
      final text = Uri.decodeComponent(rawText);
      return ChatResult(
        audioBytes: Uint8List.fromList(resp.data as List<int>),
        text: text,
        conversationId: resp.headers.value('x-conversation-id') ?? '',
        messageId: resp.headers.value('x-message-id') ?? '',
      );
    }

    // TTS 失敗 fallback → JSON
    final json = jsonDecode(
      utf8.decode(resp.data as List<int>),
    ) as Map<String, dynamic>;
    return ChatResult(
      audioBytes: null,
      text: json['message'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      messageId: json['message_id'] as String? ?? '',
    );
  }

  /// Food recognition：上傳圖片 → 回傳 detect_url
  Future<String> uploadFoodImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'photo.jpg',
      ),
    });

    final resp = await _dio.post(ApiConfig.foodRecognitionPath, data: formData);

    if (resp.statusCode != 200) {
      throw Exception('Food recognition failed (${resp.statusCode})');
    }

    final map = Map<String, dynamic>.from(resp.data as Map);
    return map['detect_url'] as String? ?? 'https://food.bestweiwei.dpdns.org';
  }

  Future<void> hangup({required String callId}) async {
    try {
      await _dio.post(
        ApiConfig.hangupPath,
        data: {'call_id': callId},
      );
    } on DioException catch (e) {
      final data = e.response?.data;

      final msg = (data is Map && data['message'] != null)
          ? data['message'].toString()
          : 'Hangup failed';

      throw Exception(msg);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
