import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted persistent storage for JWT tokens and serialized user sessions.
class SecureSessionStorage {
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _keySession = 'gtrams_session';
  static const _keyToken = 'gtrams_jwt_token';
  static const _keyUserJson = 'gtrams_user_json';
  static const _keyRole = 'gtrams_role';
  Future<void> _pendingWrite = Future.value();
  int _generation = 0;
  bool _loggedOut = false;
  DateTime? offlineExpiresAt;

  int get generation => _generation;

  Future<void> saveSession({
    required String token,
    required String role,
    required Map<String, dynamic> userJson,
    int? expectedGeneration,
    bool rotateGeneration = true,
  }) {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      return Future.error(StateError('The session changed. Please try again.'));
    }
    if (rotateGeneration) _generation++;
    final generation = _generation;
    return _write(() async {
      await _storage.write(
        key: _keySession,
        value: jsonEncode({
          'token': token,
          'role': role,
          'user': userJson,
          'validatedAt': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      if (generation == _generation) _loggedOut = false;
    });
  }

  Future<String?> readToken() async {
    try {
      final session = await _readSession();
      if (session != null) return session['token'] as String?;
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readRole() async {
    try {
      final session = await _readSession();
      if (session != null) return session['role'] as String?;
      return await _storage.read(key: _keyRole);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> readUserJson() async {
    try {
      final session = await _readSession();
      if (session != null) return session['user'] as Map<String, dynamic>?;
      final raw = await _storage.read(key: _keyUserJson);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> readLastValidatedAt() async {
    try {
      final session = await _readSession();
      return DateTime.tryParse(session?['validatedAt'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _readSession() async {
    await _pendingWrite;
    if (_loggedOut) return const {};
    final raw = await _storage.read(key: _keySession);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _write(Future<void> Function() operation) {
    final write = _pendingWrite.then((_) => operation());
    _pendingWrite = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> clearSession() {
    _generation++;
    offlineExpiresAt = null;
    _loggedOut = true;
    return _write(() async {
      // This marker prevents a failed legacy-key deletion from reviving a session.
      await _storage.write(key: _keySession, value: '{}');
      await Future.wait([
        _storage.delete(key: _keyToken),
        _storage.delete(key: _keyRole),
        _storage.delete(key: _keyUserJson),
      ]);
    });
  }
}
