import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';

/// Official TODA member removal / disaffiliation reasons matching backend Mongoose enum.
const List<String> kTodaRemovalReasons = [
  'No longer operating / Inactive',
  'Transferred to another TODA or municipality',
  'Violation of TODA Bylaws / Disciplinary action',
  'Unauthorized / Unendorsed membership claim',
  'Failure to attend meetings / Settle association dues',
  'Other (Specified in details)',
];

/// Aggregate KPI statistics for a TODA President's association (`GET /toda/my-members`).
class TodaDirectoryStats {
  const TodaDirectoryStats({
    this.totalMembers = 0,
    this.totalUnits = 0,
    this.activeUnits = 0,
    this.pendingUnits = 0,
    this.expiredUnits = 0,
  });

  final int totalMembers;
  final int totalUnits;
  final int activeUnits;
  final int pendingUnits;
  final int expiredUnits;

  factory TodaDirectoryStats.fromJson(Map<String, dynamic> json) {
    return TodaDirectoryStats(
      totalMembers: _toInt(json['totalMembers']),
      totalUnits: _toInt(json['totalUnits']),
      activeUnits: _toInt(json['activeUnits']),
      pendingUnits: _toInt(json['pendingUnits']),
      expiredUnits: _toInt(json['expiredUnits']),
    );
  }
}

/// Summary of an individual tricycle unit under a TODA member.
class TodaMemberUnit {
  const TodaMemberUnit({
    required this.id,
    this.plateNo = '',
    this.make = '',
    this.made = '',
    this.zone = '',
    this.status = 'Pending',
  });

  final String id;
  final String plateNo;
  final String make;
  final String made;
  final String zone;
  final String status;

  CivicStatusTone get statusTone {
    switch (status) {
      case 'Active':
        return CivicStatusTone.active;
      case 'Active - Under Warning':
      case 'Pending':
      case 'Pending for Approval':
      case 'For Payment':
      case 'For Signing':
      case 'Ready for Pickup':
      case 'Cancellation Requested':
        return CivicStatusTone.inProgress;
      case 'Expired':
      case 'Suspended':
      case 'Revoked':
        return CivicStatusTone.danger;
      default:
        return CivicStatusTone.neutral;
    }
  }

  factory TodaMemberUnit.fromJson(Map<String, dynamic> json) {
    return TodaMemberUnit(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      plateNo: (json['plateNo'] ?? '').toString().trim(),
      make: (json['make'] ?? '').toString().trim(),
      made: (json['made'] ?? '').toString().trim(),
      zone: (json['zone'] ?? '').toString().trim(),
      status: (json['status'] ?? 'Pending').toString().trim(),
    );
  }
}

/// Member profile returned inside `GET /api/v1/toda/my-members`.
class TodaMemberProfile {
  const TodaMemberProfile({
    required this.id,
    required this.name,
    this.contact = '',
    this.address = '',
    this.email = '',
    this.bodyNumber = '',
    this.plateNo = '',
    this.role = 'operator',
    this.isPresident = false,
    this.isCurrentUser = false,
    this.isRosterEndorsed = false,
    this.registeredInApp = true,
    this.units = const [],
    this.createdAt,
  });

  final String id;
  final String name;
  final String contact;
  final String address;
  final String email;
  final String bodyNumber;
  final String plateNo;
  final String role;
  final bool isPresident;
  final bool isCurrentUser;
  final bool isRosterEndorsed;
  final bool registeredInApp;
  final List<TodaMemberUnit> units;
  final DateTime? createdAt;

  /// Only non-president operators other than the current user may be nominated for removal.
  bool get canRequestRemoval => !isPresident && !isCurrentUser;

  String get primaryPlateNo {
    if (plateNo.isNotEmpty) return plateNo;
    for (final u in units) {
      if (u.plateNo.isNotEmpty) return u.plateNo;
    }
    return '';
  }

