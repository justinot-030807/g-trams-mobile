import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';

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
  });

  final String email;
  final String name;
  final String googleId;
  final String picture;
  final String onboardingToken;
}

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required SecureSessionStorage sessionStorage,
  })  : _api = apiClient,
        _storage = sessionStorage;

  final ApiClient _api;
  final SecureSessionStorage _storage;

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

  Future<MobileUser> signInWithGoogle() async {
    if (kIsWeb) {
      throw const ApiException(
        message:
            'Google Sign-In is configured for Android APK devices. Use email/phone login in Chrome preview.',
      );
    }

    try {
      var serverClientId = AppConfig.defaultGoogleClientId;
      try {
        final cfg = await _api.dio.get<Map<String, dynamic>>('/auth/google-client-id');
        final fetched = (cfg.data?['clientId'] ?? '').toString().trim();
        if (fetched.isNotEmpty) serverClientId = fetched;
      } catch (_) {
        // Fallback to AppConfig.defaultGoogleClientId
      }

      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile', 'openid'],
        serverClientId: serverClientId,
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        throw const ApiException(message: 'Google sign-in was cancelled.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        throw const ApiException(
          message:
              'Unable to verify Google credentials. Confirm Android SHA-1 is registered in Google Cloud Console.',
        );
      }

      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/google',
        data: {
          if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
          if (accessToken != null && accessToken.isNotEmpty)
            'accessToken': accessToken,
        },
      );

      final data = res.data ?? const <String, dynamic>{};
      if (data['needsOnboarding'] == true) {
        final profile = data['googleProfile'] is Map<String, dynamic>
            ? data['googleProfile'] as Map<String, dynamic>
            : const <String, dynamic>{};
        throw GoogleOnboardingRequiredException(
          email: (profile['email'] ?? account.email).toString(),
          name: (profile['name'] ?? account.displayName ?? '').toString(),
          googleId: (profile['googleId'] ?? account.id).toString(),
          picture: (profile['picture'] ?? account.photoUrl ?? '').toString(),
          onboardingToken: (profile['onboardingToken'] ?? '').toString(),
        );
      }

      return await _handleAuthenticatedPayload(data);
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
    required String password,
    required String message,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/appeal',
        data: {
          'contact': GasanConstants.canonicalizeContact(contact),
          'password': password,
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

  Future<MobileUser> _handleAuthenticatedPayload(
    Map<String, dynamic> data,
  ) async {
    final token = (data['token'] ?? '').toString().trim();
    if (token.isEmpty) {
      throw const ApiException(
        message: 'Server did not return a valid session token.',
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
