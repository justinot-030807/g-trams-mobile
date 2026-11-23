import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted persistent storage for JWT tokens and serialized user sessions.
class SecureSessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _keyToken = 'gtrams_jwt_token';
  static const _keyUserJson = 'gtrams_user_json';
  static const _keyRole = 'gtrams_role';

  Future<void> saveSession({
    required String token,
    required String role,
    required Map<String, dynamic> userJson,
  }) async {
    await Future.wait([
      _storage.write(key: _keyToken, value: token),
      _storage.write(key: _keyRole, value: role),
      _storage.write(key: _keyUserJson, value: jsonEncode(userJson)),
    ]);
  }

  Future<String?> readToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readRole() async {
    try {
      return await _storage.read(key: _keyRole);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readUserJson() async {
    try {
      final raw = await _storage.read(key: _keyUserJson);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _keyToken),
        _storage.delete(key: _keyRole),
        _storage.delete(key: _keyUserJson),
      ]);
    } catch (_) {
      // Ignore storage teardown errors on logout.
    }
  }
}