  factory TodaMemberProfile.fromJson(Map<String, dynamic> json) {
    final rawUnits = json['units'];
    final units = rawUnits is List
        ? rawUnits
            .whereType<Map>()
            .map((e) => TodaMemberUnit.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <TodaMemberUnit>[];

    return TodaMemberProfile(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['operatorName'] ?? 'Member').toString().trim(),
      contact: (json['contact'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
      bodyNumber: (json['bodyNumber'] ?? '').toString().trim(),
      plateNo: (json['plateNo'] ?? '').toString().trim(),
      role: (json['role'] ?? 'operator').toString().trim(),
      isPresident: json['isPresident'] == true,
      isCurrentUser: json['isCurrentUser'] == true,
      isRosterEndorsed: json['isRosterEndorsed'] == true,
      registeredInApp: json['registeredInApp'] != false,
      units: units,
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
    );
  }
}

/// Full response payload for `GET /api/v1/toda/my-members`.
class TodaMembersDirectory {
  const TodaMembersDirectory({
    required this.todaName,
    this.stats = const TodaDirectoryStats(),
    this.members = const [],
  });

  final String todaName;
  final TodaDirectoryStats stats;
  final List<TodaMemberProfile> members;

  factory TodaMembersDirectory.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'] is Map
        ? Map<String, dynamic>.from(json['stats'] as Map)
        : <String, dynamic>{};
    final rawMembers = json['members'];
    final members = rawMembers is List
        ? rawMembers
            .whereType<Map>()
            .map((e) => TodaMemberProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <TodaMemberProfile>[];
    return TodaMembersDirectory(
      todaName: (json['todaName'] ?? 'NON-TODA').toString().trim(),
      stats: TodaDirectoryStats.fromJson(rawStats),
      members: members,
    );
  }
}

/// Single editable member row from `POST /toda/scan-roster` or manual entry.
class ExtractedRosterMember {
  const ExtractedRosterMember({
    required this.operatorName,
    this.bodyNumber = '',
    this.plateNo = '',
    this.confidence = 0.95,
  });

  final String operatorName;
  final String bodyNumber;
  final String plateNo;
  final double confidence;

  ExtractedRosterMember copyWith({
    String? operatorName,
    String? bodyNumber,
    String? plateNo,
    double? confidence,
  }) {
    return ExtractedRosterMember(
      operatorName: operatorName ?? this.operatorName,
      bodyNumber: bodyNumber ?? this.bodyNumber,
      plateNo: plateNo ?? this.plateNo,
      confidence: confidence ?? this.confidence,
    );
  }

  factory ExtractedRosterMember.fromJson(Map<String, dynamic> json) {
    final name = (json['operatorName'] ?? json['name'] ?? '').toString().trim();
    final body = (json['bodyNumber'] ?? json['unitNo'] ?? '').toString().trim();
    final plate = (json['plateNo'] ?? '').toString().trim();
    final confRaw = json['confidence'];
    final conf = confRaw is num ? confRaw.toDouble() : 0.95;
    return ExtractedRosterMember(
      operatorName: name,
      bodyNumber: body,
      plateNo: plate,
      confidence: conf,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': operatorName.trim(),
        'operatorName': operatorName.trim(),
        'bodyNumber': bodyNumber.trim().toUpperCase(),
        'unitNo': bodyNumber.trim().toUpperCase(),
        'plateNo': plateNo.trim().toUpperCase(),
        'confidence': confidence,
      };
}

/// Response returned by `POST /api/v1/toda/scan-roster`.
class RosterScanResult {
  const RosterScanResult({
    required this.success,
    this.extractedMembers = const [],
    this.todaAssociation = '',
    this.ocrNotes = '',
    this.message = '',
  });

  final bool success;
  final List<ExtractedRosterMember> extractedMembers;
  final String todaAssociation;
  final String ocrNotes;
  final String message;

  int get extractedCount => extractedMembers.length;

  factory RosterScanResult.fromJson(Map<String, dynamic> json) {
    final rawList = json['extractedMembers'];
    final members = rawList is List
        ? rawList
            .whereType<Map>()
            .map(
              (e) =>
                  ExtractedRosterMember.fromJson(Map<String, dynamic>.from(e)),
            )
            .where((m) => m.operatorName.isNotEmpty)
            .toList()
        : <ExtractedRosterMember>[];

    return RosterScanResult(
      success: json['success'] == true,
      extractedMembers: members,
      todaAssociation: (json['todaAssociation'] ?? '').toString().trim(),
      ocrNotes: (json['ocrNotes'] ?? '').toString().trim(),
      message: (json['message'] ?? '').toString().trim(),
    );
  }
}

/// Historical roster submission record (`GET /api/v1/toda/my-submissions`).
class TodaSubmissionRecord {
  const TodaSubmissionRecord({
    required this.id,
    required this.fileName,
    required this.status,
    this.todaAssociation = '',
    this.extractedCount = 0,
    this.ocrNotes = '',
    this.createdAt,
  });

  final String id;
  final String fileName;
  final String status;
  final String todaAssociation;
  final int extractedCount;
  final String ocrNotes;
  final DateTime? createdAt;

  CivicStatusTone get statusTone {
    switch (status) {
      case 'Approved':
        return CivicStatusTone.active;
      case 'Rejected':
        return CivicStatusTone.danger;
      default:
        return CivicStatusTone.inProgress;
    }
  }

  factory TodaSubmissionRecord.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['extractedMembers'];
    final fallbackCount = membersRaw is List ? membersRaw.length : 0;
    return TodaSubmissionRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      fileName: (json['fileName'] ?? 'Roster Submission').toString().trim(),
      status: (json['status'] ?? 'Pending').toString().trim(),
      todaAssociation: (json['todaAssociation'] ?? '').toString().trim(),
      extractedCount: _toInt(json['extractedCount'], fallback: fallbackCount),
      ocrNotes: (json['ocrNotes'] ?? '').toString().trim(),
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
    );
  }
}

/// Member removal / disaffiliation request record (`GET /api/v1/toda/removal-requests`).
class TodaRemovalRequestRecord {
  const TodaRemovalRequestRecord({
    required this.id,
    required this.memberName,
    required this.reason,
    required this.details,
    required this.status,
    this.todaName = '',
    this.adminRemarks = '',
    this.createdAt,
    this.reviewedAt,
  });

