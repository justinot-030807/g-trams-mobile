import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';

/// Sanction tier applied to an individual violation citation.
class ViolationSanction {
  const ViolationSanction({
    required this.type,
    required this.resultingStatus,
    this.fineAmount = 0,
    this.suspensionDays = 0,
    this.suspensionStartDate,
    this.suspensionEndDate,
  });

  /// `Warning`, `Suspension`, or `Revocation`.
  final String type;

  /// `Active - Under Warning`, `Suspended`, or `Revoked`.
  final String resultingStatus;
  final num fineAmount;
  final int suspensionDays;
  final DateTime? suspensionStartDate;
  final DateTime? suspensionEndDate;

  factory ViolationSanction.fromJson(Map<String, dynamic> json) {
    return ViolationSanction(
      type: (json['type'] ?? 'Warning').toString().trim(),
      resultingStatus:
          (json['resultingStatus'] ?? 'Active - Under Warning').toString().trim(),
      fineAmount: _toNum(json['fineAmount']),
      suspensionDays: _toInt(json['suspensionDays']),
      suspensionStartDate:
          ManilaDateFormatter.tryParseIso(json['suspensionStartDate']),
      suspensionEndDate:
          ManilaDateFormatter.tryParseIso(json['suspensionEndDate']),
    );
  }
}

/// Single municipal violation citation record from `GET /api/v1/violations/history/:franchiseId`.
class ViolationRecord {
  const ViolationRecord({
    required this.id,
    required this.violationType,
    required this.offenseNumber,
    required this.sanction,
    this.plateNo = '',
    this.bodyNumber = '',
    this.driverName = '',
    this.violationCode = 'OTHER',
    this.severity = 'Medium',
    this.isGrave = false,
    this.remarks = '',
    this.evidenceUrl = '',
    this.recordedByName = 'OVM Franchising Staff (LLSA I)',
    this.status = 'Active',
    this.settledAt,
    this.settledNotes = '',
    this.createdAt,
  });

  final String id;
  final String plateNo;
  final String bodyNumber;
  final String driverName;
  final String violationType;
  final String violationCode;
  final String severity;
  final bool isGrave;
  final int offenseNumber;
  final ViolationSanction sanction;
  final String remarks;
  final String evidenceUrl;
  final String recordedByName;

  /// `Active`, `Settled`, or `Lifted`.
  final String status;
  final DateTime? settledAt;
  final String settledNotes;
  final DateTime? createdAt;

  bool get isActive => status == 'Active';

  String get offenseLabel {
    final n = offenseNumber;
    final suffix = n == 1
        ? 'st'
        : n == 2
            ? 'nd'
            : n == 3
                ? 'rd'
                : 'th';
    return '$n$suffix Offense';
  }

  factory ViolationRecord.fromJson(Map<String, dynamic> json) {
    final sanctionRaw = json['sanction'];
    final sanction = sanctionRaw is Map
        ? ViolationSanction.fromJson(Map<String, dynamic>.from(sanctionRaw))
        : const ViolationSanction(
            type: 'Warning',
            resultingStatus: 'Active - Under Warning',
          );

    // Ensure "BPLO" is never rendered even if legacy DB rows carry old labels.
    var rawRecorder = (json['recordedByName'] ?? '').toString().trim();
    if (rawRecorder.isEmpty && json['recordedBy'] is Map) {
      rawRecorder =
          ((json['recordedBy'] as Map)['name'] ?? '').toString().trim();
    }
    if (rawRecorder.isEmpty || rawRecorder.toUpperCase().contains('BPLO')) {
      rawRecorder = 'OVM Franchising Staff (LLSA I)';
    }

    return ViolationRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      plateNo: (json['plateNo'] ?? '').toString().trim(),
      bodyNumber: (json['bodyNumber'] ?? '').toString().trim(),
      driverName: (json['driverName'] ?? '').toString().trim(),
      violationType: (json['violationType'] ?? 'Ordinance Violation').toString().trim(),
      violationCode: (json['violationCode'] ?? 'OTHER').toString().trim(),
      severity: (json['severity'] ?? 'Medium').toString().trim(),
      isGrave: json['isGrave'] == true,
      offenseNumber: _toInt(json['offenseNumber'], fallback: 1),
      sanction: sanction,
      remarks: (json['remarks'] ?? '').toString().trim(),
      evidenceUrl: (json['evidenceUrl'] ?? '').toString().trim(),
      recordedByName: rawRecorder,
      status: (json['status'] ?? 'Active').toString().trim(),
      settledAt: ManilaDateFormatter.tryParseIso(json['settledAt']),
      settledNotes: (json['settledNotes'] ?? '').toString().trim(),
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
    );
  }
}

