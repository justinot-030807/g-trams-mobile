import 'dart:typed_data';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';

/// Wizard operating modes supported by Phase 3.
enum WizardFlowMode { newApplication, fixReapply, renewal }

/// Canonical Tricycle / Motorcycle DL Codes accepted by the G-TRAMS backend.
const List<String> kAllowedDlCodes = ['A, A1', 'A1', 'A'];

/// Common tricycle motorcycle makes in Gasan, Marinduque.
const List<String> kPopularTricycleMakes = [
  'Honda TMX 125 Alpha',
  'Honda TMX Supremo 150',
  'Kawasaki Barako II 175',
  'Kawasaki CT100 / CT125',
  'Yamaha YTX 125',
  'Suzuki GD110',
  'Rusi TC 125 / 150',
  'Bajaj RE',
];

const List<String> kDrivingConditions = [
  'None',
  'A - Wear Corrective Lenses',
  'B - Drive Only with Special Equipment',
  '1 - Wear Eyeglasses',
];

/// Platform-agnostic captured/uploaded document file ready for OCR & multipart upload.
class ScannedDocumentAttachment {
  const ScannedDocumentAttachment({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.sourceLabel = 'File',
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final String sourceLabel;

  int get sizeBytes => bytes.length;
  bool get isImage => mimeType.toLowerCase().startsWith('image/');
  bool get isPdf =>
      mimeType.toLowerCase().contains('pdf') ||
      fileName.toLowerCase().endsWith('.pdf');
}

/// Result returned by `POST /api/v1/franchises/scan-document` (3-Tier AI OCR).
class OcrScanResult {
  const OcrScanResult({
    required this.success,
    required this.docType,
    this.needsManual = false,
    this.message = '',
    this.data = const {},
  });

  final bool success;
  final String docType;
  final bool needsManual;
  final String message;
  final Map<String, dynamic> data;

  /// RA 10173 Data Privacy sanitizer: strictly strips driver blood type,
  /// payment amounts, body measurements, and OCR signatory keys before storage/UI.
  static const Set<String> _privacyExcludedKeys = {
    'bloodtype',
    'blood_type',
    'totalamountpaid',
    'basiccommunitytax',
    'additionaltax',
    'interest',
    'amountpaid',
    'cedulaamount',
    'treasurer',
    'signatory',
    'todasignaory',
    'todasig',
    'issuer',
    'brgyissuer',
    'height',
    'weight',
  };

  static Map<String, dynamic> sanitizeOcrData(Map<String, dynamic> raw) {
    final cleaned = <String, dynamic>{};
    for (final entry in raw.entries) {
      final normKey = entry.key.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      if (_privacyExcludedKeys.contains(normKey)) continue;
      if (entry.value != null) {
        cleaned[entry.key] = entry.value;
      }
    }
    return cleaned;
  }

  factory OcrScanResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackDocType,
  }) {
    final rawData = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    return OcrScanResult(
      success: json['success'] == true,
      docType: (json['docType'] ?? fallbackDocType).toString(),
      needsManual: json['needsManual'] == true,
      message: (json['message'] ?? '').toString().trim(),
      data: sanitizeOcrData(rawData),
    );
  }
}

/// Real-time duplicate check result from `GET /api/v1/franchises/check-unique`.
class UniqueFieldCheckResult {
  const UniqueFieldCheckResult({
    required this.field,
    required this.value,
    required this.isUnique,
    this.existingStatus,
    this.message = '',
  });

  final String field;
  final String value;
  final bool isUnique;
  final String? existingStatus;
  final String message;

