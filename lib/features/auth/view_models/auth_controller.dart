import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.offlineSession = false,
    this.sessionRevokedReason,
  });

  final AuthStatus status;
  final MobileUser? user;
  final PortalSettings settings;
  final bool biometricSupported;
  final bool offlineSession;
  final String? sessionRevokedReason;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;

  AuthState copyWith({
    AuthStatus? status,
    MobileUser? user,
    bool clearUser = false,
    PortalSettings? settings,
    bool? biometricSupported,
    bool? offlineSession,
    String? sessionRevokedReason,
    bool clearRevokedReason = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      settings: settings ?? this.settings,
      biometricSupported: biometricSupported ?? this.biometricSupported,
      offlineSession: offlineSession ?? this.offlineSession,
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
  Timer? _offlineExpiry;

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
      final deadline = _authRepo.offlineSessionExpiresAt;
      state = state.copyWith(
        status: requireBiometricLock
            ? AuthStatus.biometricLocked
            : AuthStatus.authenticated,
        user: user,
        settings: settings,
        biometricSupported: bioAvailable,
        offlineSession: deadline != null,
      );
      if (deadline != null) {
        _offlineExpiry?.cancel();
        _offlineExpiry = Timer(deadline.difference(DateTime.now().toUtc()), () {
          if (_authRepo.offlineSessionExpiresAt == deadline) forceLogout();
        });
      }
    } else {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearUser: true,
        settings: settings,
        biometricSupported: bioAvailable,
        offlineSession: false,
      );
    }
  }

  Future<bool> unlockWithBiometrics(String reason) async {
    if (state.status != AuthStatus.biometricLocked) return false;
    final lockedUser = state.user;
    final ok = await _biometric.authenticate(localizedReason: reason);
    if (!mounted) return false;
    if (ok && lockedUser != null && identical(state.user, lockedUser) &&
        state.status == AuthStatus.biometricLocked) {
      final deadline = _authRepo.offlineSessionExpiresAt;
      if (deadline != null && !DateTime.now().toUtc().isBefore(deadline)) {
        forceLogout();
        return false;
      }
      state = state.copyWith(status: AuthStatus.authenticated);
      return true;
    }
    return false;
  }

  bool lockOnResume() {
    if (!state.isAuthenticated) return false;
    state = state.copyWith(status: AuthStatus.biometricLocked);
    return true;
  }

  Future<void> revalidateOfflineSession() async {
    final user = state.user;
    final deadline = _authRepo.offlineSessionExpiresAt;
    if (user == null || !state.isAuthenticated || deadline == null) return;
    if (!DateTime.now().toUtc().isBefore(deadline)) {
      forceLogout();
      return;
    }
    try {
      final fresh = await _authRepo.fetchProfile();
      if (!mounted || state.user?.id != user.id) return;
      _offlineExpiry?.cancel();
      state = state.copyWith(
        offlineSession: false,
        user: mapEquals(user.toJson(), fresh.toJson()) ? user : fresh,
      );
    } catch (error) {
      if (!mounted || state.user?.id != user.id) return;
      final status = ApiClient.mapDioError(error).statusCode;
      if (status == 401 || status == 403) forceLogout();
    }
  }

  Future<MobileUser> login({
    required String contact,
    required String password,
  }) async {
    final user = await _authRepo.login(contact: contact, password: password);
    setAuthenticatedUser(user);
    return user;
  }

  Future<MobileUser> signInWithGoogle() async {
    final user = await _authRepo.signInWithGoogle();
    setAuthenticatedUser(user);
    return user;
  }

  Future<MobileUser> completeGoogleOnboarding({
    required String email,
    required String fullName,
    required String address,
    required String todaAssociation,
    required String bodyNumber,
    String googleId = '',
    String picture = '',
    String onboardingToken = '',
    String idToken = '',
    String accessToken = '',
    String? emergencyContact,
  }) async {
    final user = await _authRepo.completeGoogleOnboarding(
      email: email,
      fullName: fullName,
      address: address,
      todaAssociation: todaAssociation,
      bodyNumber: bodyNumber,
      googleId: googleId,
      picture: picture,
      onboardingToken: onboardingToken,
      idToken: idToken,
      accessToken: accessToken,
      emergencyContact: emergencyContact,
    );
    setAuthenticatedUser(user);
    return user;
  }

  void setAuthenticatedUser(MobileUser user) {
    _offlineExpiry?.cancel();
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      clearRevokedReason: true,
      offlineSession: false,
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
    await _endSession();
  }

  void forceLogout({String? reason}) {
    if (state.status == AuthStatus.unauthenticated && reason == null) return;
    unawaited(_endSession(reason: reason));
  }

  Future<void> _endSession({String? reason}) async {
    _offlineExpiry?.cancel();
    final uid = state.user?.id ?? '';
    final cleanup = Future.wait([
      _authRepo.logout(),
      if (uid.isNotEmpty) _walletCache.clearUser(uid),
      if (uid.isNotEmpty) _wizardDraftCache.clearAllForUser(uid),
    ]);
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      offlineSession: false,
      sessionRevokedReason: reason,
      clearRevokedReason: reason == null,
    );
    try {
      await cleanup;
    } catch (_) {
      debugPrint('One or more G-TRAMS session records could not be cleared.');
    }
  }

  @override
  void dispose() {
    _offlineExpiry?.cancel();
    super.dispose();
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
