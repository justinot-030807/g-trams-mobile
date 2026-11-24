import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/network/server_time_sync.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';

/// Classification status of an uploaded document after OCR validation.
enum OcrFeedbackStatus {
  /// Document matched the expected official type and key fields were extracted.
  verified,

  /// Wrong document type, mismatched/invalid image, or unreadable (0 key fields).
  rejected,

  /// OCR backend service is offline, timed out, or unconfigured (manual fallback).
  serviceUnavailable,
}

/// Feedback badge displayed on a document card after OCR validation runs.
class OcrDocumentFeedback {
  const OcrDocumentFeedback({
    required this.status,
    required this.message,
    this.title = '',
    this.detectedDocumentType = '',
    this.appliedFields = const [],
  });

  final OcrFeedbackStatus status;
  final String title;
  final String message;
  final String detectedDocumentType;
  final List<String> appliedFields;

  bool get success => status == OcrFeedbackStatus.verified;
  bool get isRejected => status == OcrFeedbackStatus.rejected;
  bool get isServiceUnavailable =>
      status == OcrFeedbackStatus.serviceUnavailable;
}

class FranchiseWizardState {
  const FranchiseWizardState({
    required this.draft,
    this.attachments = const {},
    this.scanningDocKey,
    this.ocrFeedback = const {},
    this.uniqueChecks = const {},
    this.checkingUniqueFields = const {},
    this.todaJurisdictionCheck,
    this.hasResumedDraft = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.submittedFranchise,
    this.targetUnitForRenewal,
  });

  final FranchiseWizardDraft draft;
  final Map<String, ScannedDocumentAttachment> attachments;
  final String? scanningDocKey;
  final Map<String, OcrDocumentFeedback> ocrFeedback;
  final Map<String, UniqueFieldCheckResult> uniqueChecks;
  final Set<String> checkingUniqueFields;
  final TodaJurisdictionCheckResult? todaJurisdictionCheck;
  final bool hasResumedDraft;
  final bool isSubmitting;
  final String? errorMessage;
  final FranchiseRecord? submittedFranchise;
  final FranchiseRecord? targetUnitForRenewal;

  bool get isScanningAny => scanningDocKey != null;

  bool isDocRejected(String fieldKey) =>
      ocrFeedback[fieldKey]?.isRejected == true;

  bool hasValidAttachment(String fieldKey) =>
      attachments.containsKey(fieldKey) && !isDocRejected(fieldKey);

  bool _hasValidSlotOrExisting(String fieldKey, String existingUrl) {
    if (isDocRejected(fieldKey)) return false;
    return attachments.containsKey(fieldKey) || existingUrl.isNotEmpty;
  }

  bool hasRejectedAttachmentOnStep(int step) {
    final keys = switch (step) {
      1 => const ['orCrDocument', 'crDocument', 'orDocument'],
      2 => const ['license', 'licenseBack', 'brgyClearance'],
      3 => const ['cedulaDoc'],
      _ => const <String>[],
    };
    return keys.any(isDocRejected);
  }

  bool get hasAnyRejectedDoc =>
      ocrFeedback.values.any((fb) => fb.isRejected);

  bool get hasAnyOrCrDoc =>
      _hasValidSlotOrExisting('orCrDocument', draft.existingOrCrUrl) ||
      _hasValidSlotOrExisting('crDocument', draft.existingCrUrl) ||
      _hasValidSlotOrExisting('orDocument', draft.existingOrUrl);

  bool get hasLicenseDoc =>
      _hasValidSlotOrExisting('license', draft.existingLicenseUrl);

  bool get hasBrgyClearanceDoc =>
      _hasValidSlotOrExisting('brgyClearance', draft.existingBrgyClearanceUrl);

  bool get hasCedulaDoc =>
      _hasValidSlotOrExisting('cedulaDoc', draft.existingCedulaUrl);

  bool get hasDuplicateConflict => uniqueChecks.values.any((c) => !c.isUnique);

