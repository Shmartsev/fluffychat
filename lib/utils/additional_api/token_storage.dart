import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  // Используем зашифрованное хранилище
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userId = 'user_id';


  // Сохраняем токены
  static Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _accessTokenKey, value: access);
    await _storage.write(key: _refreshTokenKey, value: refresh);
  }

  static Future<void> saveUserId({required String userId}) async {
    await _storage.write(key: _userId, value: userId);
  }

  // Читаем access-токен
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  // Читаем refresh-токен
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userId);
  }

  // Очищаем при логауте
  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userId);
  }
}