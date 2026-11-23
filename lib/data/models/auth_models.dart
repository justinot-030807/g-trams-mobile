import 'package:gtrams_mobile/core/constants/gasan_constants.dart';

/// Authenticated operator or TODA president profile model.
class MobileUser {
  const MobileUser({
    required this.id,
    required this.name,
    required this.role,
    this.contact = '',
    this.email = '',
    this.address = '',
    this.todaAssociation = 'NON-TODA',
    this.bodyNumber = '',
    this.profilePic = '',
    this.emergencyContact = '',
    this.recoveryEmail = '',
    this.recoveryPhone = '',
    this.backupContact = '',
    this.authProvider = 'local',
    this.hasLocalPassword = true,
    this.isContactVerified = false,
    this.isRecoveryEmailVerified = false,
    this.isRecoveryPhoneVerified = false,
  });

  final String id;
  final String name;
  final String role;
  final String contact;
  final String email;
  final String address;
  final String todaAssociation;
  final String bodyNumber;
  final String profilePic;
  final String emergencyContact;
  final String recoveryEmail;
  final String recoveryPhone;
  final String backupContact;
  final String authProvider;
  final bool hasLocalPassword;
  final bool isContactVerified;
  final bool isRecoveryEmailVerified;
  final bool isRecoveryPhoneVerified;

  bool get isTodaPresident => GasanConstants.isTodaPresidentRole(role);
  bool get isAllowedMobileUser => GasanConstants.isAllowedMobileRole(role);

  bool get isGoogleOnlyAccount =>
      !hasLocalPassword || authProvider.toLowerCase() == 'google';

  bool get hasAnyRecoveryContact =>
      effectiveRecoveryEmail.isNotEmpty || effectiveRecoveryPhone.isNotEmpty;

  String get effectiveRecoveryEmail {
    if (recoveryEmail.trim().isNotEmpty) return recoveryEmail.trim();
    if (recoveryPhone.trim().isEmpty && backupContact.contains('@')) {
      return backupContact.trim().toLowerCase();
    }
    return '';
  }

  String get effectiveRecoveryPhone {
    if (recoveryPhone.trim().isNotEmpty) return recoveryPhone.trim();
    if (recoveryEmail.trim().isEmpty &&
        backupContact.trim().isNotEmpty &&
        !backupContact.contains('@')) {
      return backupContact.trim();
    }
    return '';
  }

  String get roleDisplayTitle =>
      isTodaPresident ? 'TODA President' : 'Registered Operator';

  MobileUser copyWith({
    String? name,
    String? contact,
    String? email,
    String? address,
    String? todaAssociation,
    String? bodyNumber,
    String? profilePic,
    String? emergencyContact,
    String? recoveryEmail,
    String? recoveryPhone,
    String? backupContact,
    String? authProvider,
    bool? hasLocalPassword,
    bool? isContactVerified,
    bool? isRecoveryEmailVerified,
    bool? isRecoveryPhoneVerified,
  }) {
    return MobileUser(
      id: id,
      name: name ?? this.name,
      role: role,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      address: address ?? this.address,
      todaAssociation: todaAssociation ?? this.todaAssociation,
      bodyNumber: bodyNumber ?? this.bodyNumber,
      profilePic: profilePic ?? this.profilePic,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      recoveryPhone: recoveryPhone ?? this.recoveryPhone,
      backupContact: backupContact ?? this.backupContact,
      authProvider: authProvider ?? this.authProvider,
      hasLocalPassword: hasLocalPassword ?? this.hasLocalPassword,
      isContactVerified: isContactVerified ?? this.isContactVerified,
      isRecoveryEmailVerified:
          isRecoveryEmailVerified ?? this.isRecoveryEmailVerified,
      isRecoveryPhoneVerified:
          isRecoveryPhoneVerified ?? this.isRecoveryPhoneVerified,
    );
  }