  FranchiseWizardState copyWith({
    FranchiseWizardDraft? draft,
    Map<String, ScannedDocumentAttachment>? attachments,
    String? scanningDocKey,
    bool clearScanning = false,
    Map<String, OcrDocumentFeedback>? ocrFeedback,
    Map<String, UniqueFieldCheckResult>? uniqueChecks,
    Set<String>? checkingUniqueFields,
    TodaJurisdictionCheckResult? todaJurisdictionCheck,
    bool clearJurisdiction = false,
    bool? hasResumedDraft,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    FranchiseRecord? submittedFranchise,
    bool clearSubmitted = false,
    FranchiseRecord? targetUnitForRenewal,
    bool clearRenewalTarget = false,
  }) {
    return FranchiseWizardState(
      draft: draft ?? this.draft,
      attachments: attachments ?? this.attachments,
      scanningDocKey:
          clearScanning ? null : (scanningDocKey ?? this.scanningDocKey),
      ocrFeedback: ocrFeedback ?? this.ocrFeedback,
      uniqueChecks: uniqueChecks ?? this.uniqueChecks,
      checkingUniqueFields: checkingUniqueFields ?? this.checkingUniqueFields,
      todaJurisdictionCheck: clearJurisdiction
          ? null
          : (todaJurisdictionCheck ?? this.todaJurisdictionCheck),
      hasResumedDraft: hasResumedDraft ?? this.hasResumedDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      submittedFranchise: clearSubmitted
          ? null
          : (submittedFranchise ?? this.submittedFranchise),
      targetUnitForRenewal: clearRenewalTarget
          ? null
          : (targetUnitForRenewal ?? this.targetUnitForRenewal),
    );
  }
}

class FranchiseWizardController extends StateNotifier<FranchiseWizardState> {
  FranchiseWizardController({
    required FranchiseRepository franchiseRepository,
    required WizardDraftCache draftCache,
    required MobileUser? user,
    this.onSubmittedRefreshGarage,
  })  : _repo = franchiseRepository,
        _draftCache = draftCache,
        _user = user,
        super(
          FranchiseWizardState(
            draft: user != null
                ? FranchiseWizardDraft.fromUser(user)
                : const FranchiseWizardDraft(),
          ),
        ) {
    _hydrateApplyDraftIfPresent();
  }

  final FranchiseRepository _repo;
  final WizardDraftCache _draftCache;
  final MobileUser? _user;
  final Future<void> Function()? onSubmittedRefreshGarage;

  void _hydrateApplyDraftIfPresent() {
    final user = _user;
    if (user == null || user.id.isEmpty) return;
    final saved = _draftCache.readApplyDraft(user.id);
    if (saved != null) {
      state = state.copyWith(
        draft: saved,
        hasResumedDraft: true,
      );
    }
  }

  /// Starts a fresh 5-Step New Franchise Application.
  Future<void> startNewApplication({bool clearSavedDraft = false}) async {
    final user = _user;
    if (clearSavedDraft && user != null && user.id.isNotEmpty) {
      await _draftCache.clearApplyDraft(user.id);
    }
    final fresh = user != null
        ? FranchiseWizardDraft.fromUser(user)
        : const FranchiseWizardDraft();
    state = FranchiseWizardState(draft: fresh);
  }

  /// Opens Fix & Reapply mode pre-filled from a rejected franchise record.
  void startFixReapply(FranchiseRecord unit) {
    final user = _user ?? const MobileUser(id: '', name: '', role: 'operator');
    final prefilled = FranchiseWizardDraft.fromExistingFranchise(
      unit: unit,
      user: user,
      mode: WizardFlowMode.fixReapply,
    );
    state = FranchiseWizardState(draft: prefilled);
  }

  /// Opens Renewal mode pre-filled from an eligible franchise record (resuming Hive draft if saved).
  void startRenewal(FranchiseRecord unit) {
    final user = _user ?? const MobileUser(id: '', name: '', role: 'operator');
    final saved = user.id.isNotEmpty
        ? _draftCache.readRenewalDraft(user.id, unit.id)
        : null;
    final draft = saved ??
        FranchiseWizardDraft.fromExistingFranchise(
          unit: unit,
          user: user,
          mode: WizardFlowMode.renewal,
        );
    state = FranchiseWizardState(
      draft: draft,
      hasResumedDraft: saved != null,
      targetUnitForRenewal: unit,
    );
  }

