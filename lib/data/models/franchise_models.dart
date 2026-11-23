import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';

/// Filter categories for the Operator Garage Dashboard.
enum GarageFilter { all, active, inProgress, pastArchived }

/// Official 5-Stage Gasan LGU Franchise Processing Pipeline (Payment Before Signing).
enum LguPipelineStage {
  pending(0),
  forPayment(1),
  forSigning(2),
  readyForPickup(3),
  active(4);

  const LguPipelineStage(this.stepIndex);
  final int stepIndex;
}

/// Official withdrawal reasons for unpaid pending applications (`PUT /franchises/:id/cancel`).
const List<String> kWithdrawApplicationReasons = [
  'Need to correct vehicle or tricycle details',
  'Incomplete requirements / Postponing application',
  'Personal reasons / Attending to other matters',
  'Duplicate or accidental submission',
  'Other reason (Please specify below)',
];

/// Official voluntary surrender reasons (`PUT /franchises/:id/request-cancellation`).
class VoluntaryCancellationReasonOption {
  const VoluntaryCancellationReasonOption({
    required this.value,
    required this.labelEn,
    required this.labelFil,
  });

  final String value;
  final String labelEn;
  final String labelFil;
}

const List<VoluntaryCancellationReasonOption> kVoluntaryCancellationReasons = [
  VoluntaryCancellationReasonOption(
    value: 'Relocation / TODA Transfer',
    labelEn: 'Relocation / TODA Transfer',
    labelFil: 'Paglipat ng TODA o Lugar (Relocation / TODA Transfer)',
  ),
  VoluntaryCancellationReasonOption(
    value: 'Unit Sale / Transfer of Ownership',
    labelEn: 'Unit Sale / Transfer of Ownership',
    labelFil: 'Pagbenta o Paglipat ng Tricycle (Unit Sale / Transfer)',
  ),
  VoluntaryCancellationReasonOption(
    value: 'Voluntary Cessation / Personal Reasons',
    labelEn: 'Voluntary Cessation / Personal Reasons',
    labelFil: 'Kusang Pagtigil sa Pamamasada (Personal Reasons)',
  ),
  VoluntaryCancellationReasonOption(
    value: 'Vehicle Damage / Total Loss',
    labelEn: 'Vehicle Damage / Total Loss',
    labelFil: 'Nasira o Hindi na Magamit ang Unit (Vehicle Damage)',
  ),
  VoluntaryCancellationReasonOption(
    value: 'Other',
    labelEn: 'Other Reason (Specify below)',
    labelFil: 'Iba pang Dahilan (Pakisulat sa ibaba)',
  ),
];

/// Prior-term / renewal payment record embedded in `franchise.paymentHistory`.
class PaymentHistoryItem {
  const PaymentHistoryItem({
    this.termId = '',
    this.officialReceiptNo = '',
    this.amountPaid = 0,
    this.paymentDate,
    this.payerName = '',
    this.paymentMethod = '',
    this.cashierName = '',
    this.paymentRemarks = '',
    this.approvalDate,
    this.expiryDate,
    this.mtopNo = '',
    this.applicationType = 'New',
    this.previousStatus = 'Expired',
    this.todaName = '',
    this.zone = '',
    this.plateNo = '',
  });

