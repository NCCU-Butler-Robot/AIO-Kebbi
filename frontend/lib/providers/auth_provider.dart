import 'package:flutter/material.dart';
import '/models/login_models.dart';
import '/services/api_service.dart';
import '/services/secure_storage.dart';
import '/config/api_config.dart';
import 'package:get_it/get_it.dart';
import '../di/service_locator.dart';





class AuthProvider extends ChangeNotifier {
  final ApiService _api = sl<ApiService>();

  bool _loading = false;
  bool get loading => _loading;

  String? _token;
  String? get token => _token;

  String? _uuid;
  String? get uuid => _uuid;

  String? _name;
  String? get name => _name;

  String? _username;
  String? get username => _username;

  Future<void> init() async {
    _token = await SecureStorage.readToken();
    // 將 storage 裡的 token 注入 ApiService，
    // 否則 App 重啟後 ApiService._accessToken 會是 null 導致 401
    if (_token != null && _token!.isNotEmpty) {
      sl<ApiService>().setAccessToken(_token);
    }
    try {
      _uuid = await SecureStorage.readUuid();
      _name = await SecureStorage.readName();
      _username = await SecureStorage.readUsername();
    } catch (_) {}
    notifyListeners();
  }

  Future<String?> login({
    required String username,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();

    if (ApiConfig.devBypassLogin) {
      // ignore: prefer_const_declarations
      final fakeToken = ApiConfig.devFakeAccessToken;

      _token = fakeToken;
      GetIt.I<ApiService>().setAccessToken(fakeToken);
      _uuid = 'dev-uuid';
      _name = 'Dev User';
      _username = username;

      await SecureStorage.saveLogin(
        token: fakeToken,
        uuid: _uuid!,
        name: _name!,
        username: _username!,
      );

      return null;
    }

    try {
      final res = await _api.login(LoginRequest(username: username, password: password));
      // 後端回傳
      _token = res.accessToken;
      GetIt.I<ApiService>().setAccessToken(res.accessToken);
      _uuid = res.uuid;
      _name = res.name;
      _username = res.username;

      await SecureStorage.saveLogin(
        token: res.accessToken,
        uuid: res.uuid,
        name: res.name,
        username: res.username,
      );
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _uuid = null;
    _name = null;
    _username = null;
    await SecureStorage.clear();
    notifyListeners();
  }

  bool get isLoggedIn => _token?.isNotEmpty == true;
}