  /// Discards the currently saved Hive draft and resets the active flow cleanly.
  Future<void> discardDraft() async {
    final user = _user;
    final currentMode = state.draft.mode;
    final renewUnit = state.targetUnitForRenewal;
    if (user != null && user.id.isNotEmpty) {
      if (currentMode == WizardFlowMode.renewal && renewUnit != null) {
        await _draftCache.clearRenewalDraft(user.id, renewUnit.id);
      } else {
        await _draftCache.clearApplyDraft(user.id);
      }
    }

    if (currentMode == WizardFlowMode.renewal && renewUnit != null) {
      final fresh = FranchiseWizardDraft.fromExistingFranchise(
        unit: renewUnit,
        user: user ?? const MobileUser(id: '', name: '', role: 'operator'),
        mode: WizardFlowMode.renewal,
      );
      state = FranchiseWizardState(
        draft: fresh,
        targetUnitForRenewal: renewUnit,
      );
    } else {
      await startNewApplication(clearSavedDraft: false);
    }
  }

  /// Updates draft fields and auto-saves immediately to Hive.
  void updateDraft(
    FranchiseWizardDraft Function(FranchiseWizardDraft current) updater,
  ) {
    final nextDraft = updater(state.draft).copyWith(
      savedAt: DateTime.now().toUtc(),
    );
    state = state.copyWith(draft: nextDraft, clearError: true);
    _persistDraft(nextDraft);
  }

  void setStep(int step) {
    final clamped = step.clamp(0, 4);
    updateDraft((d) => d.copyWith(currentStep: clamped));
  }

  void updateBarangay(String barangay) {
    final resolvedZone = GasanConstants.getZoneForBarangay(barangay);
    final allowedTodas = GasanConstants.getTodasForBarangay(barangay);
    var nextToda = state.draft.todaName;
    if (nextToda != 'NON-TODA' &&
        allowedTodas.isNotEmpty &&
        !allowedTodas.any((t) => t.id == nextToda)) {
      nextToda = allowedTodas.first.id;
    }

    updateDraft(
      (d) => d.copyWith(
        barangay: barangay,
        zone: resolvedZone.isNotEmpty ? resolvedZone : d.zone,
        todaName: nextToda,
        cedulaAddress: d.cedulaAddress.isEmpty ||
                d.cedulaAddress == 'Gasan, Marinduque'
            ? '$barangay, Gasan, Marinduque'
            : d.cedulaAddress,
      ),
    );
    checkTodaJurisdiction();
  }

  void updateToda(String todaName) {
    final entry = GasanConstants.findTodaById(todaName);
    final entryZone = entry?.zone ?? '';
    final shouldSyncZone = state.draft.barangay.isEmpty &&
        (entryZone == 'Central' || entryZone == 'North' || entryZone == 'South');
    updateDraft(
      (d) => d.copyWith(
        todaName: todaName,
        zone: shouldSyncZone ? entryZone : d.zone,
      ),
    );
    checkTodaJurisdiction();
  }

  Future<void> checkTodaJurisdiction() async {
    final toda = state.draft.todaName.trim();
    final brgy = state.draft.barangay.trim();
    if (toda.isEmpty || toda == 'NON-TODA' || brgy.isEmpty) {
      state = state.copyWith(clearJurisdiction: true);
      return;
    }
    try {
      final result = await _repo.checkTodaJurisdiction(
        todaName: toda,
        barangay: brgy,
      );
      if (!mounted) return;
      state = state.copyWith(todaJurisdictionCheck: result);
    } catch (_) {
      // Non-blocking jurisdiction advisory
    }
  }

  /// Runs real-time uniqueness validation (`plateNo`, `motorNo`, or `chassisNo`).
  Future<void> checkUniqueField(String field, String value) async {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.length < 3) {
      final nextChecks = Map<String, UniqueFieldCheckResult>.from(state.uniqueChecks)
        ..remove(field);
      state = state.copyWith(uniqueChecks: nextChecks);
      return;
    }

    final checking = Set<String>.from(state.checkingUniqueFields)..add(field);
    state = state.copyWith(checkingUniqueFields: checking);