  final String id;
  final String todaName;
  final String memberName;
  final String reason;
  final String details;
  final String status;
  final String adminRemarks;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  CivicStatusTone get statusTone {
    switch (status) {
      case 'Approved':
        return CivicStatusTone.active;
      case 'Rejected':
        return CivicStatusTone.danger;
      default:
        return CivicStatusTone.inProgress;
    }
  }

  factory TodaRemovalRequestRecord.fromJson(Map<String, dynamic> json) {
    return TodaRemovalRequestRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      todaName: (json['todaName'] ?? '').toString().trim(),
      memberName: (json['memberName'] ?? 'Operator').toString().trim(),
      reason: (json['reason'] ?? '').toString().trim(),
      details: (json['details'] ?? '').toString().trim(),
      status: (json['status'] ?? 'Pending').toString().trim(),
      adminRemarks: (json['adminRemarks'] ?? '').toString().trim(),
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
      reviewedAt: ManilaDateFormatter.tryParseIso(json['reviewedAt']),
    );
  }
}

/// Single franchise item returned by public QR verification (`GET /api/v1/auth/verify/:id`).
class VerifiedFranchiseSummary {
  const VerifiedFranchiseSummary({
    required this.plateNo,
    required this.status,
    this.make = '',
    this.todaName = '',
    this.mtopNo = '',
    this.approvalDate,
    this.expiryDate,
    this.isCurrentlyValid = false,
    this.validityStatus = 'INACTIVE',
    this.isRenewalPending = false,
    this.renewalStatus = '',
  });

  final String plateNo;
  final String make;
  final String status;
  final String todaName;
  final String mtopNo;
  final DateTime? approvalDate;
  final DateTime? expiryDate;
  final bool isCurrentlyValid;
  final String validityStatus;
  final bool isRenewalPending;
  final String renewalStatus;

  CivicStatusTone get tone {
    if (isCurrentlyValid || validityStatus == 'VALID') {
      return CivicStatusTone.active;
    }
    if (validityStatus == 'PENDING' || status == 'Active - Under Warning') {
      return CivicStatusTone.inProgress;
    }
    return CivicStatusTone.danger;
  }