  final String termId;
  final String officialReceiptNo;
  final num amountPaid;
  final DateTime? paymentDate;
  final String payerName;
  final String paymentMethod;
  final String cashierName;
  final String paymentRemarks;
  final DateTime? approvalDate;
  final DateTime? expiryDate;
  final String mtopNo;
  final String applicationType;
  final String previousStatus;
  final String todaName;
  final String zone;
  final String plateNo;

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      termId: (json['termId'] ?? '').toString().trim(),
      officialReceiptNo: (json['officialReceiptNo'] ?? '').toString().trim(),
      amountPaid: _parseNum(json['amountPaid']),
      paymentDate: ManilaDateFormatter.tryParseIso(json['paymentDate']),
      payerName: (json['payerName'] ?? '').toString().trim(),
      paymentMethod: (json['paymentMethod'] ?? '').toString().trim(),
      cashierName: (json['cashierName'] ?? '').toString().trim(),
      paymentRemarks: (json['paymentRemarks'] ?? '').toString().trim(),
      approvalDate: ManilaDateFormatter.tryParseIso(json['approvalDate']),
      expiryDate: ManilaDateFormatter.tryParseIso(json['expiryDate']),
      mtopNo: (json['mtopNo'] ?? '').toString().trim(),
      applicationType: (json['applicationType'] ?? 'New').toString().trim(),
      previousStatus: (json['previousStatus'] ?? 'Expired').toString().trim(),
      todaName: (json['todaName'] ?? '').toString().trim(),
      zone: (json['zone'] ?? '').toString().trim(),
      plateNo: (json['plateNo'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'termId': termId,
        'officialReceiptNo': officialReceiptNo,
        'amountPaid': amountPaid,
        'paymentDate': paymentDate?.toIso8601String(),
        'payerName': payerName,
        'paymentMethod': paymentMethod,
        'cashierName': cashierName,
        'paymentRemarks': paymentRemarks,
        'approvalDate': approvalDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'mtopNo': mtopNo,
        'applicationType': applicationType,
        'previousStatus': previousStatus,
        'todaName': todaName,
        'zone': zone,
        'plateNo': plateNo,
      };
}

/// Voluntary surrender / cancellation workflow details from `franchise.cancellationDetails`.
class CancellationDetails {
  const CancellationDetails({
    this.reason = '',
    this.customReason = '',
    this.remarks = '',
    this.letterUrl = '',
    this.letterText = '',
    this.priorStatus = '',
    this.decision = '',
    this.requestedAt,
    this.reviewedAt,
    this.staffNotes = '',
    this.rejectionReason = '',
  });

  final String reason;
  final String customReason;
  final String remarks;
  final String letterUrl;
  final String letterText;
  final String priorStatus;
  final String decision;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String staffNotes;
  final String rejectionReason;

  bool get hasReason => reason.isNotEmpty;

  String get effectiveReason =>
      reason == 'Other' && customReason.isNotEmpty ? customReason : reason;