    try {
      final excludeId = state.draft.mode == WizardFlowMode.fixReapply
          ? state.draft.targetFranchiseId
          : null;
      final result = await _repo.checkUniqueField(
        field: field,
        value: trimmed,
        excludeId: excludeId,
      );
      if (!mounted) return;
      final nextChecks = Map<String, UniqueFieldCheckResult>.from(state.uniqueChecks)
        ..[field] = result;
      final nextChecking = Set<String>.from(state.checkingUniqueFields)
        ..remove(field);
      state = state.copyWith(
        uniqueChecks: nextChecks,
        checkingUniqueFields: nextChecking,
      );
    } catch (_) {
      if (!mounted) return;
      final nextChecking = Set<String>.from(state.checkingUniqueFields)
        ..remove(field);
      state = state.copyWith(checkingUniqueFields: nextChecking);
    }
  }

  /// Attaches a scanned/picked file and runs OCR validation (`POST /franchises/scan-document`).
  Future<void> attachAndScanDocument({
    required String fieldKey,
    required String ocrDocType,
    required ScannedDocumentAttachment file,
    bool isFil = false,
  }) async {
    final canonicalDocType = OcrScanResult.canonicalBackendDocType(ocrDocType);
    final nextAttachments =
        Map<String, ScannedDocumentAttachment>.from(state.attachments)
          ..[fieldKey] = file;
    final nextFeedback = Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
      ..remove(fieldKey);

    state = state.copyWith(
      attachments: nextAttachments,
      scanningDocKey: fieldKey,
      ocrFeedback: nextFeedback,
      clearError: true,
    );

    try {
      final result = await _repo.scanDocument(
        file: file,
        docType: canonicalDocType,
      );
      if (!mounted || !identical(state.attachments[fieldKey], file)) return;

      if (result.success &&
          !result.isWrongDocument &&
          result.isValidDocument &&
          result.isExpectedDocumentType &&
          !result.isServiceUnavailable) {
        final outcome =
            state.draft.applyOcrExtraction(canonicalDocType, result.data);
        final isLicenseBack = canonicalDocType == 'licenseBack';
        if (!isLicenseBack &&
            result.extractedFieldCount <= 0 &&
            outcome.appliedFields.isEmpty) {
          _markDocumentRejected(
            fieldKey: fieldKey,
            canonicalDocType: canonicalDocType,
            result: result,
            isFil: isFil,
          );
          return;
        }

        final updatedDraft = outcome.draft.copyWith(
          savedAt: DateTime.now().toUtc(),
        );
        final updatedFeedback =
            Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
              ..[fieldKey] = OcrDocumentFeedback(
                status: OcrFeedbackStatus.verified,
                detectedDocumentType: result.detectedDocumentType,
                message: outcome.appliedFields.isNotEmpty
                    ? (isFil
                        ? 'Na-auto-fill: ${outcome.appliedFields.join(', ')}'
                        : 'Auto-filled: ${outcome.appliedFields.join(', ')}')
                    : (isFil
                        ? 'Beripikado ang dokumento.'
                        : 'Document verified.'),
                appliedFields: outcome.appliedFields,
              );

        state = state.copyWith(
          draft: updatedDraft,
          clearScanning: true,
          ocrFeedback: updatedFeedback,
        );
        _persistDraft(updatedDraft);

        // Immediately verify uniqueness if Plate/Motor/Chassis came from OCR
        if (canonicalDocType == 'orCr') {
          if (updatedDraft.plateNo.length >= 3) {
            checkUniqueField('plateNo', updatedDraft.plateNo);
          }
          if (updatedDraft.motorNo.length >= 3) {
            checkUniqueField('motorNo', updatedDraft.motorNo);
          }
          if (updatedDraft.chassisNo.length >= 3) {
            checkUniqueField('chassisNo', updatedDraft.chassisNo);
          }
        }
      } else if (result.isServiceUnavailable) {
        final updatedFeedback =
            Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
              ..[fieldKey] = OcrDocumentFeedback(
                status: OcrFeedbackStatus.serviceUnavailable,
                title: isFil
                    ? 'Hindi Magamit ang OCR — Suriin Nang Manual'
                    : 'OCR Unavailable — Verify Manually',
                message: isFil
                    ? 'Nakalakip na ang file ngunit pansamantalang hindi magamit ang OCR. Suriin ang larawan at ilagay nang manual ang detalye.'
                    : 'File attached, but auto-scan is temporarily unavailable. Verify the photo and enter details manually below.',
              );
        state = state.copyWith(
          clearScanning: true,
          ocrFeedback: updatedFeedback,
        );
      } else {
        _markDocumentRejected(
          fieldKey: fieldKey,
          canonicalDocType: canonicalDocType,
          result: result,
          isFil: isFil,
        );
      }
    } catch (err) {
      if (!mounted || !identical(state.attachments[fieldKey], file)) return;
      final apiErr = ApiClient.mapDioError(err);
      if (apiErr.statusCode == 400 || apiErr.statusCode == 422) {
        final parsed = apiErr.rawData != null
            ? OcrScanResult.fromJson(
                apiErr.rawData!,
                fallbackDocType: canonicalDocType,
              )
            : OcrScanResult(
                success: false,
                docType: canonicalDocType,
                isValidDocument: false,
                isExpectedDocumentType: false,
                isWrongDocument: true,
                message: apiErr.message,
                mismatchReason: apiErr.message,
              );
        _markDocumentRejected(
          fieldKey: fieldKey,
          canonicalDocType: canonicalDocType,
          result: parsed,
          isFil: isFil,
        );
        return;
      }

      final updatedFeedback =
          Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
            ..[fieldKey] = OcrDocumentFeedback(
              status: OcrFeedbackStatus.serviceUnavailable,
              title: isFil
                  ? 'Hindi Magamit ang OCR — Suriin Nang Manual'
                  : 'OCR Unavailable — Verify Manually',
              message: isFil
                  ? 'Nakalakip ang file (${apiErr.message}). Suriin ang larawan at ilagay nang manual ang detalye.'
                  : 'File attached (${apiErr.message}). Verify the photo and enter details manually below.',
            );
      state = state.copyWith(
        clearScanning: true,
        ocrFeedback: updatedFeedback,
      );
    }
  }

  void _markDocumentRejected({
    required String fieldKey,
    required String canonicalDocType,
    required OcrScanResult result,
    required bool isFil,
  }) {
    final expectedLabel =
        _expectedDocumentLabel(fieldKey, canonicalDocType, isFil: isFil);
    final detected = result.detectedDocumentType.trim();
    final reason = result.mismatchReason.trim();
    final reasonLower = reason.toLowerCase();

    final String detailMessage;
    if (detected.isNotEmpty) {
      detailMessage = isFil
          ? 'Maling dokumento o malabo ($detected). Mag-upload ng malinaw na $expectedLabel.'
          : 'Wrong or unreadable document ($detected). Please upload a clear photo of your $expectedLabel.';
    } else if (reason.isNotEmpty &&
        !reasonLower.contains('i-manual') &&
        !reasonLower.contains('manually')) {
      final isFilipinoBackendMsg =
          reasonLower.contains('hindi ito') || reasonLower.contains('mangyaring');
      if (isFil) {
        detailMessage = reason;
      } else if (isFilipinoBackendMsg) {
        detailMessage =
            'Wrong or unreadable document. Please upload a clear photo of your $expectedLabel.';
      } else {
        detailMessage = reason;
      }
    } else {
      detailMessage = isFil
          ? 'Maling dokumento o malabo ang larawan. Mag-upload ng malinaw na $expectedLabel.'
          : 'Wrong or unreadable document. Please upload a clear photo of your $expectedLabel.';
    }

    final updatedFeedback =
        Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
          ..[fieldKey] = OcrDocumentFeedback(
            status: OcrFeedbackStatus.rejected,
            title: isFil
                ? 'Maling Dokumento'
                : 'Wrong or Unreadable Document',
            detectedDocumentType: detected,
            message: detailMessage,
          );
    state = state.copyWith(
      clearScanning: true,
      ocrFeedback: updatedFeedback,
    );
  }

  static String _expectedDocumentLabel(
    String fieldKey,
    String canonicalDocType, {
    required bool isFil,
  }) {
    if (fieldKey == 'crDocument') {
      return 'LTO Certificate of Registration (CR)';
    }
    if (fieldKey == 'orDocument') {
      return 'LTO Official Receipt (OR)';
    }
    switch (canonicalDocType) {
      case 'orCr':
        return 'LTO OR/CR';
      case 'license':
        return isFil
            ? "LTO Driver's License (Harap)"
            : "LTO Driver's License (Front)";
      case 'licenseBack':
        return isFil
            ? "Driver's License (Likod)"
            : "Driver's License (Back)";
      case 'brgyClearance':
        return 'Barangay Clearance';
      case 'cedula':
        return 'Community Tax Certificate (Cedula)';
      default:
        return isFil ? 'opisyal na dokumento' : 'official document';
    }
  }

  void removeAttachment(String fieldKey) {
    final nextAttachments =
        Map<String, ScannedDocumentAttachment>.from(state.attachments)
          ..remove(fieldKey);
    final nextFeedback = Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
      ..remove(fieldKey);
    state = state.copyWith(
      attachments: nextAttachments,
      ocrFeedback: nextFeedback,
    );
  }

  /// Validates a specific step (`0..3`) of the 5-Step Apply/Fix-Reapply Wizard.
  String? validateApplicationStep(int step, {bool isFil = false}) {
    final d = state.draft;
    final todayIso = _todayManilaIso();

    if (step == 0) {
      if (d.fullName.trim().length < 2) {
        return isFil
            ? 'Ilagay ang buong legal na pangalan ng operator.'
            : 'Enter the operator\'s full legal name.';
      }
      if (d.barangay.trim().isEmpty) {
        return isFil
            ? 'Piliin ang iyong Barangay sa Gasan.'
            : 'Select your Barangay in Gasan, Marinduque.';
      }
      if (d.zone.trim().isEmpty) {
        return isFil
            ? 'Kailangan ang Route Zone (Central, North, o South).'
            : 'Select a valid municipal Route Zone.';
      }
      if (d.todaName.trim().isEmpty) {
        return isFil
            ? 'Piliin ang iyong TODA Association (o NON-TODA).'
            : 'Select your TODA Association (or NON-TODA).';
      }
    } else if (step == 1) {
      if (state.hasRejectedAttachmentOnStep(1)) {
        return isFil
            ? 'Palitan o alisin muna ang maling dokumento ng LTO OR/CR bago magpatuloy.'
            : 'Replace or remove the rejected LTO OR/CR document before continuing.';
      }
      if (d.plateNo.trim().isEmpty) {
        return isFil
            ? 'Ilagay ang Plate Number o MV File Number.'
            : 'Enter the Plate Number or MV File Number.';
      }
      if (d.make.trim().isEmpty) {
        return isFil
            ? 'Ilagay ang taták/modelo ng motorsiklo (hal. Honda TMX 125).'
            : 'Enter the motorcycle make/model (e.g. Honda TMX 125).';
      }
      if (d.made.trim().isEmpty) {
        return isFil
            ? 'Ilagay ang Year Model ng sasakyan (hal. 2024).'
            : 'Enter the vehicle Year Model (e.g. 2024).';
      }
      if (d.motorNo.trim().isEmpty) {
        return isFil
            ? 'Ilagay ang Motor / Engine Number.'
            : 'Enter the Motor / Engine Number.';
      }
      if (d.chassisNo.trim().isEmpty) {
        return isFil
            ? 'Ilagay ang Chassis Number.'
            : 'Enter the Chassis Number.';
      }
      if (state.hasDuplicateConflict) {
        final conflict = state.uniqueChecks.values.firstWhere((c) => !c.isUnique);
        return conflict.message.isNotEmpty
            ? conflict.message
            : 'Duplicate vehicle identifier detected.';
      }
      if (d.orCrExpiryDate.isNotEmpty && d.orCrExpiryDate.compareTo(todayIso) < 0) {
        return isFil
            ? 'Nag-expire na ang LTO OR/CR. Kailangan muna itong i-renew sa LTO.'
            : 'LTO OR/CR is already expired. Renew with LTO first.';
      }
      if (!state.hasAnyOrCrDoc) {
        return isFil
            ? 'Mag-scan o mag-upload ng valid na LTO CR o OR bago magpatuloy.'
            : 'Scan or upload a valid LTO CR / OR document before proceeding.';
      }
    } else if (step == 2) {
      if (state.hasRejectedAttachmentOnStep(2)) {
        return isFil
            ? 'Palitan o alisin muna ang maling dokumento bago magpatuloy.'
            : 'Replace or remove the rejected document before continuing.';
      }
      if (!d.isOperatorDriver && d.driverName.trim().length < 2) {
        return isFil
            ? 'Ilagay ang pangalan ng itinalagang driver.'
            : 'Enter the assigned driver\'s full name.';
      }
      if (d.driverDlCodes.trim().isNotEmpty &&
          !kAllowedDlCodes.contains(d.driverDlCodes.trim())) {
        return isFil
            ? 'Ang DL Code ay dapat A, A1, o A lamang para sa tricycle.'
            : 'Authorized DL codes must be A, A1, or A.';
      }
      if (d.driverLicenseExpiryDate.isNotEmpty &&
          d.driverLicenseExpiryDate.compareTo(todayIso) < 0) {
        return isFil
            ? "Nag-expire na ang Driver's License."
            : "Driver's License expiry date is already expired.";
      }
      if (!state.hasLicenseDoc) {
        return isFil
            ? "Mag-scan o mag-upload ng valid na Driver's License (Harap)."
            : "Scan or upload a valid Driver's License (Front).";
      }
      if (!state.hasBrgyClearanceDoc) {
        return isFil
            ? 'Mag-scan o mag-upload ng valid na Barangay Clearance.'
            : 'Scan or upload a valid Barangay Clearance.';
      }
    } else if (step == 3) {
      if (state.hasRejectedAttachmentOnStep(3)) {
        return isFil
            ? 'Palitan o alisin muna ang maling larawan ng Cedula bago magpatuloy.'
            : 'Replace or remove the rejected Cedula photo before continuing.';
      }
      return _validateCedulaFields(d, todayIso, isFil: isFil);
    }

    return null;
  }

  /// Validates the Renewal form before calling `PUT /franchises/:id/renew`.
  String? validateRenewal({bool isFil = false}) {
    if (state.hasAnyRejectedDoc) {
      return isFil
          ? 'Palitan o alisin muna ang maling dokumento bago isumite ang renewal.'
          : 'Replace or remove the rejected document before submitting renewal.';
    }
    final d = state.draft;
    final todayIso = _todayManilaIso();
    final cedulaErr = _validateCedulaFields(d, todayIso, isFil: isFil);
    if (cedulaErr != null) return cedulaErr;

    if (d.orCrExpiryDate.isNotEmpty && d.orCrExpiryDate.compareTo(todayIso) < 0) {
      return isFil
          ? 'Nag-expire na ang LTO OR/CR. Kailangan muna itong i-renew sa LTO.'
          : 'Expired LTO OR/CR: Renewal with LTO is required first.';
    }
    if (d.driverLicenseExpiryDate.isNotEmpty &&
        d.driverLicenseExpiryDate.compareTo(todayIso) < 0) {
      return isFil
          ? "Nag-expire na ang Driver's License. Mag-upload ng bagong lisensya."
          : "Expired Driver's License: Renewal with LTO is required first.";
    }
    return null;
  }

  /// Submits New Application, Fix & Reapply, or Renewal and refreshes Garage!
  Future<FranchiseRecord?> submit({bool isFil = false}) async {
    if (state.isSubmitting) return null;

    if (state.draft.mode == WizardFlowMode.renewal) {
      final err = validateRenewal(isFil: isFil);
      if (err != null) {
        state = state.copyWith(errorMessage: err);
        return null;
      }
    } else {
      for (var s = 0; s <= 3; s++) {
        final err = validateApplicationStep(s, isFil: isFil);
        if (err != null) {
          state = state.copyWith(
            draft: state.draft.copyWith(currentStep: s),
            errorMessage: err,
          );
          return null;
        }
      }
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final FranchiseRecord saved;
      final d = state.draft;
      final validAttachments = Map<String, ScannedDocumentAttachment>.fromEntries(
        state.attachments.entries.where((e) => !state.isDocRejected(e.key)),
      );
      if (d.mode == WizardFlowMode.renewal) {
        saved = await _repo.renewFranchise(
          franchiseId: d.targetFranchiseId,
          draft: d,
          attachments: validAttachments,
        );
      } else if (d.mode == WizardFlowMode.fixReapply &&
          d.targetFranchiseId.isNotEmpty) {
        saved = await _repo.updateFranchiseApplication(
          franchiseId: d.targetFranchiseId,
          draft: d,
          attachments: validAttachments,
        );
      } else {
        saved = await _repo.submitNewFranchise(
          draft: d,
          attachments: validAttachments,
        );
      }

      // Clear Hive draft once accepted by server
      final uid = _user?.id ?? '';
      if (uid.isNotEmpty) {
        if (d.mode == WizardFlowMode.renewal && d.targetFranchiseId.isNotEmpty) {
          await _draftCache.clearRenewalDraft(uid, d.targetFranchiseId);
        } else {
          await _draftCache.clearApplyDraft(uid);
        }
      }

      if (onSubmittedRefreshGarage != null) {
        await onSubmittedRefreshGarage!();
      }

      if (!mounted) return saved;
      state = state.copyWith(
        isSubmitting: false,
        submittedFranchise: saved,
        hasResumedDraft: false,
        clearError: true,
      );
      return saved;
    } catch (err) {
      if (!mounted) return null;
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: ApiClient.mapDioError(err).message,
      );
      return null;
    }
  }

  void _persistDraft(FranchiseWizardDraft draft) {
    final uid = _user?.id ?? '';
    if (uid.isEmpty) return;
    if (draft.mode == WizardFlowMode.renewal &&
        draft.targetFranchiseId.isNotEmpty) {
      _draftCache.saveRenewalDraft(uid, draft.targetFranchiseId, draft);
    } else if (draft.mode == WizardFlowMode.newApplication) {
      _draftCache.saveApplyDraft(uid, draft);
    }
  }

  String? _validateCedulaFields(
    FranchiseWizardDraft d,
    String todayIso, {
    required bool isFil,
  }) {
    if (d.cedulaSerialNo.trim().isEmpty) {
      return isFil
          ? 'Ilagay ang Cedula (CTC) Serial Number.'
          : 'Enter the Community Tax Certificate (Cedula) Serial Number.';
    }
    if (d.cedulaDate.trim().isEmpty) {
      return isFil
          ? 'Piliin ang petsa ng pag-isyu ng Cedula.'
          : 'Select the Cedula issue date.';
    }
    if (d.cedulaAddress.trim().isEmpty) {
      return isFil
          ? 'Ilagay ang lugar ng pag-isyu ng Cedula.'
          : 'Enter the Cedula place of issue.';
    }
    final currentYear = int.tryParse(todayIso.substring(0, 4)) ?? 2026;
    final cedulaYear = int.tryParse(
      d.cedulaDate.length >= 4 ? d.cedulaDate.substring(0, 4) : '',
    );
    if (cedulaYear != null && cedulaYear < currentYear) {
      return isFil
          ? 'Luma na ang Cedula ($cedulaYear). Kailangan ang Cedula para sa kasalukuyang taon ($currentYear).'
          : 'Expired Cedula ($cedulaYear). A Cedula issued in the current fiscal year ($currentYear) is required.';
    }
    if (d.cedulaDate.compareTo(todayIso) > 0) {
      return isFil
          ? 'Hindi maaaring nasa hinaharap ang petsa ng Cedula.'
          : 'Cedula date issued cannot be in the future.';
    }
    return null;
  }

  static String _todayManilaIso() {
    final m = ManilaDateFormatter.toManilaWallClock(ServerTimeSync.nowUtc());
    return '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}-${m.day.toString().padLeft(2, '0')}';
  }
}

final StateNotifierProvider<FranchiseWizardController, FranchiseWizardState>
    franchiseWizardControllerProvider =
    StateNotifierProvider<FranchiseWizardController, FranchiseWizardState>(
        (ref) {
  final auth = ref.watch(authControllerProvider);
  return FranchiseWizardController(
    franchiseRepository: ref.watch(franchiseRepositoryProvider),
    draftCache: ref.watch(wizardDraftCacheProvider),
    user: auth.user,
    onSubmittedRefreshGarage: () => ref
        .read(garageControllerProvider.notifier)
        .loadGarage(isPullToRefresh: true),
  );
});
