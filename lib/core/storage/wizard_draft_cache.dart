import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Persistent offline draft storage for the 5-Step Apply & Renew Wizard.
abstract class WizardDraftCache {
  FranchiseWizardDraft? readApplyDraft(String userId);
  Future<void> saveApplyDraft(String userId, FranchiseWizardDraft draft);
  Future<void> clearApplyDraft(String userId);

  FranchiseWizardDraft? readRenewalDraft(String userId, String franchiseId);
  Future<void> saveRenewalDraft(
    String userId,
    String franchiseId,
    FranchiseWizardDraft draft,
  );
  Future<void> clearRenewalDraft(String userId, String franchiseId);

  Future<void> clearAllForUser(String userId);
}

/// Hive-backed wizard draft store (`gtrams_wizard_drafts_v1`).
class HiveWizardDraftCache implements WizardDraftCache {
  HiveWizardDraftCache(this._box);

  static const String boxName = 'gtrams_wizard_drafts_v1';

  final Box<String> _box;

  static Future<WizardDraftCache> init() async {
    try {
      final box = await Hive.openBox<String>(boxName);
      return HiveWizardDraftCache(box);
    } catch (err) {
      debugPrint('HiveWizardDraftCache fallback to memory: $err');
      return InMemoryWizardDraftCache();
    }
  }

  String _applyKey(String userId) => 'apply_draft_v1_${userId.trim()}';
  String _renewKey(String userId, String franchiseId) =>
      'renew_draft_v1_${userId.trim()}_${franchiseId.trim()}';

  @override
  FranchiseWizardDraft? readApplyDraft(String userId) =>
      _readKey(_applyKey(userId));

  @override
  Future<void> saveApplyDraft(String userId, FranchiseWizardDraft draft) async {
    if (userId.trim().isEmpty) return;
    await _box.put(
      _applyKey(userId),
      jsonEncode(draft.copyWith(savedAt: DateTime.now().toUtc()).toJson()),
    );
  }

  @override
  Future<void> clearApplyDraft(String userId) async {
    if (userId.trim().isEmpty) return;
    await _box.delete(_applyKey(userId));
  }

  @override
  FranchiseWizardDraft? readRenewalDraft(String userId, String franchiseId) =>
      _readKey(_renewKey(userId, franchiseId));

  @override
  Future<void> saveRenewalDraft(
    String userId,
    String franchiseId,
    FranchiseWizardDraft draft,
  ) async {
    if (userId.trim().isEmpty || franchiseId.trim().isEmpty) return;
    await _box.put(
      _renewKey(userId, franchiseId),
      jsonEncode(draft.copyWith(savedAt: DateTime.now().toUtc()).toJson()),
    );
  }

  @override
  Future<void> clearRenewalDraft(String userId, String franchiseId) async {
    if (userId.trim().isEmpty || franchiseId.trim().isEmpty) return;
    await _box.delete(_renewKey(userId, franchiseId));
  }

  @override
  Future<void> clearAllForUser(String userId) async {
    final cleanId = userId.trim();
    if (cleanId.isEmpty) return;
    final keysToDelete = _box.keys
        .where(
          (k) =>
              k.toString().startsWith('apply_draft_v1_$cleanId') ||
              k.toString().startsWith('renew_draft_v1_${cleanId}_'),
        )
        .toList();
    if (keysToDelete.isNotEmpty) {
      await _box.deleteAll(keysToDelete);
    }
  }

  FranchiseWizardDraft? _readKey(String key) {
    try {
      final raw = _box.get(key);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FranchiseWizardDraft.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

/// In-memory draft cache for unit & widget tests.
class InMemoryWizardDraftCache implements WizardDraftCache {
  final Map<String, String> _store = {};

  String _applyKey(String userId) => 'apply_draft_v1_${userId.trim()}';
  String _renewKey(String userId, String franchiseId) =>
      'renew_draft_v1_${userId.trim()}_${franchiseId.trim()}';

  @override
  FranchiseWizardDraft? readApplyDraft(String userId) =>
      _readKey(_applyKey(userId));

  @override
  Future<void> saveApplyDraft(String userId, FranchiseWizardDraft draft) async {
    if (userId.trim().isEmpty) return;
    _store[_applyKey(userId)] =
        jsonEncode(draft.copyWith(savedAt: DateTime.now().toUtc()).toJson());
  }

  @override
  Future<void> clearApplyDraft(String userId) async {
    _store.remove(_applyKey(userId));
  }

  @override
  FranchiseWizardDraft? readRenewalDraft(String userId, String franchiseId) =>
      _readKey(_renewKey(userId, franchiseId));

  @override
  Future<void> saveRenewalDraft(
    String userId,
    String franchiseId,
    FranchiseWizardDraft draft,
  ) async {
    if (userId.trim().isEmpty || franchiseId.trim().isEmpty) return;
    _store[_renewKey(userId, franchiseId)] =
        jsonEncode(draft.copyWith(savedAt: DateTime.now().toUtc()).toJson());
  }

  @override
  Future<void> clearRenewalDraft(String userId, String franchiseId) async {
    _store.remove(_renewKey(userId, franchiseId));
  }

  @override
  Future<void> clearAllForUser(String userId) async {
    final cleanId = userId.trim();
    _store.removeWhere(
      (k, _) =>
          k.startsWith('apply_draft_v1_$cleanId') ||
          k.startsWith('renew_draft_v1_${cleanId}_'),
    );
  }

  FranchiseWizardDraft? _readKey(String key) {
    final raw = _store[key];
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return FranchiseWizardDraft.fromJson(Map<String, dynamic>.from(decoded));
  }
}

final Provider<WizardDraftCache> wizardDraftCacheProvider =
    Provider<WizardDraftCache>((ref) => InMemoryWizardDraftCache());
