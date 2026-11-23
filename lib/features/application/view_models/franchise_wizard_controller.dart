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

/// Feedback badge displayed on a document card after 3-Tier AI OCR runs.
class OcrDocumentFeedback {
  const OcrDocumentFeedback({
    required this.success,
    required this.message,
    this.appliedFields = const [],
  });

  final bool success;
  final String message;
  final List<String> appliedFields;
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

  bool get hasAnyOrCrDoc =>
      attachments.containsKey('orCrDocument') ||
      attachments.containsKey('crDocument') ||
      attachments.containsKey('orDocument') ||
      draft.existingOrCrUrl.isNotEmpty ||
      draft.existingCrUrl.isNotEmpty ||
      draft.existingOrUrl.isNotEmpty;

  bool get hasLicenseDoc =>
      attachments.containsKey('license') ||
      draft.existingLicenseUrl.isNotEmpty;

  bool get hasBrgyClearanceDoc =>
      attachments.containsKey('brgyClearance') ||
      draft.existingBrgyClearanceUrl.isNotEmpty;

  bool get hasCedulaDoc =>
      attachments.containsKey('cedulaDoc') ||
      draft.existingCedulaUrl.isNotEmpty;

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

  /// Attaches a scanned/picked file and runs 3-Tier AI OCR (`POST /franchises/scan-document`).
  Future<void> attachAndScanDocument({
    required String fieldKey,
    required String ocrDocType,
    required ScannedDocumentAttachment file,
  }) async {
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
      final result = await _repo.scanDocument(file: file, docType: ocrDocType);
      if (!mounted) return;

      if (result.success && result.data.isNotEmpty) {
        final outcome = state.draft.applyOcrExtraction(ocrDocType, result.data);
        final updatedDraft = outcome.draft.copyWith(
          savedAt: DateTime.now().toUtc(),
        );
        final updatedFeedback =
            Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
              ..[fieldKey] = OcrDocumentFeedback(
                success: true,
                message: outcome.appliedFields.isNotEmpty
                    ? 'AI Auto-Filled: ${outcome.appliedFields.join(', ')}'
                    : 'Document scanned successfully.',
                appliedFields: outcome.appliedFields,
              );

        state = state.copyWith(
          draft: updatedDraft,
          clearScanning: true,
          ocrFeedback: updatedFeedback,
        );
        _persistDraft(updatedDraft);

        // Immediately verify uniqueness if Plate/Motor/Chassis came from OCR
        if (ocrDocType == 'orcr' || ocrDocType == 'cr' || ocrDocType == 'or') {
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
      } else {
        final updatedFeedback =
            Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
              ..[fieldKey] = OcrDocumentFeedback(
                success: false,
                message: result.message.isNotEmpty
                    ? result.message
                    : 'Document attached. Please verify or enter fields manually below.',
              );
        state = state.copyWith(
          clearScanning: true,
          ocrFeedback: updatedFeedback,
        );
      }
    } catch (err) {
      if (!mounted) return;
      final apiErr = ApiClient.mapDioError(err);
      final updatedFeedback =
          Map<String, OcrDocumentFeedback>.from(state.ocrFeedback)
            ..[fieldKey] = OcrDocumentFeedback(
              success: false,
              message:
                  'File attached (${apiErr.message}). You can enter fields manually below.',
            );
      state = state.copyWith(
        clearScanning: true,
        ocrFeedback: updatedFeedback,
      );
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
            ? 'Mag-scan o mag-upload ng LTO CR o OR bago magpatuloy.'
            : 'Scan or upload your LTO CR / OR document before proceeding.';
      }
    } else if (step == 2) {
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
            ? "Mag-scan o mag-upload ng Driver's License (Harap)."
            : "Scan or upload the Driver's License (Front).";
      }
      if (!state.hasBrgyClearanceDoc) {
        return isFil
            ? 'Mag-scan o mag-upload ng Barangay Clearance.'
            : 'Scan or upload your Barangay Clearance.';
      }
    } else if (step == 3) {
      return _validateCedulaFields(d, todayIso, isFil: isFil);
    }

    return null;
  }

  /// Validates the Renewal form before calling `PUT /franchises/:id/renew`.
  String? validateRenewal({bool isFil = false}) {
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
      if (d.mode == WizardFlowMode.renewal) {
        saved = await _repo.renewFranchise(
          franchiseId: d.targetFranchiseId,
          draft: d,
          attachments: state.attachments,
        );
      } else if (d.mode == WizardFlowMode.fixReapply &&
          d.targetFranchiseId.isNotEmpty) {
        saved = await _repo.updateFranchiseApplication(
          franchiseId: d.targetFranchiseId,
          draft: d,
          attachments: state.attachments,
        );
      } else {
        saved = await _repo.submitNewFranchise(
          draft: d,
          attachments: state.attachments,
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
