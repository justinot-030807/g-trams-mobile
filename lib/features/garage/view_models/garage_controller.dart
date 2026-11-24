import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/network/server_time_sync.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/violation_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';

final Provider<FranchiseRepository> franchiseRepositoryProvider =
    Provider<FranchiseRepository>((ref) {
  return FranchiseRepository(apiClient: ref.watch(apiClientProvider));
});

/// Reactive state for the Operator Garage Dashboard & Offline Digital Wallet.
class GarageState {
  const GarageState({
    this.franchises = const [],
    this.settings = const PortalSettings(),
    this.cachedUser,
    this.selectedFilter = GarageFilter.all,
    this.isLoading = true,
    this.isRefreshing = false,
    this.isOfflineFallback = false,
    this.errorMessage,
    this.lastSyncedAt,
  });

  final List<FranchiseRecord> franchises;
  final PortalSettings settings;
  final MobileUser? cachedUser;
  final GarageFilter selectedFilter;
  final bool isLoading;
  final bool isRefreshing;
  final bool isOfflineFallback;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  /// Number of units currently occupying ordinance fleet slots.
  int get slotOccupyingCount =>
      franchises.where((f) => f.countsTowardQuota).length;

  int get maxUnits => settings.maxUnitsPerOperator;

  bool get hasAvailableSlot => slotOccupyingCount < maxUnits;

  List<FranchiseRecord> get activeUnits =>
      franchises.where((f) => f.filterCategory == GarageFilter.active).toList();

  List<FranchiseRecord> get inProgressUnits => franchises
      .where((f) => f.filterCategory == GarageFilter.inProgress)
      .toList();

  List<FranchiseRecord> get pastArchivedUnits => franchises
      .where((f) => f.filterCategory == GarageFilter.pastArchived)
      .toList();

  List<FranchiseRecord> get filteredUnits {
    switch (selectedFilter) {
      case GarageFilter.all:
        return franchises;
      case GarageFilter.active:
        return activeUnits;
      case GarageFilter.inProgress:
        return inProgressUnits;
      case GarageFilter.pastArchived:
        return pastArchivedUnits;
    }
  }

  /// Picks the single highest-priority unit requiring operator action for the top callout.
  FranchiseRecord? get priorityActionUnit {
    FranchiseRecord? firstWhereOrNull(bool Function(FranchiseRecord) test) {
      for (final f in franchises) {
        if (test(f)) return f;
      }
      return null;
    }

    return firstWhereOrNull((f) => f.status == 'For Payment') ??
        firstWhereOrNull((f) => f.status == 'Ready for Pickup') ??
        firstWhereOrNull((f) => f.isRejectedNeedsFix || f.isRefilableRenewal) ??
        firstWhereOrNull((f) => f.status == 'Suspended') ??
        firstWhereOrNull((f) => f.status == 'Expired') ??
        firstWhereOrNull(
          (f) => f.isWithinRenewalWindow(settings.renewalReminderDays),
        ) ??
        firstWhereOrNull((f) => f.status == 'For Signing') ??
        firstWhereOrNull((f) => f.status == 'Cancellation Requested');
  }

  /// Units eligible to display inside the Offline Digital Wallet (MTOP E-Copy / E-Receipt).
  List<FranchiseRecord> get walletEligibleUnits => franchises
      .where((f) => f.hasApprovedECopy || f.hasOfficialReceipt)
      .toList();