  factory MobileUser.fromJson(Map<String, dynamic> json) {
    final nested = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    final rawRole = (nested['role'] ?? json['role'] ?? 'operator').toString();
    final provider = (nested['authProvider'] ?? 'local').toString().trim();
    final hasLocalRaw = nested['hasLocalPassword'];
    final hasLocal = hasLocalRaw is bool
        ? hasLocalRaw
        : provider.toLowerCase() != 'google';

    return MobileUser(
      id: (nested['_id'] ?? nested['id'] ?? json['_id'] ?? json['id'] ?? '')
          .toString(),
      name: (nested['name'] ??
              nested['fullName'] ??
              json['name'] ??
              json['fullName'] ??
              'Operator')
          .toString()
          .trim(),
      role: GasanConstants.normalizeRole(rawRole),
      contact: (nested['contact'] ?? json['contact'] ?? '').toString().trim(),
      email: (nested['email'] ?? json['email'] ?? '').toString().trim(),
      address: (nested['address'] ?? '').toString().trim(),
      todaAssociation:
          (nested['todaAssociation'] ?? 'NON-TODA').toString().trim(),
      bodyNumber: (nested['bodyNumber'] ?? '').toString().trim(),
      profilePic:
          (nested['profilePic'] ?? nested['profilePicUrl'] ?? '').toString(),
      emergencyContact: (nested['emergencyContact'] ?? '').toString().trim(),
      recoveryEmail: (nested['recoveryEmail'] ?? '').toString().trim(),
      recoveryPhone: (nested['recoveryPhone'] ?? '').toString().trim(),
      backupContact: (nested['backupContact'] ?? '').toString().trim(),
      authProvider: provider,
      hasLocalPassword: hasLocal,
      isContactVerified: nested['isContactVerified'] == true,
      isRecoveryEmailVerified: nested['isRecoveryEmailVerified'] == true,
      isRecoveryPhoneVerified: nested['isRecoveryPhoneVerified'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'role': role,
        'contact': contact,
        'email': email,
        'address': address,
        'todaAssociation': todaAssociation,
        'bodyNumber': bodyNumber,
        'profilePic': profilePic,
        'emergencyContact': emergencyContact,
        'recoveryEmail': recoveryEmail,
        'recoveryPhone': recoveryPhone,
        'backupContact': backupContact,
        'authProvider': authProvider,
        'hasLocalPassword': hasLocalPassword,
        'isContactVerified': isContactVerified,
        'isRecoveryEmailVerified': isRecoveryEmailVerified,
        'isRecoveryPhoneVerified': isRecoveryPhoneVerified,
      };
}

/// Live result of `POST /api/v1/auth/verify-roster` during registration.
class RosterVerificationResult {
  const RosterVerificationResult({
    required this.verified,
    required this.status,
    required this.message,
    this.advisory,
  });

  final bool verified;
  final String status;
  final String message;
  final Map<String, dynamic>? advisory;

  factory RosterVerificationResult.fromJson(Map<String, dynamic> json) {
    final advisoryRaw = json['advisory'];
    return RosterVerificationResult(
      verified: json['verified'] == true,
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      advisory: advisoryRaw is Map
          ? Map<String, dynamic>.from(advisoryRaw)
          : null,
    );
  }
}

/// Official municipal advisory configured in `SystemSettings.announcements`.
class PortalAnnouncement {
  const PortalAnnouncement({
    required this.title,
    required this.desc,
    this.type = 'info',
    this.date = 'General Advisory',
    this.isActive = true,
  });

  final String title;
  final String desc;
  final String type;
  final String date;
  final bool isActive;

  factory PortalAnnouncement.fromJson(Map<String, dynamic> json) {
    return PortalAnnouncement(
      title: (json['title'] ?? 'Municipal Advisory').toString().trim(),
      desc: (json['desc'] ?? json['description'] ?? '').toString().trim(),
      type: (json['type'] ?? 'info').toString().trim().toLowerCase(),
      date: (json['date'] ?? 'General Advisory').toString().trim(),
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'desc': desc,
        'type': type,
        'date': date,
        'isActive': isActive,
      };
}

/// Public municipal configuration returned by `GET /api/v1/settings`.
class PortalSettings {
  const PortalSettings({
    this.maintenanceMode = false,
    this.fiscalYear = '2026',
    this.franchiseFee = 500,
    this.penaltyRate = 0,
    this.maxUnitsPerOperator = 2,
    this.renewalReminderDays = 60,
    this.validityNew = 3,
    this.validityRenew = 1,
    this.announcements = const [],
  });

  final bool maintenanceMode;
  final String fiscalYear;
  final num franchiseFee;
  final num penaltyRate;
  final int maxUnitsPerOperator;
  final int renewalReminderDays;
  final int validityNew;
  final int validityRenew;
  final List<PortalAnnouncement> announcements;

  List<PortalAnnouncement> get activeAnnouncements =>
      announcements.where((a) => a.isActive && a.title.isNotEmpty).toList();

  factory PortalSettings.fromJson(Map<String, dynamic> json) {
    final d = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawAnnouncements = d['announcements'];
    final announcements = rawAnnouncements is List
        ? rawAnnouncements
            .whereType<Map>()
            .map(
              (item) => PortalAnnouncement.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <PortalAnnouncement>[];
    return PortalSettings(
      maintenanceMode: d['maintenanceMode'] == true,
      fiscalYear: (d['fiscalYear'] ?? '2026').toString(),
      franchiseFee: _toNum(d['franchiseFee'], 500),
      penaltyRate: _toNum(d['penaltyRate'], 0),
      maxUnitsPerOperator: _toInt(d['maxUnitsPerOperator'], 2),
      renewalReminderDays:
          _toInt(d['renewalReminderDays'] ?? d['expiryWarningDays'], 60),
      validityNew: _toInt(d['validityNew'], 3),
      validityRenew: _toInt(d['validityRenew'], 1),
      announcements: announcements,
    );
  }

  Map<String, dynamic> toJson() => {
        'maintenanceMode': maintenanceMode,
        'fiscalYear': fiscalYear,
        'franchiseFee': franchiseFee,
        'penaltyRate': penaltyRate,
        'maxUnitsPerOperator': maxUnitsPerOperator,
        'renewalReminderDays': renewalReminderDays,
        'validityNew': validityNew,
        'validityRenew': validityRenew,
        'announcements': announcements.map((a) => a.toJson()).toList(),
      };

  static num _toNum(dynamic val, num fallback) {
    if (val is num) return val;
    return num.tryParse(val?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic val, int fallback) {
    if (val is int) return val;
    return int.tryParse(val?.toString() ?? '') ?? fallback;
  }
}

/// Metadata returned by `POST /api/v1/auth/forgot-password`.
class ForgotPasswordResponse {
  const ForgotPasswordResponse({
    required this.destination,
    required this.message,
    this.resetChallengeToken = '',
    this.hasBackupContact = false,
    this.hasRecoveryEmail = false,
    this.hasRecoveryPhone = false,
    this.maskedRecoveryEmail = '',
    this.maskedRecoveryPhone = '',
    this.maskedPrimaryContact = '',
    this.recoveryUsed = false,
  });

  final String destination;
  final String message;
  final String resetChallengeToken;
  final bool hasBackupContact;
  final bool hasRecoveryEmail;
  final bool hasRecoveryPhone;
  final String maskedRecoveryEmail;
  final String maskedRecoveryPhone;
  final String maskedPrimaryContact;
  final bool recoveryUsed;

  factory ForgotPasswordResponse.fromJson(
    Map<String, dynamic> json,
    String fallbackContact,
  ) {
    return ForgotPasswordResponse(
      destination: (json['destination'] ?? fallbackContact).toString(),
      message: (json['message'] ?? 'Verification code sent successfully.')
          .toString(),
      resetChallengeToken: (json['resetChallengeToken'] ?? '').toString(),
      hasBackupContact: json['hasBackupContact'] == true ||
          json['hasRecoveryEmail'] == true ||
          json['hasRecoveryPhone'] == true,
      hasRecoveryEmail: json['hasRecoveryEmail'] == true,
      hasRecoveryPhone: json['hasRecoveryPhone'] == true,
      maskedRecoveryEmail: (json['maskedRecoveryEmail'] ?? '').toString(),
      maskedRecoveryPhone: (json['maskedRecoveryPhone'] ?? '').toString(),
      maskedPrimaryContact:
          (json['maskedPrimaryContact'] ?? fallbackContact).toString(),
      recoveryUsed: json['recoveryUsed'] == true,
    );
  }
}

/// Deactivated account navigation payload.
class DeactivatedAccountArgs {
  const DeactivatedAccountArgs({
    required this.contact,
    this.reason = '',
    this.appealStatus = 'none',
    this.hasLocalPassword = true,
    this.authProvider = 'local',
  });

  final String contact;
  final String reason;
  final String appealStatus;
  final bool hasLocalPassword;
  final String authProvider;
}
