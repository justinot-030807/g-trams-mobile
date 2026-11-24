import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';

/// Credentials returned by native Google Sign-In before server verification.
class GoogleAuthCredentials {
  const GoogleAuthCredentials({
    required this.email,
    this.name = '',
    this.googleId = '',
    this.picture = '',
    this.idToken,
    this.accessToken,
  });

  final String email;
  final String name;
  final String googleId;
  final String picture;
  final String? idToken;
  final String? accessToken;
}

typedef GoogleSignInRunner = Future<GoogleAuthCredentials?> Function(
  String serverClientId,
);

/// Result of `POST /api/v1/auth/request-recovery-otp`.
class RecoveryOtpResult {
  const RecoveryOtpResult({
    required this.destination,
    required this.message,
  });

  final String destination;
  final String message;
}

/// Result of `PUT /api/v1/auth/change-password`.
class ChangePasswordResult {
  const ChangePasswordResult({
    required this.message,
    required this.newToken,
  });

  final String message;
  final String newToken;
}

/// Thrown when a municipal staff role attempts to sign in on the Operator/TODA APK.
class StaffRoleBlockedException implements Exception {
  const StaffRoleBlockedException({
    required this.rawRole,
    required this.displayRole,
  });

  final String rawRole;
  final String displayRole;
}

/// Returned when Google Sign-In succeeds for a brand-new operator who must finish onboarding.
class GoogleOnboardingRequiredException implements Exception {
  const GoogleOnboardingRequiredException({
    required this.email,
    required this.name,
    required this.googleId,
    this.picture = '',
    this.onboardingToken = '',
    this.idToken = '',
    this.accessToken = '',
    this.message = '',
  });

