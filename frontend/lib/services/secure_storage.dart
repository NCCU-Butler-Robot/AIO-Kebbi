import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // Keys
  static const _kToken = 'access_token';
  static const _kUuid = 'user_uuid';
  static const _kName = 'user_name';
  static const _kUname = 'user_username';

  /// 一次性寫入登入後的所有資料
  static Future<void> saveLogin({
    required String token,
    required String uuid,
    required String name,
    required String username,
  }) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUuid, value: uuid);
    await _storage.write(key: _kName, value: name);
    await _storage.write(key: _kUname, value: username);
  }

  /// 個別寫入/更新
  static Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  static Future<void> saveUuid(String uuid) =>
      _storage.write(key: _kUuid, value: uuid);
  static Future<void> saveName(String name) =>
      _storage.write(key: _kName, value: name);
  static Future<void> saveUsername(String username) =>
      _storage.write(key: _kUname, value: username);

  /// 讀取
  static Future<String?> readToken() => _storage.read(key: _kToken);
  static Future<String?> readUuid() => _storage.read(key: _kUuid);
  static Future<String?> readName() => _storage.read(key: _kName);
  static Future<String?> readUsername() => _storage.read(key: _kUname);

  /// 刪除單一欄位
  static Future<void> deleteToken() => _storage.delete(key: _kToken);
  static Future<void> deleteUuid() => _storage.delete(key: _kUuid);
  static Future<void> deleteName() => _storage.delete(key: _kName);
  static Future<void> deleteUsername() => _storage.delete(key: _kUname);

  /// 清除
  static Future<void> clear() => _storage.deleteAll();
}
