import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/biometric_service.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, biometricLocked }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.settings = const PortalSettings(),
    this.biometricSupported = false,
    this.sessionRevokedReason,
  });

  final AuthStatus status;
  final MobileUser? user;
  final PortalSettings settings;
  final bool biometricSupported;
  final String? sessionRevokedReason;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    MobileUser? user,
    bool clearUser = false,
    PortalSettings? settings,
    bool? biometricSupported,
    String? sessionRevokedReason,
    bool clearRevokedReason = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      settings: settings ?? this.settings,
      biometricSupported: biometricSupported ?? this.biometricSupported,
      sessionRevokedReason: clearRevokedReason
          ? null
          : (sessionRevokedReason ?? this.sessionRevokedReason),
    );
  }
}

final Provider<SecureSessionStorage> secureSessionStorageProvider =
    Provider<SecureSessionStorage>((ref) => SecureSessionStorage());

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureSessionStorageProvider);
  return ApiClient(
    sessionStorage: storage,
    onUnauthorized: () {
      ref.read(authControllerProvider.notifier).forceLogout();
    },
  );
});

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    sessionStorage: ref.watch(secureSessionStorageProvider),
  );
});

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) {
  return SettingsRepository(apiClient: ref.watch(apiClientProvider));
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthRepository authRepository,
    required SettingsRepository settingsRepository,
    required BiometricService biometricService,
    required OfflineWalletCache walletCache,
    required WizardDraftCache wizardDraftCache,
  })  : _authRepo = authRepository,
        _settingsRepo = settingsRepository,
        _biometric = biometricService,
        _walletCache = walletCache,
        _wizardDraftCache = wizardDraftCache,
        super(const AuthState());

  final AuthRepository _authRepo;
  final SettingsRepository _settingsRepo;
  final BiometricService _biometric;
  final OfflineWalletCache _walletCache;
  final WizardDraftCache _wizardDraftCache;

  /// Bootstraps server settings, biometric capability, and any existing session.
  Future<void> bootstrap({required bool requireBiometricLock}) async {
    final results = await Future.wait([
      _settingsRepo.fetchSettings(),
      _authRepo.restoreSession(),
      _biometric.isAvailable(),
    ]);

    final settings = results[0] as PortalSettings;
    final user = results[1] as MobileUser?;
    final bioAvailable = results[2] as bool;

    if (user != null) {
      final shouldLock = requireBiometricLock && bioAvailable;
      state = state.copyWith(
        status: shouldLock
            ? AuthStatus.biometricLocked
            : AuthStatus.authenticated,
        user: user,
        settings: settings,
        biometricSupported: bioAvailable,
      );
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        settings: settings,
        biometricSupported: bioAvailable,
      );
    }
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    final ok = await _biometric.authenticate(localizedReason: reason);
    if (ok && state.user != null) {
      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    }
    return false;
  }

  Future<MobileUser> login({
    required String contact,
    required String password,
  }) async {
    final user = await _authRepo.login(contact: contact, password: password);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearRevokedReason: true,
    );
    return user;
  }

  Future<MobileUser> signInWithGoogle() async {
    final user = await _authRepo.signInWithGoogle();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearRevokedReason: true,
    );
    return user;
  }

  void setAuthenticatedUser(MobileUser user) {
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearRevokedReason: true,
    );
  }

  Future<MobileUser?> refreshProfile() async {
    try {
      final fresh = await _authRepo.fetchProfile();
      state = state.copyWith(user: fresh);
      return fresh;
    } catch (_) {
      return state.user;
    }
  }

  void updateCachedUser(MobileUser user) {
    state = state.copyWith(user: user);
  }

  Future<String?> readSessionToken() => _authRepo.readSessionToken();

  void clearRevokedReason() {
    if (state.sessionRevokedReason != null) {
      state = state.copyWith(clearRevokedReason: true);
    }
  }

  Future<void> logout() async {
    final uid = state.user?.id ?? '';
    await _authRepo.logout();
    if (uid.isNotEmpty) {
      await _walletCache.clearUser(uid);
      await _wizardDraftCache.clearAllForUser(uid);
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearRevokedReason: true,
    );
  }

  void forceLogout({String? reason}) {
    if (state.status == AuthStatus.unauthenticated && reason == null) return;
    final uid = state.user?.id ?? '';
    _authRepo.logout();
    if (uid.isNotEmpty) {
      _walletCache.clearUser(uid);
      _wizardDraftCache.clearAllForUser(uid);
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      sessionRevokedReason: reason,
    );
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    biometricService: ref.watch(biometricServiceProvider),
    walletCache: ref.watch(offlineWalletCacheProvider),
    wizardDraftCache: ref.watch(wizardDraftCacheProvider),
  );
});
