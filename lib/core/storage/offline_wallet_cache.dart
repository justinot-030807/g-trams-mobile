import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cached offline snapshot of the operator's garage, Digital ID profile, and settings.
class OfflineWalletSnapshot {
  const OfflineWalletSnapshot({
    required this.franchises,
    required this.settings,
    this.user,
    this.lastSyncedAt,
  });

  final MobileUser? user;
  final List<FranchiseRecord> franchises;
  final PortalSettings settings;
  final DateTime? lastSyncedAt;

  bool get hasData => franchises.isNotEmpty || user != null || lastSyncedAt != null;

  Map<String, dynamic> toJson() => {
        'user': user?.toJson(),
        'franchises': franchises.map((f) => f.toJson()).toList(),
        'settings': settings.toJson(),
        'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
      };

  factory OfflineWalletSnapshot.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map
        ? MobileUser.fromJson(Map<String, dynamic>.from(rawUser))
        : null;

    final rawFranchises = json['franchises'];
    final franchises = rawFranchises is List
        ? rawFranchises
            .whereType<Map>()
            .map((e) => FranchiseRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <FranchiseRecord>[];

    final rawSettings = json['settings'];
    final settings = rawSettings is Map
        ? PortalSettings.fromJson(Map<String, dynamic>.from(rawSettings))
        : const PortalSettings();

    final rawSynced = json['lastSyncedAt']?.toString();
    final lastSyncedAt = rawSynced != null && rawSynced.isNotEmpty
        ? DateTime.tryParse(rawSynced)?.toUtc()
        : null;

    return OfflineWalletSnapshot(
      user: user,
      franchises: franchises,
      settings: settings,
      lastSyncedAt: lastSyncedAt,
    );
  }
}

/// Abstract cache interface so production uses Hive (`hive_flutter`) and tests
/// can inject an in-memory implementation with zero disk side effects.
abstract class OfflineWalletCache {
  OfflineWalletSnapshot? readSnapshot(String userId);
  Future<void> writeSnapshot(String userId, OfflineWalletSnapshot snapshot);
  Future<void> clearUser(String userId);
  Future<void> clearAll();
}

/// Hive-backed offline wallet storage (IndexedDB on Chrome Web, app storage on Android).
class HiveOfflineWalletCache implements OfflineWalletCache {
  HiveOfflineWalletCache(this._box);

  static const String boxName = 'gtrams_offline_wallet_v1';

  final Box<String> _box;

  static Future<OfflineWalletCache> init() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<String>(boxName);
      return HiveOfflineWalletCache(box);
    } catch (err) {
      debugPrint('HiveOfflineWalletCache fallback to memory: $err');
      return InMemoryOfflineWalletCache();
    }
  }

  String _key(String userId) => 'wallet_snapshot_v1_${userId.trim()}';

  @override
  OfflineWalletSnapshot? readSnapshot(String userId) {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return null;
    try {
      final raw = _box.get(_key(cleanId));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return OfflineWalletSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeSnapshot(
    String userId,
    OfflineWalletSnapshot snapshot,
  ) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    await _box.put(_key(cleanId), jsonEncode(snapshot.toJson()));
  }

  @override
  Future<void> clearUser(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    await _box.delete(_key(cleanId));
  }

  @override
  Future<void> clearAll() async {
    await _box.clear();
  }
}

/// Lightweight in-memory fallback / unit-test cache implementation.
class InMemoryOfflineWalletCache implements OfflineWalletCache {
  final Map<String, String> _store = {};

  String _key(String userId) => 'wallet_snapshot_v1_${userId.trim()}';

  @override
  OfflineWalletSnapshot? readSnapshot(String userId) {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return null;
    final raw = _store[_key(cleanId)];
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return OfflineWalletSnapshot.fromJson(Map<String, dynamic>.from(decoded));
  }

  @override
  Future<void> writeSnapshot(
    String userId,
    OfflineWalletSnapshot snapshot,
  ) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    _store[_key(cleanId)] = jsonEncode(snapshot.toJson());
  }

  @override
  Future<void> clearUser(String userId) async {
    _store.remove(_key(userId));
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
  }
}

final Provider<OfflineWalletCache> offlineWalletCacheProvider =
    Provider<OfflineWalletCache>((ref) => InMemoryOfflineWalletCache());
