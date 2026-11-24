import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PrivateCacheBox {
  static const _keyName = 'gtrams_hive_encryption_key';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static Future<HiveAesCipher>? _cipher;

  static Future<Box<String>?> open(String legacyName) async {
    if (kIsWeb) {
      // The web preview uses memory so records don't persist in a shared browser.
      await Hive.deleteBoxFromDisk(legacyName);
      return null;
    }

    final cipher = await (_cipher ??= _loadCipher());
    final box = await Hive.openBox<String>(
      '${legacyName}_encrypted',
      encryptionCipher: cipher,
    );
    if (await Hive.boxExists(legacyName)) {
      final legacy = await Hive.openBox<String>(legacyName);
      try {
        await box.putAll(
          Map.fromEntries(
            legacy.toMap().entries.where(
              (entry) => !box.containsKey(entry.key),
            ),
          ),
        );
        await box.flush();
        await legacy.deleteFromDisk();
      } finally {
        if (legacy.isOpen) await legacy.close();
      }
    }
    return box;
  }

  static Future<HiveAesCipher> _loadCipher() async {
    final stored = await _storage.read(key: _keyName);
    if (stored != null) return HiveAesCipher(base64Url.decode(stored));

    final key = Hive.generateSecureKey();
    await _storage.write(key: _keyName, value: base64Url.encode(key));
    return HiveAesCipher(key);
  }
}
