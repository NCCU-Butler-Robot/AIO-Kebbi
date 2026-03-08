// lib/services/api_service.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/login_models.dart';

class ApiService {
  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
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
  Future<LoginResponse> login(LoginRequest req) async {
    if (ApiConfig.mockLogin) return _mockLogin(req);

    // ignore: prefer_const_declarations
    final path = ApiConfig.loginPath;
    debugPrint('[API] POST ${_dio.options.baseUrl}$path');

    final resp = await _dio.post(
      path,
      data: req.toJson(),
      options: Options(
        extra: const {'skipAuth': true},
      ),
    );

    if (resp.statusCode == 200 && resp.data is Map) {
      final map = Map<String, dynamic>.from(resp.data as Map);
      return LoginResponse.fromJson(map);
    }

    final body = resp.data is String ? resp.data : jsonEncode(resp.data);
    throw Exception('Login failed (${resp.statusCode}) $body');
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