  factory CancellationDetails.fromJson(Map<String, dynamic> json) {
    return CancellationDetails(
      reason: (json['reason'] ?? '').toString().trim(),
      customReason: (json['customReason'] ?? '').toString().trim(),
      remarks: (json['remarks'] ?? '').toString().trim(),
      letterUrl: (json['letterUrl'] ?? '').toString().trim(),
      letterText: (json['letterText'] ?? '').toString().trim(),
      priorStatus: (json['priorStatus'] ?? '').toString().trim(),
      decision: (json['decision'] ?? '').toString().trim(),
      requestedAt: ManilaDateFormatter.tryParseIso(json['requestedAt']),
      reviewedAt: ManilaDateFormatter.tryParseIso(json['reviewedAt']),
      staffNotes: (json['staffNotes'] ?? '').toString().trim(),
      rejectionReason: (json['rejectionReason'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'reason': reason,
        'customReason': customReason,
        'remarks': remarks,
        'letterUrl': letterUrl,
        'letterText': letterText,
        'priorStatus': priorStatus,
        'decision': decision,
        'requestedAt': requestedAt?.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'staffNotes': staffNotes,
        'rejectionReason': rejectionReason,
      };
}

/// Snapshot of an already-issued permit retained while a renewal application is pending.
class IssuedPermitSnapshot {
  const IssuedPermitSnapshot({
    this.status = '',
    this.expiryDate,
    this.approvalDate,
    this.mtopNo = '',
    this.officialReceiptNo = '',
    this.amountPaid = 0,
    this.paymentDate,
    this.paymentMethod = '',
    this.cashierName = '',
  });

  final String status;
  final DateTime? expiryDate;
  final DateTime? approvalDate;
  final String mtopNo;
  final String officialReceiptNo;
  final num amountPaid;
  final DateTime? paymentDate;
  final String paymentMethod;
  final String cashierName;

  factory IssuedPermitSnapshot.fromJson(Map<String, dynamic> json) {
    return IssuedPermitSnapshot(
      status: (json['status'] ?? '').toString().trim(),
      expiryDate: ManilaDateFormatter.tryParseIso(json['expiryDate']),
      approvalDate: ManilaDateFormatter.tryParseIso(json['approvalDate']),
      mtopNo: (json['mtopNo'] ?? '').toString().trim(),
      officialReceiptNo: (json['officialReceiptNo'] ?? '').toString().trim(),
      amountPaid: _parseNum(json['amountPaid']),
      paymentDate: ManilaDateFormatter.tryParseIso(json['paymentDate']),
      paymentMethod: (json['paymentMethod'] ?? '').toString().trim(),
      cashierName: (json['cashierName'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'expiryDate': expiryDate?.toIso8601String(),
        'approvalDate': approvalDate?.toIso8601String(),
        'mtopNo': mtopNo,
        'officialReceiptNo': officialReceiptNo,
        'amountPaid': amountPaid,
        'paymentDate': paymentDate?.toIso8601String(),
        'paymentMethod': paymentMethod,
        'cashierName': cashierName,
      };
}

/// Complete franchise record returned by `GET /api/v1/franchises/my-franchises`.
class FranchiseRecord {
  const FranchiseRecord({
    required this.id,
    required this.fullName,
    required this.plateNo,
    required this.status,
    this.operatorId = '',
    this.address = '',
    this.zone = '',
    this.made = '',
    this.make = '',
    this.motorNo = '',
    this.chassisNo = '',
    this.todaName = '',
    this.mtopNo = '',
    this.bodyNumber = '',
    this.color = '',
    this.series = '',
    this.yearModel = '',
    this.applicationType = 'New',
    this.dateApplied,
    this.approvalDate,
    this.expiryDate,
    this.daysRemaining,
    this.isExpiredVirtual = false,
    this.isExpiringSoonVirtual = false,
    this.occupiesFleetSlot,
    this.canFixIssues,
    this.canRefileRenewal,
    this.cancellationOutcome = '',
    this.cancellationDetails,
    this.cancelReason = '',
    this.rejectedField = '',
    this.evidenceUrl = '',
    this.suspensionEndDate,
    this.suspensionReason = '',
    this.currentSanction = '',
    this.activeViolationCount = 0,
    this.paymentStatus = 'Unpaid',
    this.officialReceiptNo = '',
    this.payerName = '',
    this.amountPaid = 0,
    this.paymentMethod = '',
    this.paymentDate,
    this.cashierName = '',
    this.paymentRemarks = '',
    this.paymentHistory = const [],
    this.issuedPermit,
    this.isArchived = false,
    this.archivedAt,
    this.driverName = '',
    this.driverContact = '',
    this.driverLicenseNo = '',
    this.cedulaSerialNo = '',
    this.cedulaDate,
    this.cedulaAddress = '',
    this.orCrNo = '',
    this.orNo = '',
    this.crNo = '',
    this.orCrUrl = '',
    this.crUrl = '',
    this.orUrl = '',
    this.licenseUrl = '',
    this.licenseBackUrl = '',
    this.brgyClearanceUrl = '',
    this.cedulaUrl = '',
    this.updatedAt,
  });

  final String id;
  final String operatorId;
  final String fullName;
  final String address;
  final String zone;
  final String made;
  final String make;
  final String motorNo;
  final String chassisNo;
  final String plateNo;
  final String todaName;
  final String mtopNo;
  final String bodyNumber;
  final String color;
  final String series;
  final String yearModel;
  final String status;
  final String applicationType;
  final DateTime? dateApplied;
  final DateTime? approvalDate;
  final DateTime? expiryDate;
  final int? daysRemaining;
  final bool isExpiredVirtual;
  final bool isExpiringSoonVirtual;
  final bool? occupiesFleetSlot;
  final bool? canFixIssues;
  final bool? canRefileRenewal;
  final String cancellationOutcome;
  final CancellationDetails? cancellationDetails;
  final String cancelReason;
  final String rejectedField;
  final String evidenceUrl;
  final DateTime? suspensionEndDate;
  final String suspensionReason;
  final String currentSanction;
  final int activeViolationCount;
  final String paymentStatus;
  final String officialReceiptNo;
  final String payerName;
  final num amountPaid;
  final String paymentMethod;
  final DateTime? paymentDate;
  final String cashierName;
  final String paymentRemarks;
  final List<PaymentHistoryItem> paymentHistory;
  final IssuedPermitSnapshot? issuedPermit;
  final bool isArchived;
  final DateTime? archivedAt;
  final String driverName;
  final String driverContact;
  final String driverLicenseNo;
  final String cedulaSerialNo;
  final DateTime? cedulaDate;
  final String cedulaAddress;
  final String orCrNo;
  final String orNo;
  final String crNo;
  final String orCrUrl;
  final String crUrl;
  final String orUrl;
  final String licenseUrl;
  final String licenseBackUrl;
  final String brgyClearanceUrl;
  final String cedulaUrl;
  final DateTime? updatedAt;

  /// Clean display zone (`Central`, `North`, `South`).
  String get formattedZone => ManilaDateFormatter.formatZoneLabel(zone);

  /// Clean display MTOP number (prefers `mtopNo`, falls back to issued permit snapshot).
  String get displayMtopNo {
    if (mtopNo.isNotEmpty) return mtopNo;
    if (issuedPermit != null && issuedPermit!.mtopNo.isNotEmpty) {
      return issuedPermit!.mtopNo;
    }
    return '';
  }

  /// Whether this record was finalized through voluntary operator surrender.
  bool get isVoluntarilyCancelled {
    if (cancellationOutcome.isNotEmpty) {
      return cancellationOutcome == 'voluntary_surrender';
    }
    return status == 'Cancelled' &&
        ((cancellationDetails?.hasReason ?? false) ||
            (paymentStatus == 'Paid' && issuedPermit == null));
  }

  /// Whether this record was withdrawn by the operator prior to payment.
  bool get isWithdrawn {
    if (issuedPermit != null) return false;
    if (cancellationOutcome.isNotEmpty) {
      return cancellationOutcome == 'operator_withdrawn';
    }
    return status == 'Cancelled' &&
        !isVoluntarilyCancelled &&
        isArchived &&
        archivedAt != null;
  }

  /// Whether a rejected renewal application can be refiled while keeping the issued permit.
  bool get isRefilableRenewal {
    if (canRefileRenewal != null) return canRefileRenewal!;
    return status == 'Cancelled' &&
        issuedPermit != null &&
        paymentStatus != 'Paid' &&
        issuedPermit!.status != 'Suspended' &&
        issuedPermit!.status != 'Revoked';
  }

  /// Whether a rejected new application can be corrected and resubmitted.
  bool get isRejectedNeedsFix {
    if (canFixIssues != null) return canFixIssues!;
    return status == 'Cancelled' &&
        !isVoluntarilyCancelled &&
        !isWithdrawn &&
        issuedPermit == null;
  }

  /// Whether the operator can withdraw this unpaid application (`PUT /franchises/:id/cancel`).
  bool get isWithdrawable {
    const withdrawable = {'Pending', 'Pending for Approval', 'For Payment'};
    return withdrawable.contains(status) &&
        paymentStatus != 'Paid' &&
        !isArchived;
  }

  /// Whether the operator can request voluntary franchise cancellation (`PUT /franchises/:id/request-cancellation`).
  bool get canRequestVoluntaryCancellation {
    return (status == 'Active' || status == 'Active - Under Warning') &&
        !isArchived;
  }

  /// Whether this franchise currently occupies one of the operator's ordinance fleet slots.
  bool get countsTowardQuota {
    if (occupiesFleetSlot != null) return occupiesFleetSlot!;
    const nonOccupying = {'Cancelled', 'Rejected', 'Revoked', 'Expired', 'Archived'};
    if (!nonOccupying.contains(status) && !isArchived) return true;
    if (issuedPermit != null &&
        !isArchived &&
        {'Active', 'Active - Under Warning', 'Suspended'}
            .contains(issuedPermit!.status)) {
      return true;
    }
    return false;
  }

  /// Whether an approved MTOP E-Copy is available to display offline.
  bool get hasApprovedECopy {
    return status == 'Active' ||
        status == 'Active - Under Warning' ||
        status == 'Ready for Pickup' ||
        issuedPermit != null;
  }

  /// Whether an Official Receipt (`OR#`) or payment history exists for E-Receipt display.
  bool get hasOfficialReceipt {
    return officialReceiptNo.isNotEmpty ||
        paymentStatus == 'Paid' ||
        (issuedPermit?.officialReceiptNo.isNotEmpty ?? false) ||
        paymentHistory.isNotEmpty;
  }

  /// Server-authoritative `daysRemaining` in `Asia/Manila` (falls back to Manila calendar delta).
  int? effectiveDaysRemaining({DateTime? nowManilaOverride}) {
    if (daysRemaining != null) return daysRemaining;
    final exp = expiryDate ?? issuedPermit?.expiryDate;
    if (exp == null) return null;
    return ManilaDateFormatter.calculateManilaDaysRemaining(
      exp,
      nowManilaOverride: nowManilaOverride,
    );
  }

  /// True when the franchise is active and inside the renewal reminder window (`<= reminderDays`).
  bool isWithinRenewalWindow(
    int reminderDays, {
    DateTime? nowManilaOverride,
  }) {
    if (status != 'Active' && status != 'Active - Under Warning') return false;
    final days = effectiveDaysRemaining(nowManilaOverride: nowManilaOverride);
    if (days == null) return isExpiringSoonVirtual;
    return days > 0 && days <= reminderDays;
  }

  /// True when the franchise is expired or past its validity date.
  bool isEffectivelyExpired({DateTime? nowManilaOverride}) {
    if (status == 'Expired' || isExpiredVirtual) return true;
    if (status == 'Active' || status == 'Active - Under Warning') {
      final days = effectiveDaysRemaining(nowManilaOverride: nowManilaOverride);
      return days != null && days <= 0;
    }
    return false;
  }

  /// True when the unit is eligible for a Renew shortcut (expired or within renewal window).
  bool canShowRenewShortcut(int reminderDays) {
    if (status == 'Expired') return true;
    if (isRefilableRenewal) return true;
    if (status == 'Active' || status == 'Active - Under Warning') {
      final days = effectiveDaysRemaining();
      return days != null && days <= reminderDays;
    }
    return false;
  }

  /// Maps status to the 5-Stage LGU Pipeline (`null` for terminal/non-pipeline states).
  LguPipelineStage? get pipelineStage {
    switch (status) {
      case 'Pending':
      case 'Pending for Approval':
      case 'Under Review':
      case 'For Inspection':
        return LguPipelineStage.pending;
      case 'For Payment':
        return LguPipelineStage.forPayment;
      case 'For Signing':
        return LguPipelineStage.forSigning;
      case 'Ready for Pickup':
        return LguPipelineStage.readyForPickup;
      case 'Active':
      case 'Active - Under Warning':
        return LguPipelineStage.active;
      default:
        return null;
    }
  }

  /// Maps this unit into one of the 3 primary Garage filter tabs.
  GarageFilter get filterCategory {
    if (isArchived ||
        status == 'Archived' ||
        status == 'Revoked' ||
        status == 'Expired' ||
        isVoluntarilyCancelled ||
        isWithdrawn) {
      return GarageFilter.pastArchived;
    }
    if (status == 'Active' ||
        status == 'Active - Under Warning' ||
        status == 'Suspended') {
      return GarageFilter.active;
    }
    // Pending, For Payment, For Signing, Ready for Pickup, Cancellation Requested,
    // plus rejected applications needing Fix & Reapply / Refile Renewal.
    return GarageFilter.inProgress;
  }

  /// Semantic WCAG AA color band for status badges and banners.
  CivicStatusTone get statusTone {
    switch (status) {
      case 'Active':
        return CivicStatusTone.active;
      case 'Active - Under Warning':
      case 'Pending':
      case 'Pending for Approval':
      case 'Under Review':
      case 'For Inspection':
      case 'For Payment':
      case 'For Signing':
      case 'Ready for Pickup':
      case 'Cancellation Requested':
      case 'Pending Cancellation':
        return CivicStatusTone.inProgress;
      case 'Expired':
      case 'Suspended':
      case 'Revoked':
        return CivicStatusTone.danger;
      case 'Cancelled':
        return (isRejectedNeedsFix || isRefilableRenewal)
            ? CivicStatusTone.danger
            : CivicStatusTone.neutral;
      default:
        return CivicStatusTone.neutral;
    }
  }

  /// Builds the official formal surrender letter template addressed to Hon. Lidany A. Lao-Baldo / OVM.
  String buildVoluntaryCancellationLetter({
    required String reason,
    String customReason = '',
    String remarks = '',
  }) {
    final operatorName =
        fullName.trim().isEmpty ? 'Registered Operator' : fullName.trim();
    final toda = todaName.trim().isEmpty ? 'N/A' : todaName.trim();
    final plate = plateNo.trim().isEmpty ? 'N/A' : plateNo.trim();
    final mtop = displayMtopNo.isEmpty ? 'N/A' : displayMtopNo;
    final effectiveReason =
        reason == 'Other' && customReason.trim().isNotEmpty
            ? customReason.trim()
            : reason;
    final detailsLine = remarks.trim().isNotEmpty
        ? '\nAdditional Details: ${remarks.trim()}'
        : '';

    return [
      'Hon. Lidany A. Lao-Baldo',
      'Municipal Vice Mayor / Office of the Vice Mayor (OVM)',
      'Municipality of Gasan, Province of Marinduque',
      '',
      'Dear Hon. Vice Mayor,',
      '',
      "I am respectfully requesting the voluntary cancellation of my Motorized Tricycle Operator's Permit (MTOP) / Tricycle Franchise with the following details:",
      '',
      '• Registered Operator: $operatorName',
      '• TODA Association: $toda',
      '• Franchise / MTOP No.: $mtop',
      '• Plate / MV File No.: $plate',
      '• Reason for Cancellation: $effectiveReason$detailsLine',
      '',
      'I affirm that this surrender and cancellation request is voluntary and will coordinate with the Office of the Vice Mayor (OVM) Franchising Unit (LLSA I) for official approval.',
      '',
      'Respectfully yours,',
      operatorName,
    ].join('\n');
  }

  factory FranchiseRecord.fromJson(Map<String, dynamic> json) {
    final rawOperator = json['operator'];
    final operatorId = rawOperator is Map
        ? (rawOperator['_id'] ?? rawOperator['id'] ?? '').toString()
        : (rawOperator ?? '').toString();

    final rawPayments = json['paymentHistory'];
    final payments = rawPayments is List
        ? rawPayments
            .whereType<Map>()
            .map((e) => PaymentHistoryItem.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <PaymentHistoryItem>[];

    final rawCancel = json['cancellationDetails'];
    final cancelDetails = rawCancel is Map
        ? CancellationDetails.fromJson(Map<String, dynamic>.from(rawCancel))
        : null;

    final rawIssued = json['issuedPermit'];
    final issued = rawIssued is Map
        ? IssuedPermitSnapshot.fromJson(Map<String, dynamic>.from(rawIssued))
        : null;

    return FranchiseRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      operatorId: operatorId,
      fullName: (json['fullName'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      zone: (json['zone'] ?? '').toString().trim(),
      made: (json['made'] ?? '').toString().trim(),
      make: (json['make'] ?? '').toString().trim(),
      motorNo: (json['motorNo'] ?? '').toString().trim(),
      chassisNo: (json['chassisNo'] ?? '').toString().trim(),
      plateNo: (json['plateNo'] ?? '').toString().trim(),
      todaName: (json['todaName'] ?? '').toString().trim(),
      mtopNo: (json['mtopNo'] ?? '').toString().trim(),
      bodyNumber: (json['bodyNumber'] ?? '').toString().trim(),
      color: (json['color'] ?? '').toString().trim(),
      series: (json['series'] ?? '').toString().trim(),
      yearModel: (json['yearModel'] ?? '').toString().trim(),
      status: (json['status'] ?? 'Pending').toString().trim(),
      applicationType: (json['applicationType'] ?? 'New').toString().trim(),
      dateApplied: ManilaDateFormatter.tryParseIso(json['dateApplied']),
      approvalDate: ManilaDateFormatter.tryParseIso(json['approvalDate']),
      expiryDate: ManilaDateFormatter.tryParseIso(json['expiryDate']),
      daysRemaining: _parseNullableInt(json['daysRemaining']),
      isExpiredVirtual: json['isExpired'] == true,
      isExpiringSoonVirtual: json['isExpiringSoon'] == true,
      occupiesFleetSlot: json['occupiesFleetSlot'] is bool
          ? json['occupiesFleetSlot'] as bool
          : null,
      canFixIssues:
          json['canFixIssues'] is bool ? json['canFixIssues'] as bool : null,
      canRefileRenewal: json['canRefileRenewal'] is bool
          ? json['canRefileRenewal'] as bool
          : null,
      cancellationOutcome:
          (json['cancellationOutcome'] ?? '').toString().trim(),
      cancellationDetails: cancelDetails,
      cancelReason: (json['cancelReason'] ?? '').toString().trim(),
      rejectedField: (json['rejectedField'] ?? '').toString().trim(),
      evidenceUrl: (json['evidenceUrl'] ?? '').toString().trim(),
      suspensionEndDate:
          ManilaDateFormatter.tryParseIso(json['suspensionEndDate']),
      suspensionReason: (json['suspensionReason'] ?? '').toString().trim(),
      currentSanction: (json['currentSanction'] ?? '').toString().trim(),
      activeViolationCount: _parseInt(json['activeViolationCount']),
      paymentStatus: (json['paymentStatus'] ?? 'Unpaid').toString().trim(),
      officialReceiptNo: (json['officialReceiptNo'] ?? '').toString().trim(),
      payerName: (json['payerName'] ?? '').toString().trim(),
      amountPaid: _parseNum(json['amountPaid']),
      paymentMethod: (json['paymentMethod'] ?? '').toString().trim(),
      paymentDate: ManilaDateFormatter.tryParseIso(json['paymentDate']),
      cashierName: (json['cashierName'] ?? '').toString().trim(),
      paymentRemarks: (json['paymentRemarks'] ?? '').toString().trim(),
      paymentHistory: payments,
      issuedPermit: issued,
      isArchived: json['isArchived'] == true,
      archivedAt: ManilaDateFormatter.tryParseIso(json['archivedAt']),
      driverName: (json['driverName'] ?? '').toString().trim(),
      driverContact: (json['driverContact'] ?? '').toString().trim(),
      driverLicenseNo: (json['driverLicenseNo'] ?? '').toString().trim(),
      cedulaSerialNo: (json['cedulaSerialNo'] ?? '').toString().trim(),
      cedulaDate: ManilaDateFormatter.tryParseIso(json['cedulaDate']),
      cedulaAddress: (json['cedulaAddress'] ?? '').toString().trim(),
      orCrNo: (json['orCrNo'] ?? '').toString().trim(),
      orNo: (json['orNo'] ?? '').toString().trim(),
      crNo: (json['crNo'] ?? '').toString().trim(),
      orCrUrl: (json['orCrUrl'] ?? '').toString().trim(),
      crUrl: (json['crUrl'] ?? '').toString().trim(),
      orUrl: (json['orUrl'] ?? '').toString().trim(),
      licenseUrl: (json['licenseUrl'] ?? '').toString().trim(),
      licenseBackUrl: (json['licenseBackUrl'] ?? '').toString().trim(),
      brgyClearanceUrl: (json['brgyClearanceUrl'] ?? '').toString().trim(),
      cedulaUrl: (json['cedulaUrl'] ?? '').toString().trim(),
      updatedAt: ManilaDateFormatter.tryParseIso(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'operator': operatorId,
        'fullName': fullName,
        'address': address,
        'zone': zone,
        'made': made,
        'make': make,
        'motorNo': motorNo,
        'chassisNo': chassisNo,
        'plateNo': plateNo,
        'todaName': todaName,
        'mtopNo': mtopNo,
        'bodyNumber': bodyNumber,
        'color': color,
        'series': series,
        'yearModel': yearModel,
        'status': status,
        'applicationType': applicationType,
        'dateApplied': dateApplied?.toIso8601String(),
        'approvalDate': approvalDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'daysRemaining': daysRemaining,
        'isExpired': isExpiredVirtual,
        'isExpiringSoon': isExpiringSoonVirtual,
        'occupiesFleetSlot': occupiesFleetSlot,
        'canFixIssues': canFixIssues,
        'canRefileRenewal': canRefileRenewal,
        'cancellationOutcome': cancellationOutcome,
        'cancellationDetails': cancellationDetails?.toJson(),
        'cancelReason': cancelReason,
        'rejectedField': rejectedField,
        'evidenceUrl': evidenceUrl,
        'suspensionEndDate': suspensionEndDate?.toIso8601String(),
        'suspensionReason': suspensionReason,
        'currentSanction': currentSanction,
        'activeViolationCount': activeViolationCount,
        'paymentStatus': paymentStatus,
        'officialReceiptNo': officialReceiptNo,
        'payerName': payerName,
        'amountPaid': amountPaid,
        'paymentMethod': paymentMethod,
        'paymentDate': paymentDate?.toIso8601String(),
        'cashierName': cashierName,
        'paymentRemarks': paymentRemarks,
        'paymentHistory': paymentHistory.map((p) => p.toJson()).toList(),
        'issuedPermit': issuedPermit?.toJson(),
        'isArchived': isArchived,
        'archivedAt': archivedAt?.toIso8601String(),
        'driverName': driverName,
        'driverContact': driverContact,
        'driverLicenseNo': driverLicenseNo,
        'cedulaSerialNo': cedulaSerialNo,
        'cedulaDate': cedulaDate?.toIso8601String(),
        'cedulaAddress': cedulaAddress,
        'orCrNo': orCrNo,
        'orNo': orNo,
        'crNo': crNo,
        'orCrUrl': orCrUrl,
        'crUrl': crUrl,
        'orUrl': orUrl,
        'licenseUrl': licenseUrl,
        'licenseBackUrl': licenseBackUrl,
        'brgyClearanceUrl': brgyClearanceUrl,
        'cedulaUrl': cedulaUrl,
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

num _parseNum(dynamic raw) {
  if (raw is num) return raw;
  return num.tryParse(raw?.toString() ?? '') ?? 0;
}

int _parseInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

int? _parseNullableInt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw.toString());
}