/// Configurable 3-Tier Progressive Discipline policy returned by backend.
class ViolationPolicySummary {
  const ViolationPolicySummary({
    this.secondOffenseFine = 500,
    this.secondOffenseSuspensionDays = 15,
  });

  final num secondOffenseFine;
  final int secondOffenseSuspensionDays;

  factory ViolationPolicySummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ViolationPolicySummary();
    final tiers = json['tiers'];
    if (tiers is! Map) return const ViolationPolicySummary();
    final second = tiers['secondOffense'];
    if (second is! Map) return const ViolationPolicySummary();
    return ViolationPolicySummary(
      secondOffenseFine: _toNum(second['defaultFine'], fallback: 500),
      secondOffenseSuspensionDays:
          _toInt(second['defaultSuspensionDays'], fallback: 15),
    );
  }
}

/// Full response payload of `GET /api/v1/violations/history/:franchiseId`.
class ViolationHistoryResponse {
  const ViolationHistoryResponse({
    required this.franchiseId,
    required this.plateNo,
    required this.franchiseStatus,
    this.fullName = '',
    this.todaName = '',
    this.driverName = '',
    this.currentSanction = '',
    this.suspensionEndDate,
    this.activeViolationsCount = 0,
    this.totalViolationsCount = 0,
    this.nextOffenseNumber = 1,
    this.expectedSanction = 'Warning',
    this.expectedStatus = 'Active - Under Warning',
    this.history = const [],
    this.policy = const ViolationPolicySummary(),
  });

  final String franchiseId;
  final String fullName;
  final String plateNo;
  final String todaName;
  final String franchiseStatus;
  final String driverName;
  final String currentSanction;
  final DateTime? suspensionEndDate;
  final int activeViolationsCount;
  final int totalViolationsCount;
  final int nextOffenseNumber;
  final String expectedSanction;
  final String expectedStatus;
  final List<ViolationRecord> history;
  final ViolationPolicySummary policy;

  factory ViolationHistoryResponse.fromJson(Map<String, dynamic> json) {
    final franchise = json['franchise'] is Map
        ? Map<String, dynamic>.from(json['franchise'] as Map)
        : <String, dynamic>{};

    final rawHistory = json['history'];
    final history = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map((e) => ViolationRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ViolationRecord>[];

    final rawPolicy = json['policy'] is Map
        ? Map<String, dynamic>.from(json['policy'] as Map)
        : null;

    return ViolationHistoryResponse(
      franchiseId: (franchise['_id'] ?? franchise['id'] ?? '').toString(),
      fullName: (franchise['fullName'] ?? '').toString().trim(),
      plateNo: (franchise['plateNo'] ?? '').toString().trim(),
      todaName: (franchise['todaName'] ?? '').toString().trim(),
      franchiseStatus: (franchise['status'] ?? 'Active').toString().trim(),
      driverName: (franchise['driverName'] ?? '').toString().trim(),
      currentSanction: (franchise['currentSanction'] ?? '').toString().trim(),
      suspensionEndDate:
          ManilaDateFormatter.tryParseIso(franchise['suspensionEndDate']),
      activeViolationsCount: _toInt(json['activeViolationsCount']),
      totalViolationsCount: _toInt(json['totalViolationsCount']),
      nextOffenseNumber: _toInt(json['nextOffenseNumber'], fallback: 1),
      expectedSanction:
          (json['expectedSanction'] ?? 'Warning').toString().trim(),
      expectedStatus: (json['expectedStatus'] ?? 'Active - Under Warning')
          .toString()
          .trim(),
      history: history,
      policy: ViolationPolicySummary.fromJson(rawPolicy),
    );
  }
}

num _toNum(dynamic raw, {num fallback = 0}) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '') ?? fallback;
}

int _toInt(dynamic raw, {int fallback = 0}) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? fallback;
}