  final String email;
  final String name;
  final String googleId;
  final String picture;
  final String onboardingToken;
  final String idToken;
  final String accessToken;
  final String message;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureSessionStorage sessionStorage,
    GoogleSignInRunner? googleSignInRunner,
    bool? isWebOverride,
  })  : _api = apiClient,
        _storage = sessionStorage,
        _googleSignInRunner = googleSignInRunner,
        _isWebOverride = isWebOverride;

  final ApiClient _api;
  final SecureSessionStorage _storage;
  final GoogleSignInRunner? _googleSignInRunner;
  final bool? _isWebOverride;
  String? _cachedGoogleClientId;

  bool get _isWeb => _isWebOverride ?? kIsWeb;

  Future<MobileUser> login({
    required String contact,
    required String password,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'contact': GasanConstants.canonicalizeContact(contact),
          'password': password,
        },
      );
      return await _handleAuthenticatedPayload(res.data ?? const {});
    } catch (e) {
      if (e is StaffRoleBlockedException) rethrow;
      throw ApiClient.mapDioError(e);
    }
  }

  /// Resolves the backend's active Web OAuth Client ID (`GOOGLE_CLIENT_ID`)
  /// so Android `serverClientId` always matches server-side `id_token` `aud` checks.
  Future<String> resolveGoogleClientId({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedGoogleClientId != null &&
        _cachedGoogleClientId!.isNotEmpty) {
      return _cachedGoogleClientId!;
    }
    var serverClientId = AppConfig.defaultGoogleClientId.trim();
    try {
      final cfg = await _api.dio.get<Map<String, dynamic>>(
        '/auth/google-client-id',
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final body = cfg.data ?? const <String, dynamic>{};
      final nested = body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : const <String, dynamic>{};
      final fetched = (body['clientId'] ??
              nested['clientId'] ??
              body['googleClientId'] ??
              nested['googleClientId'] ??
              '')
          .toString()
          .trim();
      if (fetched.isNotEmpty) {
        serverClientId = fetched;
        _cachedGoogleClientId = fetched;
      }
    } catch (_) {
      // Fallback to AppConfig.defaultGoogleClientId when offline or cold-starting.
    }
    return serverClientId;
  }

  /// Maps Android/iOS `google_sign_in` `PlatformException` codes to clear,
  /// actionable operator-facing messages.
  static ApiException mapGooglePlatformException(PlatformException e) {
    final code = e.code.trim().toLowerCase();
    final combined = '${e.message ?? ''} ${e.details ?? ''}'.toLowerCase();

    bool hasNumericCode(String target) =>
        RegExp('(?:^|[^0-9])$target(?:[^0-9]|\$)').hasMatch(combined);

    if (code == GoogleSignIn.kSignInCanceledError ||
        code == 'canceled' ||
        code == 'cancelled' ||
        hasNumericCode('12501') ||
        combined.contains('sign_in_cancelled') ||
        combined.contains('sign_in_canceled')) {
      return const ApiException(
        message:
            'Google sign-in was cancelled. Tap "Continue with Google" to choose your account.',
      );
    }

    if (hasNumericCode('10') || combined.contains('developer_error')) {
      return const ApiException(
        message:
            'Google Sign-In configuration mismatch (Error 10). Confirm this Android APK\'s SHA-1 fingerprint and OAuth Client ID are registered in Google Cloud Console.',
      );
    }

    if (code == GoogleSignIn.kNetworkError ||
        hasNumericCode('7') ||
        combined.contains('network_error')) {
      return const ApiException(
        message:
            'Network error during Google Sign-In. Check your internet connection and try again.',
      );
    }

    if (hasNumericCode('12500')) {
      return const ApiException(
        message:
            'Google Sign-In could not start (Error 12500). Update Google Play Services or confirm your Google account has access to this app.',
      );
    }

    if (hasNumericCode('12502')) {
      return const ApiException(
        message:
            'Google Sign-In is already in progress. Please wait a moment and try again.',
      );
    }

    if (code == GoogleSignInAccount.kUserRecoverableAuthError ||
        code == GoogleSignInAccount.kFailedToRecoverAuthError) {
      return const ApiException(
        message:
            'Google account authorization did not finish. Please try signing in again.',
      );
    }

    if (code == GoogleSignIn.kSignInFailedError) {
      return const ApiException(
        message:
            'Google Sign-In failed on this device. Confirm Google Play Services is updated and Android SHA-1 / OAuth Client ID settings match the server.',
      );
    }

    final cleanDetail = (e.message ?? '').trim();
    if (cleanDetail.isNotEmpty &&
        !cleanDetail.contains('com.google.android.gms')) {
      return ApiException(message: cleanDetail);
    }
    return ApiException(
      message: 'Google Sign-In failed (${e.code}). Please try again.',
    );
  }

  /// Acquires fresh Google credentials on Android (clearing stale cached
  /// sign-in sessions first to prevent silent-cancel loops).
  Future<GoogleAuthCredentials> acquireGoogleCredentials() async {
    if (_isWeb) {
      throw const ApiException(
        message:
            'Google Sign-In is configured for Android APK devices. Use email/phone login in Chrome preview.',
      );
    }

    final serverClientId = await resolveGoogleClientId();

    try {
      GoogleAuthCredentials? creds;
      if (_googleSignInRunner != null) {
        creds = await _googleSignInRunner(serverClientId);
      } else {
        final googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: serverClientId,
        );

        // Clear any stale cached GoogleSignInClient session so Android opens
        // a clean account picker and avoids silent-cancel loops.
        try {
          await googleSignIn.signOut();
        } catch (_) {
          // Ignore signOut errors prior to interactive signIn.
        }

        final account = await googleSignIn.signIn();
        if (account != null) {
          final auth = await account.authentication;
          creds = GoogleAuthCredentials(
            email: account.email,
            name: account.displayName ?? '',
            googleId: account.id,
            picture: account.photoUrl ?? '',
            idToken: auth.idToken,
            accessToken: auth.accessToken,
          );
        }
      }

      if (creds == null) {
        throw const ApiException(
          message:
              'Google sign-in was cancelled. Tap "Continue with Google" to choose your account.',
        );
      }

      final idToken = (creds.idToken ?? '').trim();
      final accessToken = (creds.accessToken ?? '').trim();
      if (idToken.isEmpty && accessToken.isEmpty) {
        throw const ApiException(
          message:
              'Unable to verify Google credentials. Confirm this APK\'s Android SHA-1 and Web Client ID are registered in Google Cloud Console.',
        );
      }

      return creds;
    } on PlatformException catch (e) {
      throw mapGooglePlatformException(e);
    }
  }

  Future<MobileUser> signInWithGoogle() async {
    try {
      final creds = await acquireGoogleCredentials();
      final idToken = (creds.idToken ?? '').trim();
      final accessToken = (creds.accessToken ?? '').trim();
      final email = creds.email.trim().toLowerCase();

      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {
          if (idToken.isNotEmpty) 'idToken': idToken,
          if (idToken.isNotEmpty) 'credential': idToken,
          if (accessToken.isNotEmpty) 'accessToken': accessToken,
          if (email.isNotEmpty) 'email': email,
          'googleProfile': {
            'email': email,
            'name': creds.name.trim(),
            'picture': creds.picture.trim(),
            'googleId': creds.googleId.trim(),
          },
        },
      );

      return await _handleGoogleResponse(
        res.data ?? const <String, dynamic>{},
        fallbackEmail: email,
        fallbackName: creds.name.trim(),
        fallbackGoogleId: creds.googleId.trim(),
        fallbackPicture: creds.picture.trim(),
        fallbackIdToken: idToken,
        fallbackAccessToken: accessToken,
      );
    } on PlatformException catch (e) {
      throw mapGooglePlatformException(e);
    } catch (e) {
      if (e is StaffRoleBlockedException ||
          e is GoogleOnboardingRequiredException ||
          e is ApiException) {
        rethrow;
      }
      throw ApiClient.mapDioError(e);
    }
  }

  /// Completes Google onboarding for a brand-new operator after TODA roster
  /// verification by submitting `onboardingData` + `googleProfile`/`onboardingToken`
  /// to `POST /api/v1/auth/google`.
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
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanAddress = address.trim();
    final cleanToda = todaAssociation.trim();
    final cleanBody = bodyNumber.trim().toUpperCase();
    final cleanOnboardingToken = onboardingToken.trim();
    final cleanIdToken = idToken.trim();
    final cleanAccessToken = accessToken.trim();
    final rawPhone = (emergencyContact ?? '').trim();
    var cleanPhone =
        rawPhone.isNotEmpty ? GasanConstants.canonicalizeContact(rawPhone) : '';
    if (cleanPhone.startsWith('+639') && cleanPhone.length == 13) {
      cleanPhone = '0${cleanPhone.substring(3)}';
    } else if (cleanPhone.startsWith('639') && cleanPhone.length == 12) {
      cleanPhone = '0${cleanPhone.substring(2)}';
    }

    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {
          'email': cleanEmail,
          if (cleanOnboardingToken.isNotEmpty)
            'onboardingToken': cleanOnboardingToken,
          if (cleanIdToken.isNotEmpty) 'idToken': cleanIdToken,
          if (cleanIdToken.isNotEmpty) 'credential': cleanIdToken,
          if (cleanAccessToken.isNotEmpty) 'accessToken': cleanAccessToken,
          'googleProfile': {
            'email': cleanEmail,
            if (cleanOnboardingToken.isNotEmpty)
              'onboardingToken': cleanOnboardingToken,
            'name': cleanName,
            'picture': picture.trim(),
            'googleId': googleId.trim(),
          },
          'onboardingData': {
            'fullName': cleanName,
            'name': cleanName,
            'address': cleanAddress,
            'todaAssociation': cleanToda,
            'bodyNumber': cleanBody,
            'email': cleanEmail,
            if (cleanOnboardingToken.isNotEmpty)
              'onboardingToken': cleanOnboardingToken,
            'contact': cleanEmail,
            if (cleanPhone.isNotEmpty) 'emergencyContact': cleanPhone,
            if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
            'role': 'operator',
          },
        },
      );

      return await _handleGoogleResponse(
        res.data ?? const <String, dynamic>{},
        fallbackEmail: cleanEmail,
        fallbackName: cleanName,
        fallbackGoogleId: googleId.trim(),
        fallbackPicture: picture.trim(),
        fallbackIdToken: cleanIdToken,
        fallbackAccessToken: cleanAccessToken,
      );
    } catch (e) {
      if (e is StaffRoleBlockedException ||
          e is GoogleOnboardingRequiredException ||
          e is ApiException) {
        rethrow;
      }
      throw ApiClient.mapDioError(e);
    }
  }

  Future<RosterVerificationResult> verifyTodaRoster({
    required String fullName,
    required String todaAssociation,
    required String bodyNumber,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/verify-roster',
        data: {
          'fullName': fullName.trim(),
          'todaAssociation': todaAssociation.trim(),
          'bodyNumber': bodyNumber.trim().toUpperCase(),
        },
      );
      return RosterVerificationResult.fromJson(res.data ?? const {});
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<String> registerOperator({
    required String fullName,
    required String address,
    required String todaAssociation,
    required String bodyNumber,
    required String contact,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final cleanName = fullName.trim();
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'name': cleanName,
          'fullName': cleanName,
          'address': address.trim(),
          'todaAssociation': todaAssociation.trim(),
          'bodyNumber': bodyNumber.trim().toUpperCase(),
          'contact': GasanConstants.canonicalizeContact(contact),
          'password': password,
          'confirmPassword': confirmPassword,
          'role': 'operator',
        },
      );
      return (res.data?['message'] ?? 'Verification code sent successfully.')
          .toString();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<MobileUser?> verifyRegistrationOtp({
    required String contact,
    required String otp,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        data: {
          'contact': GasanConstants.canonicalizeContact(contact),
          'otp': otp.trim(),
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final token = (data['token'] ?? '').toString().trim();
      if (token.isNotEmpty) {
        return await _handleAuthenticatedPayload(data);
      }
      return null;
    } catch (e) {
      if (e is StaffRoleBlockedException) rethrow;
      throw ApiClient.mapDioError(e);
    }
  }

  Future<ForgotPasswordResponse> requestPasswordReset({
    required String contact,
    bool useBackupContact = false,
    String? preferredChannel,
    String? recoveryTarget,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {
          'contact': GasanConstants.canonicalizeContact(contact),
          if (useBackupContact) 'useBackupContact': true,
          if (preferredChannel != null && preferredChannel.isNotEmpty)
            'preferredChannel': preferredChannel,
          if (recoveryTarget != null && recoveryTarget.isNotEmpty)
            'recoveryTarget': GasanConstants.canonicalizeContact(recoveryTarget),
        },
      );
      return ForgotPasswordResponse.fromJson(res.data ?? const {}, contact.trim());
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<String> resetPassword({
    required String contact,
    required String otp,
    required String newPassword,
    String? resetChallengeToken,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {
          'contact': GasanConstants.canonicalizeContact(contact),
          'otp': otp.trim(),
          'newPassword': newPassword,
          if (resetChallengeToken != null && resetChallengeToken.isNotEmpty)
            'resetChallengeToken': resetChallengeToken,
        },
      );
      return (res.data?['message'] ?? 'Password reset successful.').toString();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<String> submitDeactivationAppeal({
    required String contact,
    String password = '',
    required String message,
    String? googleIdToken,
    String? googleAccessToken,
  }) async {
    try {
      final cleanIdToken = (googleIdToken ?? '').trim();
      final cleanAccessToken = (googleAccessToken ?? '').trim();
      final hasGoogleReauth =
          cleanIdToken.isNotEmpty || cleanAccessToken.isNotEmpty;

      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/appeal',
        data: {
          if (contact.trim().isNotEmpty)
            'contact': GasanConstants.canonicalizeContact(contact),
          if (!hasGoogleReauth && password.isNotEmpty) 'password': password,
          if (cleanIdToken.isNotEmpty) 'googleCredential': cleanIdToken,
          if (cleanIdToken.isNotEmpty) 'idToken': cleanIdToken,
          if (cleanAccessToken.isNotEmpty)
            'googleAccessToken': cleanAccessToken,
          if (cleanAccessToken.isNotEmpty) 'accessToken': cleanAccessToken,
          'message': message.trim(),
        },
      );
      return (res.data?['message'] ?? 'Appeal submitted for review.').toString();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<MobileUser?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) return null;

    final cachedJson = await _storage.readUserJson();
    MobileUser? cachedUser;
    if (cachedJson != null) {
      cachedUser = MobileUser.fromJson(cachedJson);
      if (!cachedUser.isAllowedMobileUser) {
        await _storage.clearSession();
        return null;
      }
    }

    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/auth/profile');
      if (res.data != null) {
        final freshUser = MobileUser.fromJson(res.data!);
        if (!freshUser.isAllowedMobileUser) {
          await _storage.clearSession();
          return null;
        }
        await _storage.saveSession(
          token: token,
          role: freshUser.role,
          userJson: freshUser.toJson(),
        );
        _sendHeartbeatBestEffort();
        return freshUser;
      }
    } catch (e) {
      final mapped = ApiClient.mapDioError(e);
      if (mapped.statusCode == 401 || mapped.statusCode == 403) {
        await _storage.clearSession();
        return null;
      }
      // Allow offline session continuation when server is temporarily unreachable.
      return cachedUser;
    }

    return cachedUser;
  }

  Future<void> logout() async {
    await _storage.clearSession();
  }

  Future<String?> readSessionToken() => _storage.readToken();

  Future<MobileUser> fetchProfile() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/auth/profile');
      final freshUser = MobileUser.fromJson(res.data ?? const {});
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        await _storage.saveSession(
          token: token,
          role: freshUser.role,
          userJson: freshUser.toJson(),
        );
      }
      return freshUser;
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  /// Updates operator or TODA president profile, avatar photo, or recovery contacts.
  /// Mirrors exact multipart/field contract of `PUT /api/v1/auth/profile`.
  Future<MobileUser> updateProfile({
    String? name,
    String? address,
    String? contact,
    String? emergencyContact,
    String? recoveryEmail,
    String? recoveryPhone,
    bool clearRecovery = false,
    String? currentPassword,
    String? verificationTarget,
    String? recoveryOtp,
    String? language,
    String? theme,
    ScannedDocumentAttachment? profilePic,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (name != null) fields['name'] = name.trim();
      if (address != null) fields['address'] = address.trim();
      if (contact != null) {
        fields['contact'] = GasanConstants.canonicalizeContact(contact);
      }
      if (emergencyContact != null) {
        fields['emergencyContact'] = emergencyContact.trim();
      }
      if (recoveryEmail != null) {
        fields['recoveryEmail'] = recoveryEmail.trim().toLowerCase();
      }
      if (recoveryPhone != null) {
        fields['recoveryPhone'] = recoveryPhone.trim();
      }
      if (clearRecovery) {
        fields['clearRecovery'] = 'true';
      }
      if (currentPassword != null && currentPassword.isNotEmpty) {
        fields['currentPassword'] = currentPassword;
      }
      if (verificationTarget != null && verificationTarget.isNotEmpty) {
        fields['verificationTarget'] =
            GasanConstants.canonicalizeContact(verificationTarget);
      }
      if (recoveryOtp != null && recoveryOtp.isNotEmpty) {
        fields['recoveryOtp'] = recoveryOtp.trim();
      }
      if (language != null) fields['language'] = language;
      if (theme != null) fields['theme'] = theme;

      final Response<Map<String, dynamic>> res;
      if (profilePic != null) {
        final form = FormData.fromMap({
          ...fields,
          'profilePic': MultipartFile.fromBytes(
            profilePic.bytes,
            filename: profilePic.fileName,
          ),
        });
        res = await _api.dio.put<Map<String, dynamic>>(
          '/auth/profile',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
      } else {
        res = await _api.dio.put<Map<String, dynamic>>(
          '/auth/profile',
          data: fields,
        );
      }

      final updated = MobileUser.fromJson(res.data ?? const {});
      final token = await _storage.readToken();
      if (token != null && token.isNotEmpty) {
        await _storage.saveSession(
          token: token,
          role: updated.role,
          userJson: updated.toJson(),
        );
      }
      return updated;
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<RecoveryOtpResult> requestRecoveryOtp(String target) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/request-recovery-otp',
        data: {'target': GasanConstants.canonicalizeContact(target)},
      );
      final data = res.data ?? const <String, dynamic>{};
      return RecoveryOtpResult(
        destination: (data['destination'] ?? target).toString(),
        message: (data['message'] ?? 'Verification code sent.').toString(),
      );
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  /// Calls `PUT /api/v1/auth/change-password` with `{ oldPassword, newPassword }`,
  /// persists the returned fresh JWT token, and returns it for Socket.IO reconnect.
  Future<ChangePasswordResult> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/auth/change-password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final newToken = (data['token'] ?? '').toString().trim();
      final message =
          (data['message'] ?? 'Password changed successfully.').toString();

      if (newToken.isNotEmpty) {
        final cachedUser = await _storage.readUserJson();
        final cachedRole = await _storage.readRole() ?? 'operator';
        if (cachedUser != null) {
          await _storage.saveSession(
            token: newToken,
            role: cachedRole,
            userJson: cachedUser,
          );
        }
      }

      return ChangePasswordResult(message: message, newToken: newToken);
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> raw) {
    final nested = raw['data'];
    if (nested is Map) {
      return <String, dynamic>{
        ...raw,
        ...Map<String, dynamic>.from(nested),
      };
    }
    return raw;
  }

  String _extractSessionToken(Map<String, dynamic> payload) {
    for (final key in const ['token', 'sessionToken', 'jwt']) {
      final candidate = (payload[key] ?? '').toString().trim();
      if (candidate.isNotEmpty) return candidate;
    }
    final nestedData = payload['data'];
    if (nestedData is Map) {
      for (final key in const ['token', 'sessionToken', 'jwt']) {
        final candidate = (nestedData[key] ?? '').toString().trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    final nestedUser = payload['user'];
    if (nestedUser is Map) {
      final candidate = (nestedUser['token'] ?? '').toString().trim();
      if (candidate.isNotEmpty) return candidate;
    }
    return '';
  }

  Future<MobileUser> _handleGoogleResponse(
    Map<String, dynamic> raw, {
    String fallbackEmail = '',
    String fallbackName = '',
    String fallbackGoogleId = '',
    String fallbackPicture = '',
    String fallbackIdToken = '',
    String fallbackAccessToken = '',
  }) async {
    final payload = _unwrapPayload(raw);
    final serverMessage =
        (payload['message'] ?? payload['error'] ?? '').toString().trim();

    if (payload['accountDeactivated'] == true) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Your account has been deactivated.',
        statusCode: 403,
        accountDeactivated: true,
        deactivationContact: (payload['contact'] ?? fallbackEmail).toString(),
        deactivationReason: (payload['reason'] ?? '').toString(),
        appealStatus: (payload['appealStatus'] ?? 'none').toString(),
        hasLocalPassword: payload['hasLocalPassword'] is bool
            ? payload['hasLocalPassword'] as bool
            : false,
        authProvider: (payload['authProvider'] ?? 'google').toString(),
        rawData: raw,
      );
    }

    if (payload['maintenanceMode'] == true) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Portal is currently undergoing system maintenance. Please try again later.',
        statusCode: 503,
        isMaintenance: true,
        rawData: raw,
      );
    }

    final rawProfile = payload['googleProfile'] ?? payload['profile'];
    final profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : const <String, dynamic>{};

    final onboardingToken =
        (profile['onboardingToken'] ?? payload['onboardingToken'] ?? '')
            .toString()
            .trim();
    final token = _extractSessionToken(payload);

    final needsOnboarding = payload['isNewUser'] == true ||
        payload['needsOnboarding'] == true ||
        payload['requiresOnboarding'] == true ||
        payload['onboardingRequired'] == true ||
        (token.isEmpty && onboardingToken.isNotEmpty);

    if (needsOnboarding) {
      throw GoogleOnboardingRequiredException(
        email: (profile['email'] ?? payload['email'] ?? fallbackEmail)
            .toString()
            .trim()
            .toLowerCase(),
        name: (profile['name'] ??
                profile['fullName'] ??
                payload['name'] ??
                fallbackName)
            .toString()
            .trim(),
        googleId:
            (profile['googleId'] ?? profile['sub'] ?? fallbackGoogleId)
                .toString()
                .trim(),
        picture: (profile['picture'] ?? fallbackPicture).toString().trim(),
        onboardingToken: onboardingToken,
        idToken: fallbackIdToken,
        accessToken: fallbackAccessToken,
        message: serverMessage,
      );
    }

    final statusStr = (payload['status'] ?? '').toString().trim().toLowerCase();
    final isPendingApproval = payload['pendingApproval'] == true ||
        payload['requiresApproval'] == true ||
        statusStr == 'pending_approval' ||
        statusStr == 'pending';

    if (isPendingApproval && token.isEmpty) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Your account is pending approval by the Office of the Municipal Vice Mayor (OVM) — LLSA I.',
        rawData: raw,
      );
    }

    if (token.isEmpty) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Unable to complete Google sign-in right now. Please try again.',
        rawData: raw,
      );
    }

    return await _handleAuthenticatedPayload(payload);
  }

  Future<MobileUser> _handleAuthenticatedPayload(
    Map<String, dynamic> rawData,
  ) async {
    final data = _unwrapPayload(rawData);
    final serverMessage =
        (data['message'] ?? data['error'] ?? '').toString().trim();

    if (data['accountDeactivated'] == true) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Your account has been deactivated.',
        statusCode: 403,
        accountDeactivated: true,
        deactivationContact: data['contact']?.toString(),
        deactivationReason: data['reason']?.toString(),
        appealStatus: data['appealStatus']?.toString(),
        hasLocalPassword: data['hasLocalPassword'] is bool
            ? data['hasLocalPassword'] as bool
            : null,
        authProvider: data['authProvider']?.toString(),
        rawData: rawData,
      );
    }

    final token = _extractSessionToken(data);
    if (token.isEmpty) {
      throw ApiException(
        message: serverMessage.isNotEmpty
            ? serverMessage
            : 'Unable to establish your session. Please sign in again.',
        rawData: rawData,
      );
    }

    final user = MobileUser.fromJson(data);
    if (!user.isAllowedMobileUser) {
      await _storage.clearSession();
      throw StaffRoleBlockedException(
        rawRole: user.role,
        displayRole: GasanConstants.blockedRoleDisplayName(user.role),
      );
    }

    await _storage.saveSession(
      token: token,
      role: user.role,
      userJson: user.toJson(),
    );
    _sendHeartbeatBestEffort();
    return user;
  }

  void _sendHeartbeatBestEffort() {
    unawaited(
      _api.dio.post<dynamic>('/auth/heartbeat').then<void>(
        (_) {},
        onError: (Object _) {},
      ),
    );
  }
}