  GarageState copyWith({
    List<FranchiseRecord>? franchises,
    PortalSettings? settings,
    MobileUser? cachedUser,
    GarageFilter? selectedFilter,
    bool? isLoading,
    bool? isRefreshing,
    bool? isOfflineFallback,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastSyncedAt,
  }) {
    return GarageState(
      franchises: franchises ?? this.franchises,
      settings: settings ?? this.settings,
      cachedUser: cachedUser ?? this.cachedUser,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isOfflineFallback: isOfflineFallback ?? this.isOfflineFallback,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class GarageController extends StateNotifier<GarageState> {
  GarageController({
    required FranchiseRepository franchiseRepository,
    required SettingsRepository settingsRepository,
    required OfflineWalletCache walletCache,
    required MobileUser? user,
    PortalSettings initialSettings = const PortalSettings(),
    bool Function()? sessionIsCurrent,
    int Function()? readSessionGeneration,
    Future<void> Function()? revalidateSession,
  })  : _franchiseRepo = franchiseRepository,
        _settingsRepo = settingsRepository,
        _walletCache = walletCache,
        _sessionIsCurrent = sessionIsCurrent,
        _readSessionGeneration = readSessionGeneration,
        _revalidateSession = revalidateSession,
        _user = user,
        super(
          GarageState(
            settings: initialSettings,
            cachedUser: user,
          ),
        ) {
    if (_user != null) {
      _hydrateFromCache();
      loadGarage();
    } else {
      state = state.copyWith(isLoading: false);
    }
  }

  final FranchiseRepository _franchiseRepo;
  final SettingsRepository _settingsRepo;
  final OfflineWalletCache _walletCache;
  final MobileUser? _user;
  final bool Function()? _sessionIsCurrent;
  final int Function()? _readSessionGeneration;
  final Future<void> Function()? _revalidateSession;

  void _hydrateFromCache() {
    final uid = _user?.id ?? '';
    if (uid.isEmpty) return;
    final snapshot = _walletCache.readSnapshot(uid);
    if (snapshot == null || !snapshot.hasData) return;

    state = state.copyWith(
      franchises: snapshot.franchises,
      settings: snapshot.settings,
      cachedUser: snapshot.user ?? _user,
      lastSyncedAt: snapshot.lastSyncedAt,
      isLoading: false,
    );
  }

  void setFilter(GarageFilter filter) {
    if (state.selectedFilter == filter) return;
    state = state.copyWith(selectedFilter: filter);
  }

  /// Syncs live franchises and municipal settings from backend and updates Hive cache.
  Future<void> loadGarage({bool isPullToRefresh = false}) async {
    final user = _user;
    if (user == null) {
      state = state.copyWith(isLoading: false, isRefreshing: false);
      return;
    }

    final hasCached = state.franchises.isNotEmpty || state.lastSyncedAt != null;
    final generation = _readSessionGeneration?.call();
    bool canUseResult() => mounted && _sessionIsCurrent?.call() != false &&
        generation == _readSessionGeneration?.call();
    state = state.copyWith(
      isLoading: !isPullToRefresh && !hasCached,
      isRefreshing: isPullToRefresh || hasCached,
      clearError: true,
    );

    try {
      if (isPullToRefresh) await _revalidateSession?.call();
      if (!canUseResult()) return;
      final franchisesFuture = _franchiseRepo.fetchMyFranchises();
      final settingsFuture = _settingsRepo.fetchSettingsOrThrow().then<PortalSettings?>(
            (value) => value,
            onError: (_) => null,
          );

      final franchises = await franchisesFuture;
      final fetchedSettings = await settingsFuture;
      if (!canUseResult()) return;
      final resolvedSettings = fetchedSettings ?? state.settings;
      final syncedAt = ServerTimeSync.nowUtc();

      await _walletCache.writeSnapshot(
        user.id,
        OfflineWalletSnapshot(
          user: user,
          franchises: franchises,
          settings: resolvedSettings,
          lastSyncedAt: syncedAt,
        ),
      );

      if (!canUseResult()) return;
      state = state.copyWith(
        franchises: franchises,
        settings: resolvedSettings,
        cachedUser: user,
        lastSyncedAt: syncedAt,
        isLoading: false,
        isRefreshing: false,
        isOfflineFallback: false,
        clearError: true,
      );
    } catch (err) {
      if (!canUseResult()) return;
      final apiErr = ApiClient.mapDioError(err);
      final cachedSnapshot = _walletCache.readSnapshot(user.id);
      if (cachedSnapshot != null && cachedSnapshot.hasData) {
        state = state.copyWith(
          franchises: cachedSnapshot.franchises,
          settings: cachedSnapshot.settings,
          cachedUser: cachedSnapshot.user ?? user,
          lastSyncedAt: cachedSnapshot.lastSyncedAt,
          isLoading: false,
          isRefreshing: false,
          isOfflineFallback: true,
          errorMessage: apiErr.message,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          isOfflineFallback: false,
          errorMessage: apiErr.message,
        );
      }
    }
  }

  /// Withdraws an unpaid pending application and reloads the garage.
  Future<void> withdrawPendingApplication({
    required String franchiseId,
    required String cancelReason,
  }) async {
    await _franchiseRepo.withdrawPendingApplication(
      franchiseId: franchiseId,
      cancelReason: cancelReason,
    );
    await loadGarage(isPullToRefresh: true);
  }

  /// Submits a voluntary franchise surrender request (typed letter or file upload).
  Future<void> requestVoluntaryCancellation({
    required String franchiseId,
    required String reason,
    String customReason = '',
    String remarks = '',
    String? letterText,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    await _franchiseRepo.requestVoluntaryCancellation(
      franchiseId: franchiseId,
      reason: reason,
      customReason: customReason,
      remarks: remarks,
      letterText: letterText,
      fileBytes: fileBytes,
      fileName: fileName,
      mimeType: mimeType,
    );
    await loadGarage(isPullToRefresh: true);
  }

  /// Fetches live per-unit violation and 3-tier sanction history.
  Future<ViolationHistoryResponse> fetchViolationHistory(String franchiseId) {
    return _franchiseRepo.fetchViolationHistory(franchiseId);
  }
}

final StateNotifierProvider<GarageController, GarageState>
    garageControllerProvider =
    StateNotifierProvider<GarageController, GarageState>((ref) {
  final (user, settings) = ref.watch(authControllerProvider.select((s) => (s.user, s.settings)));
  final storage = ref.watch(secureSessionStorageProvider);
  return GarageController(
    franchiseRepository: ref.watch(franchiseRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    walletCache: ref.watch(offlineWalletCacheProvider),
    user: user,
    initialSettings: settings,
    sessionIsCurrent: () => ref.read(authControllerProvider).user?.id == user?.id,
    readSessionGeneration: () => storage.generation,
    revalidateSession: () => ref.read(authControllerProvider.notifier).revalidateOfflineSession(),
  );
});