  factory VerifiedFranchiseSummary.fromJson(Map<String, dynamic> json) {
    return VerifiedFranchiseSummary(
      plateNo: (json['plateNo'] ?? '').toString().trim(),
      make: (json['make'] ?? '').toString().trim(),
      status: (json['status'] ?? 'Inactive').toString().trim(),
      todaName: (json['todaName'] ?? '').toString().trim(),
      mtopNo: (json['mtopNo'] ?? '').toString().trim(),
      approvalDate: ManilaDateFormatter.tryParseIso(json['approvalDate']),
      expiryDate: ManilaDateFormatter.tryParseIso(json['expiryDate']),
      isCurrentlyValid: json['isCurrentlyValid'] == true,
      validityStatus: (json['validityStatus'] ?? 'INACTIVE').toString().trim(),
      isRenewalPending: json['isRenewalPending'] == true,
      renewalStatus: (json['renewalStatus'] ?? '').toString().trim(),
    );
  }
}

/// Public QR verification record returned by `GET /api/v1/auth/verify/:id`.
class OperatorVerificationResult {
  const OperatorVerificationResult({
    required this.name,
    required this.todaAssociation,
    required this.validityStatus,
    this.role = 'operator',
    this.profilePic = '',
    this.contact = '',
    this.isActive = true,
    this.isCurrentlyValid = false,
    this.franchises = const [],
  });

  final String name;
  final String role;
  final String todaAssociation;
  final String profilePic;
  final String contact;
  final bool isActive;
  final bool isCurrentlyValid;

  /// `'VALID'`, `'PENDING'`, `'EXPIRED'`, `'INACTIVE'`, `'INACTIVE_OWNER'`, `'UNVERIFIED_EXPIRY'`.
  final String validityStatus;
  final List<VerifiedFranchiseSummary> franchises;

  CivicStatusTone get overallTone {
    if (isCurrentlyValid || validityStatus == 'VALID') {
      return CivicStatusTone.active;
    }
    if (validityStatus == 'PENDING') return CivicStatusTone.inProgress;
    return CivicStatusTone.danger;
  }

  /// Extracts a clean operator/franchise/MTOP/plate ID from either a full QR URL
  /// (`https://g-trams-official.vercel.app/verify/<id>`) or a raw user input string.
  static String extractVerificationId(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final verifyIdx = uri.pathSegments.indexWhere(
        (s) => s.toLowerCase() == 'verify',
      );
      if (verifyIdx >= 0 && verifyIdx + 1 < uri.pathSegments.length) {
        return Uri.decodeComponent(uri.pathSegments[verifyIdx + 1]).trim();
      }
    }

    final match = RegExp(r'/verify/([^/?#]+)', caseSensitive: false)
        .firstMatch(trimmed);
    if (match != null && match.group(1) != null) {
      return Uri.decodeComponent(match.group(1)!).trim();
    }

    return trimmed;
  }

  factory OperatorVerificationResult.fromJson(Map<String, dynamic> json) {
    final rawFranchises = json['franchises'];
    final franchises = rawFranchises is List
        ? rawFranchises
            .whereType<Map>()
            .map(
              (e) => VerifiedFranchiseSummary.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList()
        : <VerifiedFranchiseSummary>[];

    return OperatorVerificationResult(
      name: (json['name'] ?? json['fullName'] ?? 'Registered Operator')
          .toString()
          .trim(),
      role: (json['role'] ?? 'operator').toString().trim(),
      todaAssociation: (json['todaAssociation'] ?? 'NON-TODA').toString().trim(),
      profilePic: (json['profilePic'] ?? '').toString().trim(),
      contact: (json['contact'] ?? '').toString().trim(),
      isActive: json['isActive'] != false,
      isCurrentlyValid: json['isCurrentlyValid'] == true,
      validityStatus: (json['validityStatus'] ?? 'INACTIVE').toString().trim(),
      franchises: franchises,
    );
  }
}

int _toInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