  factory UniqueFieldCheckResult.fromJson(Map<String, dynamic> json) {
    return UniqueFieldCheckResult(
      field: (json['field'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      isUnique: json['isUnique'] != false && json['unique'] != false,
      existingStatus: json['existingStatus']?.toString(),
      message: (json['message'] ?? '').toString().trim(),
    );
  }
}

/// Real-time jurisdiction check result from `GET /api/v1/franchises/check-toda-member`.
class TodaJurisdictionCheckResult {
  const TodaJurisdictionCheckResult({
    required this.todaName,
    required this.jurisdictionStatus,
    this.jurisdictionWarning = '',
    this.authorizedTodas = const [],
  });

  final String todaName;

  /// `'match'`, `'mismatch'`, `'non_toda'`, or `'unspecified'`.
  final String jurisdictionStatus;
  final String jurisdictionWarning;
  final List<String> authorizedTodas;

  bool get isMismatch => jurisdictionStatus == 'mismatch';

  factory TodaJurisdictionCheckResult.fromJson(Map<String, dynamic> json) {
    final rawTodas = json['authorizedTodas'];
    final authorized = rawTodas is List
        ? rawTodas.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    return TodaJurisdictionCheckResult(
      todaName: (json['todaName'] ?? '').toString(),
      jurisdictionStatus: (json['jurisdictionStatus'] ?? 'unspecified').toString(),
      jurisdictionWarning: (json['jurisdictionWarning'] ?? '').toString().trim(),
      authorizedTodas: authorized,
    );
  }
}

/// Result of applying AI OCR fields onto a [FranchiseWizardDraft].
class OcrAutoFillOutcome {
  const OcrAutoFillOutcome({
    required this.draft,
    required this.appliedFields,
  });

  final FranchiseWizardDraft draft;
  final List<String> appliedFields;
}

/// Serializable state for the 5-Step Apply / Fix & Reapply / Renewal Wizard
/// persisted offline in Hive for automatic draft recovery.
class FranchiseWizardDraft {
  const FranchiseWizardDraft({
    this.mode = WizardFlowMode.newApplication,
    this.targetFranchiseId = '',
    this.currentStep = 0,
    // Step 1: Operator & TODA
    this.fullName = '',
    this.barangay = '',
    this.zone = '',
    this.todaName = 'NON-TODA',
    this.bodyNumber = '',
    // Step 2: Vehicle Specs & OR/CR
    this.plateNo = '',
    this.make = '',
    this.made = '',
    this.motorNo = '',
    this.chassisNo = '',
    this.color = '',
    this.series = '',
    this.crNo = '',
    this.orNo = '',
    this.orCrNo = '',
    this.orCrExpiryDate = '',
    this.fileNo = '',
    this.existingOrCrUrl = '',
    this.existingCrUrl = '',
    this.existingOrUrl = '',
    // Step 3: Driver's License & Barangay Clearance (NO TODA Endorsement!)
    this.isOperatorDriver = true,
    this.driverName = '',
    this.driverContact = '',
    this.driverLicenseNo = '',
    this.driverLicenseSerialNo = '',
    this.driverLicenseExpiryDate = '',
    this.driverDlCodes = 'A, A1',
    this.driverConditions = 'None',
    this.driverAddress = '',
    this.brgyClearanceNo = '',
    this.brgyClearanceDate = '',
    this.existingLicenseUrl = '',
    this.existingLicenseBackUrl = '',
    this.existingBrgyClearanceUrl = '',
    // Step 4: Review & Cedula (CTC) — strictly RA 10173 compliant (no amounts/signatories)
    this.cedulaSerialNo = '',
    this.cedulaDate = '',
    this.cedulaAddress = 'Gasan, Marinduque',
    this.cedulaYear = '',
    this.cedulaFullName = '',
    this.cedulaCitizenship = 'Filipino',
    this.cedulaCivilStatus = '',
    this.cedulaProfession = '',
    this.cedulaTin = '',
    this.existingCedulaUrl = '',
    // Metadata
    this.rejectedField = '',
    this.cancelReason = '',
    this.aiScannedDocs = const {},
    this.savedAt,
  });

  final WizardFlowMode mode;
  final String targetFranchiseId;
  final int currentStep;

  // Step 1
  final String fullName;
  final String barangay;
  final String zone;
  final String todaName;
  final String bodyNumber;

  // Step 2
  final String plateNo;
  final String make;
  final String made;
  final String motorNo;
  final String chassisNo;
  final String color;
  final String series;
  final String crNo;
  final String orNo;
  final String orCrNo;
  final String orCrExpiryDate;
  final String fileNo;
  final String existingOrCrUrl;
  final String existingCrUrl;
  final String existingOrUrl;

  // Step 3
  final bool isOperatorDriver;
  final String driverName;
  final String driverContact;
  final String driverLicenseNo;
  final String driverLicenseSerialNo;
  final String driverLicenseExpiryDate;
  final String driverDlCodes;
  final String driverConditions;
  final String driverAddress;
  final String brgyClearanceNo;
  final String brgyClearanceDate;
  final String existingLicenseUrl;
  final String existingLicenseBackUrl;
  final String existingBrgyClearanceUrl;

  // Step 4
  final String cedulaSerialNo;
  final String cedulaDate;
  final String cedulaAddress;
  final String cedulaYear;
  final String cedulaFullName;
  final String cedulaCitizenship;
  final String cedulaCivilStatus;
  final String cedulaProfession;
  final String cedulaTin;
  final String existingCedulaUrl;

  // Metadata
  final String rejectedField;
  final String cancelReason;
  final Map<String, dynamic> aiScannedDocs;
  final DateTime? savedAt;

  String get fullAddress {
    final clean = barangay.trim();
    if (clean.isEmpty) return '';
    if (clean.toLowerCase().contains('gasan')) return clean;
    return '$clean, Gasan, Marinduque';
  }

  /// Creates default Step 1–4 seed values from the authenticated user's profile.
  factory FranchiseWizardDraft.fromUser(MobileUser user) {
    final normalizedBrgy = _matchOfficialBarangay(user.address);
    final resolvedZone = GasanConstants.getZoneForBarangay(normalizedBrgy);
    final toda = user.todaAssociation.trim().isNotEmpty
        ? user.todaAssociation.trim()
        : 'NON-TODA';
    final todaZone = GasanConstants.findTodaById(toda)?.zone ?? '';
    final effectiveZone = resolvedZone.isNotEmpty
        ? resolvedZone
        : (todaZone == 'Central' || todaZone == 'North' || todaZone == 'South'
            ? todaZone
            : 'Central');

    final todayStr = _todayManilaIso();
    return FranchiseWizardDraft(
      mode: WizardFlowMode.newApplication,
      fullName: user.name.trim(),
      barangay: normalizedBrgy,
      zone: effectiveZone,
      todaName: toda,
      bodyNumber: user.bodyNumber.trim(),
      driverName: user.name.trim(),
      driverContact: user.contact.trim(),
      driverAddress: normalizedBrgy.isNotEmpty
          ? '$normalizedBrgy, Gasan, Marinduque'
          : user.address.trim(),
      cedulaFullName: user.name.trim(),
      cedulaAddress: normalizedBrgy.isNotEmpty
          ? '$normalizedBrgy, Gasan, Marinduque'
          : 'Gasan, Marinduque',
      cedulaDate: todayStr,
      cedulaYear: todayStr.substring(0, 4),
    );
  }

  /// Creates a pre-populated draft for Fix & Reapply or Renewal from a [FranchiseRecord].
  factory FranchiseWizardDraft.fromExistingFranchise({
    required FranchiseRecord unit,
    required MobileUser user,
    required WizardFlowMode mode,
  }) {
    final brgy = _matchOfficialBarangay(
      unit.address.isNotEmpty ? unit.address : user.address,
    );
    final zone = unit.formattedZone != 'N/A'
        ? unit.formattedZone
        : GasanConstants.getZoneForBarangay(brgy);
    final todayStr = _todayManilaIso();
    final initialStep = mode == WizardFlowMode.fixReapply
        ? _targetStepForRejectedField(unit.rejectedField, unit.cancelReason)
        : 0;

    return FranchiseWizardDraft(
      mode: mode,
      targetFranchiseId: unit.id,
      currentStep: initialStep,
      fullName: unit.fullName.isNotEmpty ? unit.fullName : user.name,
      barangay: brgy,
      zone: zone.isNotEmpty ? zone : 'Central',
      todaName: unit.todaName.isNotEmpty ? unit.todaName : user.todaAssociation,
      bodyNumber: unit.bodyNumber.isNotEmpty ? unit.bodyNumber : user.bodyNumber,
      plateNo: unit.plateNo,
      make: unit.make,
      made: unit.made,
      motorNo: unit.motorNo,
      chassisNo: unit.chassisNo,
      color: unit.color,
      series: unit.series,
      crNo: unit.crNo,
      orNo: unit.orNo,
      orCrNo: unit.orCrNo,
      existingOrCrUrl: unit.orCrUrl,
      existingCrUrl: unit.crUrl,
      existingOrUrl: unit.orUrl,
      driverName: unit.driverName.isNotEmpty ? unit.driverName : unit.fullName,
      driverContact:
          unit.driverContact.isNotEmpty ? unit.driverContact : user.contact,
      driverLicenseNo: unit.driverLicenseNo,
      existingLicenseUrl: unit.licenseUrl,
      existingLicenseBackUrl: unit.licenseBackUrl,
      existingBrgyClearanceUrl: unit.brgyClearanceUrl,
      cedulaSerialNo: mode == WizardFlowMode.renewal ? '' : unit.cedulaSerialNo,
      cedulaDate: mode == WizardFlowMode.renewal
          ? todayStr
          : (unit.cedulaDate != null
              ? _toIsoDate(unit.cedulaDate!)
              : todayStr),
      cedulaAddress: unit.cedulaAddress.isNotEmpty
          ? unit.cedulaAddress
          : 'Gasan, Marinduque',
      cedulaYear: todayStr.substring(0, 4),
      cedulaFullName: unit.fullName.isNotEmpty ? unit.fullName : user.name,
      existingCedulaUrl: unit.cedulaUrl,
      rejectedField: unit.rejectedField,
      cancelReason: unit.cancelReason,
    );
  }

  /// Normalizes raw OCR DL codes (`A, A1, B`, `1`, etc.) to backend-valid tricycle codes.
  static String normalizeTricycleDlCodes(String? raw) {
    final tokens = (raw ?? '')
        .toUpperCase()
        .split(RegExp(r'[\s,;/]+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (tokens.contains('A') &&
        (tokens.contains('A1') || tokens.contains('1'))) {
      return 'A, A1';
    }
    if (tokens.contains('A1')) return 'A1';
    if (tokens.contains('A')) return 'A';
    return '';
  }

  /// Normalizes varied OCR date formats (`03/31/2027`, `2027-03-31`, etc.) to `YYYY-MM-DD`.
  static String normalizeOcrDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final trimmed = raw.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) return trimmed;
    if (trimmed.contains('T') &&
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
      return trimmed.substring(0, 10);
    }
    final parts = trimmed.split(RegExp(r'[/.-]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        return '${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}';
      }
      if (parts[2].length == 4) {
        final p1 = int.tryParse(parts[0]) ?? 0;
        final p2 = int.tryParse(parts[1]) ?? 0;
        final year = parts[2];
        if (p1 > 12 && p2 >= 1 && p2 <= 12) {
          return '$year-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
        }
        if (p1 >= 1 && p1 <= 12) {
          return '$year-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
        }
      }
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return _toIsoDate(parsed);
    return '';
  }

  /// Applies RA 10173-sanitized OCR extraction results onto this draft.
  OcrAutoFillOutcome applyOcrExtraction(
    String docType,
    Map<String, dynamic> rawData,
  ) {
    final data = OcrScanResult.sanitizeOcrData(rawData);
    final applied = <String>[];
    String pickStr(List<String> keys) {
      for (final k in keys) {
        final v = data[k]?.toString().trim() ?? '';
        if (v.isNotEmpty &&
            v.toUpperCase() != 'N/A' &&
            v.toUpperCase() != 'UNCLEAR' &&
            v.toUpperCase() != 'NOT FOUND') {
          return v;
        }
      }
      return '';
    }

    var next = this;
    final normDoc = docType.toLowerCase();

    if (normDoc == 'orcr' || normDoc == 'cr' || normDoc == 'or') {
      final plate = pickStr(['plateNo', 'plateNumber']).toUpperCase();
      final motor = pickStr(['motorNo', 'engineNo', 'motorNumber']).toUpperCase();
      final chassis = pickStr(['chassisNo', 'chassisNumber']).toUpperCase();
      final rawMake = pickStr(['make']);
      final rawSeries = pickStr(['series']);
      final combinedMake = rawMake.isNotEmpty &&
              rawSeries.isNotEmpty &&
              !rawMake.toLowerCase().contains(rawSeries.toLowerCase())
          ? '$rawMake $rawSeries'
          : (rawMake.isNotEmpty ? rawMake : rawSeries);
      final year = pickStr(['yearModel', 'year', 'made']);
      final col = pickStr(['color']).toUpperCase();
      final cr = pickStr(['crNo']).toUpperCase();
      final orNum = pickStr(['orNo']).toUpperCase();
      final file = pickStr(['fileNo']).toUpperCase();
      final exp = normalizeOcrDate(pickStr(['expiryDate', 'orCrExpiryDate']));

      if (plate.isNotEmpty) applied.add('Plate No.');
      if (motor.isNotEmpty) applied.add('Motor No.');
      if (chassis.isNotEmpty) applied.add('Chassis No.');
      if (combinedMake.isNotEmpty) applied.add('Vehicle Make');
      if (year.isNotEmpty) applied.add('Year Model');
      if (cr.isNotEmpty) applied.add('CR No.');
      if (orNum.isNotEmpty) applied.add('OR No.');
      if (exp.isNotEmpty) applied.add('OR/CR Expiry');

      next = next.copyWith(
        plateNo: plate.isNotEmpty ? plate : next.plateNo,
        motorNo: motor.isNotEmpty ? motor : next.motorNo,
        chassisNo: chassis.isNotEmpty ? chassis : next.chassisNo,
        make: combinedMake.isNotEmpty ? combinedMake : next.make,
        series: rawSeries.isNotEmpty ? rawSeries : next.series,
        made: year.isNotEmpty ? year : next.made,
        color: col.isNotEmpty ? col : next.color,
        crNo: cr.isNotEmpty ? cr : next.crNo,
        orNo: orNum.isNotEmpty ? orNum : next.orNo,
        orCrNo: orNum.isNotEmpty
            ? orNum
            : (cr.isNotEmpty ? cr : next.orCrNo),
        fileNo: file.isNotEmpty ? file : next.fileNo,
        orCrExpiryDate: exp.isNotEmpty ? exp : next.orCrExpiryDate,
      );
    } else if (normDoc == 'license') {
      final licNo = pickStr(['licenseNo', 'driverLicenseNo']).toUpperCase();
      final dName = pickStr(['driverName', 'fullName']);
      final dl = normalizeTricycleDlCodes(pickStr(['dlCodes', 'driverDlCodes']));
      final exp = normalizeOcrDate(pickStr(['expiryDate', 'driverLicenseExpiryDate']));
      final addr = pickStr(['address', 'driverAddress']);

      if (licNo.isNotEmpty) applied.add("Driver's License No.");
      if (dName.isNotEmpty) applied.add('Driver Name');
      if (dl.isNotEmpty) applied.add('DL Codes');
      if (exp.isNotEmpty) applied.add('License Expiry');

      next = next.copyWith(
        driverLicenseNo: licNo.isNotEmpty ? licNo : next.driverLicenseNo,
        driverName: dName.isNotEmpty ? dName : next.driverName,
        driverDlCodes: dl.isNotEmpty ? dl : next.driverDlCodes,
        driverLicenseExpiryDate:
            exp.isNotEmpty ? exp : next.driverLicenseExpiryDate,
        driverAddress: addr.isNotEmpty ? addr : next.driverAddress,
      );
    } else if (normDoc == 'licenseback') {
      final serial = pickStr(['serialNo', 'driverLicenseSerialNo']).toUpperCase();
      final dl = normalizeTricycleDlCodes(pickStr(['dlCodes', 'driverDlCodes']));

      if (serial.isNotEmpty) applied.add('License Back Serial');
      if (dl.isNotEmpty) applied.add('DL Codes');

      next = next.copyWith(
        driverLicenseSerialNo:
            serial.isNotEmpty ? serial : next.driverLicenseSerialNo,
        driverDlCodes: dl.isNotEmpty ? dl : next.driverDlCodes,
      );
    } else if (normDoc == 'brgyclearance') {
      final clrNo = pickStr(['clearanceNo', 'brgyClearanceNo']).toUpperCase();
      final dateStr = normalizeOcrDate(pickStr(['dateIssued', 'brgyClearanceDate']));
      final rawBrgy = pickStr(['barangay']);
      final matchedBrgy = _matchOfficialBarangay(rawBrgy);
      final resolvedZone = matchedBrgy.isNotEmpty
          ? GasanConstants.getZoneForBarangay(matchedBrgy)
          : '';

      if (clrNo.isNotEmpty) applied.add('Clearance No.');
      if (dateStr.isNotEmpty) applied.add('Clearance Date');
      if (matchedBrgy.isNotEmpty) applied.add('Barangay');

      next = next.copyWith(
        brgyClearanceNo: clrNo.isNotEmpty ? clrNo : next.brgyClearanceNo,
        brgyClearanceDate: dateStr.isNotEmpty ? dateStr : next.brgyClearanceDate,
        barangay:
            (next.barangay.isEmpty && matchedBrgy.isNotEmpty)
                ? matchedBrgy
                : next.barangay,
        zone: (next.zone.isEmpty && resolvedZone.isNotEmpty)
            ? resolvedZone
            : next.zone,
      );
    } else if (normDoc == 'cedula') {
      final serial = pickStr(['serialNo', 'ctcNo', 'cedulaSerialNo']).toUpperCase();
      final dateStr = normalizeOcrDate(pickStr(['dateIssued', 'cedulaDate']));
      final place = pickStr(['placeIssued', 'placeOfIssue', 'address', 'cedulaAddress']);
      final yr = pickStr(['year', 'cedulaYear']);
      final fName = pickStr(['fullName', 'taxpayerName', 'cedulaFullName']);
      final cit = pickStr(['citizenship']);
      final civil = pickStr(['civilStatus']);
      final prof = pickStr(['profession']);
      final tinVal = pickStr(['tin']);

      if (serial.isNotEmpty) applied.add('Cedula Serial No.');
      if (dateStr.isNotEmpty) applied.add('Cedula Date');
      if (place.isNotEmpty) applied.add('Place Issued');

      next = next.copyWith(
        cedulaSerialNo: serial.isNotEmpty ? serial : next.cedulaSerialNo,
        cedulaDate: dateStr.isNotEmpty ? dateStr : next.cedulaDate,
        cedulaAddress: place.isNotEmpty ? place : next.cedulaAddress,
        cedulaYear: yr.isNotEmpty
            ? yr
            : (dateStr.length >= 4 ? dateStr.substring(0, 4) : next.cedulaYear),
        cedulaFullName: fName.isNotEmpty ? fName : next.cedulaFullName,
        cedulaCitizenship: cit.isNotEmpty ? cit : next.cedulaCitizenship,
        cedulaCivilStatus: civil.isNotEmpty ? civil : next.cedulaCivilStatus,
        cedulaProfession: prof.isNotEmpty ? prof : next.cedulaProfession,
        cedulaTin: tinVal.isNotEmpty ? tinVal : next.cedulaTin,
      );
    }

    final mergedScanned = Map<String, dynamic>.from(next.aiScannedDocs);
    mergedScanned[docType] = data;

    return OcrAutoFillOutcome(
      draft: next.copyWith(aiScannedDocs: mergedScanned),
      appliedFields: applied,
    );
  }

  FranchiseWizardDraft copyWith({
    WizardFlowMode? mode,
    String? targetFranchiseId,
    int? currentStep,
    String? fullName,
    String? barangay,
    String? zone,
    String? todaName,
    String? bodyNumber,
    String? plateNo,
    String? make,
    String? made,
    String? motorNo,
    String? chassisNo,
    String? color,
    String? series,
    String? crNo,
    String? orNo,
    String? orCrNo,
    String? orCrExpiryDate,
    String? fileNo,
    String? existingOrCrUrl,
    String? existingCrUrl,
    String? existingOrUrl,
    bool? isOperatorDriver,
    String? driverName,
    String? driverContact,
    String? driverLicenseNo,
    String? driverLicenseSerialNo,
    String? driverLicenseExpiryDate,
    String? driverDlCodes,
    String? driverConditions,
    String? driverAddress,
    String? brgyClearanceNo,
    String? brgyClearanceDate,
    String? existingLicenseUrl,
    String? existingLicenseBackUrl,
    String? existingBrgyClearanceUrl,
    String? cedulaSerialNo,
    String? cedulaDate,
    String? cedulaAddress,
    String? cedulaYear,
    String? cedulaFullName,
    String? cedulaCitizenship,
    String? cedulaCivilStatus,
    String? cedulaProfession,
    String? cedulaTin,
    String? existingCedulaUrl,
    String? rejectedField,
    String? cancelReason,
    Map<String, dynamic>? aiScannedDocs,
    DateTime? savedAt,
  }) {
    return FranchiseWizardDraft(
      mode: mode ?? this.mode,
      targetFranchiseId: targetFranchiseId ?? this.targetFranchiseId,
      currentStep: currentStep ?? this.currentStep,
      fullName: fullName ?? this.fullName,
      barangay: barangay ?? this.barangay,
      zone: zone ?? this.zone,
      todaName: todaName ?? this.todaName,
      bodyNumber: bodyNumber ?? this.bodyNumber,
      plateNo: plateNo ?? this.plateNo,
      make: make ?? this.make,
      made: made ?? this.made,
      motorNo: motorNo ?? this.motorNo,
      chassisNo: chassisNo ?? this.chassisNo,
      color: color ?? this.color,
      series: series ?? this.series,
      crNo: crNo ?? this.crNo,
      orNo: orNo ?? this.orNo,
      orCrNo: orCrNo ?? this.orCrNo,
      orCrExpiryDate: orCrExpiryDate ?? this.orCrExpiryDate,
      fileNo: fileNo ?? this.fileNo,
      existingOrCrUrl: existingOrCrUrl ?? this.existingOrCrUrl,
      existingCrUrl: existingCrUrl ?? this.existingCrUrl,
      existingOrUrl: existingOrUrl ?? this.existingOrUrl,
      isOperatorDriver: isOperatorDriver ?? this.isOperatorDriver,
      driverName: driverName ?? this.driverName,
      driverContact: driverContact ?? this.driverContact,
      driverLicenseNo: driverLicenseNo ?? this.driverLicenseNo,
      driverLicenseSerialNo:
          driverLicenseSerialNo ?? this.driverLicenseSerialNo,
      driverLicenseExpiryDate:
          driverLicenseExpiryDate ?? this.driverLicenseExpiryDate,
      driverDlCodes: driverDlCodes ?? this.driverDlCodes,
      driverConditions: driverConditions ?? this.driverConditions,
      driverAddress: driverAddress ?? this.driverAddress,
      brgyClearanceNo: brgyClearanceNo ?? this.brgyClearanceNo,
      brgyClearanceDate: brgyClearanceDate ?? this.brgyClearanceDate,
      existingLicenseUrl: existingLicenseUrl ?? this.existingLicenseUrl,
      existingLicenseBackUrl:
          existingLicenseBackUrl ?? this.existingLicenseBackUrl,
      existingBrgyClearanceUrl:
          existingBrgyClearanceUrl ?? this.existingBrgyClearanceUrl,
      cedulaSerialNo: cedulaSerialNo ?? this.cedulaSerialNo,
      cedulaDate: cedulaDate ?? this.cedulaDate,
      cedulaAddress: cedulaAddress ?? this.cedulaAddress,
      cedulaYear: cedulaYear ?? this.cedulaYear,
      cedulaFullName: cedulaFullName ?? this.cedulaFullName,
      cedulaCitizenship: cedulaCitizenship ?? this.cedulaCitizenship,
      cedulaCivilStatus: cedulaCivilStatus ?? this.cedulaCivilStatus,
      cedulaProfession: cedulaProfession ?? this.cedulaProfession,
      cedulaTin: cedulaTin ?? this.cedulaTin,
      existingCedulaUrl: existingCedulaUrl ?? this.existingCedulaUrl,
      rejectedField: rejectedField ?? this.rejectedField,
      cancelReason: cancelReason ?? this.cancelReason,
      aiScannedDocs: aiScannedDocs ?? this.aiScannedDocs,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'targetFranchiseId': targetFranchiseId,
        'currentStep': currentStep,
        'fullName': fullName,
        'barangay': barangay,
        'zone': zone,
        'todaName': todaName,
        'bodyNumber': bodyNumber,
        'plateNo': plateNo,
        'make': make,
        'made': made,
        'motorNo': motorNo,
        'chassisNo': chassisNo,
        'color': color,
        'series': series,
        'crNo': crNo,
        'orNo': orNo,
        'orCrNo': orCrNo,
        'orCrExpiryDate': orCrExpiryDate,
        'fileNo': fileNo,
        'existingOrCrUrl': existingOrCrUrl,
        'existingCrUrl': existingCrUrl,
        'existingOrUrl': existingOrUrl,
        'isOperatorDriver': isOperatorDriver,
        'driverName': driverName,
        'driverContact': driverContact,
        'driverLicenseNo': driverLicenseNo,
        'driverLicenseSerialNo': driverLicenseSerialNo,
        'driverLicenseExpiryDate': driverLicenseExpiryDate,
        'driverDlCodes': driverDlCodes,
        'driverConditions': driverConditions,
        'driverAddress': driverAddress,
        'brgyClearanceNo': brgyClearanceNo,
        'brgyClearanceDate': brgyClearanceDate,
        'existingLicenseUrl': existingLicenseUrl,
        'existingLicenseBackUrl': existingLicenseBackUrl,
        'existingBrgyClearanceUrl': existingBrgyClearanceUrl,
        'cedulaSerialNo': cedulaSerialNo,
        'cedulaDate': cedulaDate,
        'cedulaAddress': cedulaAddress,
        'cedulaYear': cedulaYear,
        'cedulaFullName': cedulaFullName,
        'cedulaCitizenship': cedulaCitizenship,
        'cedulaCivilStatus': cedulaCivilStatus,
        'cedulaProfession': cedulaProfession,
        'cedulaTin': cedulaTin,
        'existingCedulaUrl': existingCedulaUrl,
        'rejectedField': rejectedField,
        'cancelReason': cancelReason,
        'aiScannedDocs': aiScannedDocs,
        'savedAt': savedAt?.toUtc().toIso8601String(),
      };

  factory FranchiseWizardDraft.fromJson(Map<String, dynamic> json) {
    final rawMode = (json['mode'] ?? '').toString();
    final mode = WizardFlowMode.values.firstWhere(
      (m) => m.name == rawMode,
      orElse: () => WizardFlowMode.newApplication,
    );
    final scannedRaw = json['aiScannedDocs'];
    return FranchiseWizardDraft(
      mode: mode,
      targetFranchiseId: (json['targetFranchiseId'] ?? '').toString(),
      currentStep: (json['currentStep'] is int)
          ? json['currentStep'] as int
          : int.tryParse(json['currentStep']?.toString() ?? '') ?? 0,
      fullName: (json['fullName'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      zone: (json['zone'] ?? '').toString(),
      todaName: (json['todaName'] ?? 'NON-TODA').toString(),
      bodyNumber: (json['bodyNumber'] ?? '').toString(),
      plateNo: (json['plateNo'] ?? '').toString(),
      make: (json['make'] ?? '').toString(),
      made: (json['made'] ?? '').toString(),
      motorNo: (json['motorNo'] ?? '').toString(),
      chassisNo: (json['chassisNo'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      series: (json['series'] ?? '').toString(),
      crNo: (json['crNo'] ?? '').toString(),
      orNo: (json['orNo'] ?? '').toString(),
      orCrNo: (json['orCrNo'] ?? '').toString(),
      orCrExpiryDate: (json['orCrExpiryDate'] ?? '').toString(),
      fileNo: (json['fileNo'] ?? '').toString(),
      existingOrCrUrl: (json['existingOrCrUrl'] ?? '').toString(),
      existingCrUrl: (json['existingCrUrl'] ?? '').toString(),
      existingOrUrl: (json['existingOrUrl'] ?? '').toString(),
      isOperatorDriver: json['isOperatorDriver'] != false,
      driverName: (json['driverName'] ?? '').toString(),
      driverContact: (json['driverContact'] ?? '').toString(),
      driverLicenseNo: (json['driverLicenseNo'] ?? '').toString(),
      driverLicenseSerialNo: (json['driverLicenseSerialNo'] ?? '').toString(),
      driverLicenseExpiryDate:
          (json['driverLicenseExpiryDate'] ?? '').toString(),
      driverDlCodes: (json['driverDlCodes'] ?? 'A, A1').toString(),
      driverConditions: (json['driverConditions'] ?? 'None').toString(),
      driverAddress: (json['driverAddress'] ?? '').toString(),
      brgyClearanceNo: (json['brgyClearanceNo'] ?? '').toString(),
      brgyClearanceDate: (json['brgyClearanceDate'] ?? '').toString(),
      existingLicenseUrl: (json['existingLicenseUrl'] ?? '').toString(),
      existingLicenseBackUrl: (json['existingLicenseBackUrl'] ?? '').toString(),
      existingBrgyClearanceUrl:
          (json['existingBrgyClearanceUrl'] ?? '').toString(),
      cedulaSerialNo: (json['cedulaSerialNo'] ?? '').toString(),
      cedulaDate: (json['cedulaDate'] ?? '').toString(),
      cedulaAddress:
          (json['cedulaAddress'] ?? 'Gasan, Marinduque').toString(),
      cedulaYear: (json['cedulaYear'] ?? '').toString(),
      cedulaFullName: (json['cedulaFullName'] ?? '').toString(),
      cedulaCitizenship: (json['cedulaCitizenship'] ?? 'Filipino').toString(),
      cedulaCivilStatus: (json['cedulaCivilStatus'] ?? '').toString(),
      cedulaProfession: (json['cedulaProfession'] ?? '').toString(),
      cedulaTin: (json['cedulaTin'] ?? '').toString(),
      existingCedulaUrl: (json['existingCedulaUrl'] ?? '').toString(),
      rejectedField: (json['rejectedField'] ?? '').toString(),
      cancelReason: (json['cancelReason'] ?? '').toString(),
      aiScannedDocs: scannedRaw is Map
          ? Map<String, dynamic>.from(scannedRaw)
          : const {},
      savedAt: ManilaDateFormatter.tryParseIso(json['savedAt']),
    );
  }

  static String _todayManilaIso() {
    final m = ManilaDateFormatter.toManilaWallClock(DateTime.now().toUtc());
    return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }

  static String _toIsoDate(DateTime dt) {
    final m = ManilaDateFormatter.toManilaWallClock(dt);
    return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }

  static String _matchOfficialBarangay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final clean = raw.trim().toLowerCase();
    for (final b in GasanConstants.barangays) {
      if (clean == b.toLowerCase() || clean.contains(b.toLowerCase())) {
        return b;
      }
    }
    if (clean.contains('uno') || clean.contains('brgy. i') || clean.contains('brgy i')) {
      return 'Barangay I (Poblacion)';
    }
    if (clean.contains('dos') || clean.contains('brgy. ii') || clean.contains('brgy ii')) {
      return 'Barangay II (Poblacion)';
    }
    if (clean.contains('tres') || clean.contains('brgy. iii') || clean.contains('brgy iii')) {
      return 'Barangay III (Poblacion)';
    }
    return '';
  }

  static int _targetStepForRejectedField(String field, String cancelReason) {
    final f = field.trim().toLowerCase();
    final r = cancelReason.trim().toLowerCase();
    if ({'plateno', 'motorno', 'chassisno', 'make', 'made', 'orcrdocument', 'crdocument', 'ordocument'}.contains(f) ||
        r.contains('plate') ||
        r.contains('motor') ||
        r.contains('chassis') ||
        r.contains('or/cr')) {
      return 1;
    }
    if ({'license', 'licenseback', 'brgyclearance'}.contains(f) ||
        r.contains('license') ||
        r.contains('clearance')) {
      return 2;
    }
    if ({'cedulaserialno', 'ceduladate', 'cedulaaddress', 'ceduladoc'}.contains(f) ||
        r.contains('cedula') ||
        r.contains('ctc')) {
      return 3;
    }
    return 0;
  }
}
