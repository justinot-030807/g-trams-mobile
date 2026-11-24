import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/application/widgets/document_scanner_card.dart';
import 'package:gtrams_mobile/features/application/widgets/wizard_renewal_view.dart';
import 'package:gtrams_mobile/features/application/widgets/wizard_step_indicator.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Phase 3 — 5-Step Apply & Fix-Reapply Franchise Wizard + Renewal Wizard.
/// Features Android ML Kit Smart Camera Document Scanner, 3-Tier AI OCR Auto-Fill,
/// real-time unique Plate/Motor/Chassis checks, TODA jurisdiction guard, and Hive Draft Auto-Save.
class ApplyRenewWizardTab extends ConsumerStatefulWidget {
  const ApplyRenewWizardTab({
    super.key,
    required this.onGoToGarage,
  });

  final VoidCallback onGoToGarage;

  @override
  ConsumerState<ApplyRenewWizardTab> createState() =>
      _ApplyRenewWizardTabState();
}

class _ApplyRenewWizardTabState extends ConsumerState<ApplyRenewWizardTab> {
  final _scrollCtrl = ScrollController();

  // Persistent controllers kept synchronized with AI OCR / draft reloads
  final _fullNameCtrl = TextEditingController();
  final _bodyNoCtrl = TextEditingController();
  final _plateNoCtrl = TextEditingController();
  final _makeCtrl = TextEditingController();
  final _madeCtrl = TextEditingController();
  final _motorNoCtrl = TextEditingController();
  final _chassisNoCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _orCrNoCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverContactCtrl = TextEditingController();
  final _driverLicenseNoCtrl = TextEditingController();
  final _driverLicenseSerialCtrl = TextEditingController();
  final _brgyClearanceNoCtrl = TextEditingController();
  final _cedulaSerialCtrl = TextEditingController();
  final _cedulaAddressCtrl = TextEditingController();
  final _cedulaProfessionCtrl = TextEditingController();
  final _cedulaTinCtrl = TextEditingController();

  bool _privacyConfirmed = false;
  bool _showAllTodas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncControllersFromDraft(ref.read(franchiseWizardControllerProvider).draft);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _fullNameCtrl.dispose();
    _bodyNoCtrl.dispose();
    _plateNoCtrl.dispose();
    _makeCtrl.dispose();
    _madeCtrl.dispose();
    _motorNoCtrl.dispose();
    _chassisNoCtrl.dispose();
    _colorCtrl.dispose();
    _orCrNoCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverContactCtrl.dispose();
    _driverLicenseNoCtrl.dispose();
    _driverLicenseSerialCtrl.dispose();
    _brgyClearanceNoCtrl.dispose();
    _cedulaSerialCtrl.dispose();
    _cedulaAddressCtrl.dispose();
    _cedulaProfessionCtrl.dispose();
    _cedulaTinCtrl.dispose();
    super.dispose();
  }

  void _syncField(TextEditingController ctrl, String value) {
    if (ctrl.text != value) {
      ctrl.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _syncControllersFromDraft(FranchiseWizardDraft d) {
    _syncField(_fullNameCtrl, d.fullName);
    _syncField(_bodyNoCtrl, d.bodyNumber);
    _syncField(_plateNoCtrl, d.plateNo);
    _syncField(_makeCtrl, d.make);
    _syncField(_madeCtrl, d.made);
    _syncField(_motorNoCtrl, d.motorNo);
    _syncField(_chassisNoCtrl, d.chassisNo);
    _syncField(_colorCtrl, d.color);
    _syncField(_orCrNoCtrl, d.orCrNo);
    _syncField(_driverNameCtrl, d.driverName);
    _syncField(_driverContactCtrl, d.driverContact);
    _syncField(_driverLicenseNoCtrl, d.driverLicenseNo);
    _syncField(_driverLicenseSerialCtrl, d.driverLicenseSerialNo);
    _syncField(_brgyClearanceNoCtrl, d.brgyClearanceNo);
    _syncField(_cedulaSerialCtrl, d.cedulaSerialNo);
    _syncField(_cedulaAddressCtrl, d.cedulaAddress);
    _syncField(_cedulaProfessionCtrl, d.cedulaProfession);
    _syncField(_cedulaTinCtrl, d.cedulaTin);
  }

  Future<void> _pickDate(
    String currentIso,
    ValueChanged<String> onSelected, {
    bool allowFuture = true,
  }) async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(currentIso) ?? now;
    final firstDate = DateTime(now.year - 5, 1, 1);
    final lastDate =
        allowFuture ? DateTime(now.year + 12, 12, 31) : DateTime(now.year, now.month, now.day);
    final safeInitial = initial.isBefore(firstDate)
        ? firstDate
        : (initial.isAfter(lastDate) ? lastDate : initial);

    final picked = await showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    onSelected(iso);
  }

  void _scrollToTop() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep text controllers synced whenever AI OCR auto-fills or mode switches
    ref.listen<FranchiseWizardState>(franchiseWizardControllerProvider, (prev, next) {
      if (prev?.draft != next.draft) {
        _syncControllersFromDraft(next.draft);
      }
    });

    final wizard = ref.watch(franchiseWizardControllerProvider);
    final controller = ref.read(franchiseWizardControllerProvider.notifier);
    final garage = ref.watch(garageControllerProvider);
    final captureService = ref.watch(documentCaptureServiceProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final strings = AppStrings(prefs.language);
    final palette = context.civic;
    final draft = wizard.draft;

    // 1. Success Confirmation State
    if (wizard.submittedFranchise != null) {
      final submitted = wizard.submittedFranchise!;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CivicCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: CivicColors.civicGreenLightBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: CivicColors.civicGreen.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 34,
                    color: CivicColors.civicGreen,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  draft.mode == WizardFlowMode.renewal
                      ? strings.pick(
                          'Renewal Application Submitted!',
                          'Naisumite na ang Renewal!',
                        )
                      : draft.mode == WizardFlowMode.fixReapply
                          ? strings.pick(
                              'Corrected Application Resubmitted!',
                              'Naipadala Muli ang Inayos na Aplikasyon!',
                            )
                          : strings.pick(
                              'Franchise Application Submitted!',
                              'Naisumite na ang Aplikasyon ng Prangkisa!',
                            ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  strings.pick(
                    'Your application for Plate ${submitted.plateNo.isNotEmpty ? submitted.plateNo : draft.plateNo} is now Pending evaluation by the Office of the Municipal Vice Mayor (OVM) — LLSA I.',
                    'Ang aplikasyon para sa Plaka ${submitted.plateNo.isNotEmpty ? submitted.plateNo : draft.plateNo} ay kasalukuyang sinusuri ng Office of the Municipal Vice Mayor (OVM) — LLSA I.',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: palette.muted),
                ),
                const SizedBox(height: 20),
                CivicPrimaryButton(
                  label: strings.backToGarage,
                  icon: Icons.home_outlined,
                  onPressed: () {
                    controller.startNewApplication();
                    widget.onGoToGarage();
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _privacyConfirmed = false);
                    controller.startNewApplication();
                  },
                  child: Text(strings.applyNewAction),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final renewableUnits = garage.franchises
        .where((f) => f.canShowRenewShortcut(garage.settings.renewalReminderDays))
        .toList();
    final isQuotaFullForNew =
        draft.mode == WizardFlowMode.newApplication && !garage.hasAvailableSlot;

    return ListView(
      key: const Key('apply_wizard_list'),
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Flow Header & Mode Switcher
        Row(
          children: [
            Expanded(
              child: Text(
                draft.mode == WizardFlowMode.renewal
                    ? strings.wizardRenewTitle
                    : draft.mode == WizardFlowMode.fixReapply
                        ? strings.wizardFixTitle
                        : strings.wizardNewTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (draft.mode == WizardFlowMode.fixReapply)
              TextButton(
                onPressed: () => controller.startNewApplication(),
                child: Text(strings.pick('New App', 'Bago')),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (draft.mode != WizardFlowMode.fixReapply) ...[
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<WizardFlowMode>(
              segments: [
                ButtonSegment(
                  value: WizardFlowMode.newApplication,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
                  label: Text(strings.pick('New Franchise', 'Bagong Prangkisa')),
                ),
                ButtonSegment(
                  value: WizardFlowMode.renewal,
                  icon: const Icon(Icons.autorenew_rounded, size: 17),
                  label: Text(
                    strings.pick(
                      'Renew (${renewableUnits.length})',
                      'I-renew (${renewableUnits.length})',
                    ),
                  ),
                ),
              ],
              selected: {draft.mode},
              onSelectionChanged: (sel) {
                final chosen = sel.first;
                if (chosen == WizardFlowMode.renewal) {
                  if (renewableUnits.isNotEmpty) {
                    controller.startRenewal(renewableUnits.first);
                  } else {
                    controller.updateDraft(
                      (d) => d.copyWith(mode: WizardFlowMode.renewal),
                    );
                  }
                } else {
                  controller.startNewApplication();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Hive Auto-Saved Draft Recovery Bar
        if (draft.savedAt != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.save_outlined,
                  size: 16,
                  color: palette.brandAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${strings.draftAutoSavedLabel} · ${ManilaDateFormatter.formatSyncTimestamp(draft.savedAt, isFil: strings.isFil)}',
                    style: CivicTheme.monoStyle(fontSize: 9.5, color: palette.muted),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => controller.discardDraft(),
                  child: Text(
                    strings.discardDraft,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Fix & Reapply Remarks Banner
        if (draft.mode == WizardFlowMode.fixReapply &&
            draft.cancelReason.isNotEmpty) ...[
          CivicBanner(
            tone: CivicStatusTone.danger,
            icon: Icons.build_circle_outlined,
            title: strings.pick(
              'OVM — LLSA I Remarks to Correct',
              'Puna ng OVM — LLSA I na Kailangang Ayusin',
            ),
            message:
                '${draft.cancelReason}${draft.rejectedField.isNotEmpty ? '\n${strings.pick('Flagged Field', 'Kailangang Ayusin')}: ${draft.rejectedField}' : ''}',
          ),
          const SizedBox(height: 12),
        ],

        // Quota Cap Advisory Banner (for New Applications)
        if (isQuotaFullForNew) ...[
          CivicBanner(
            tone: CivicStatusTone.inProgress,
            icon: Icons.info_outline_rounded,
            title: strings.pick(
              'Unit Quota Reached (${garage.slotOccupyingCount}/${garage.maxUnits})',
              'Puno na ang Limitasyon ng Unit (${garage.slotOccupyingCount}/${garage.maxUnits})',
            ),
            message: strings.pick(
              'Operators may hold up to ${garage.maxUnits} active/pending units. Renew an eligible franchise or withdraw an unpaid pending one.',
              'Hanggang ${garage.maxUnits} aktibo o nakabinbing unit lamang bawat operator. Maaari kang mag-renew o mag-withdraw ng nakabinbing aplikasyon.',
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Validation / API Error Banner
        if (wizard.errorMessage != null) ...[
          CivicBanner(
            tone: CivicStatusTone.danger,
            message: wizard.errorMessage!,
          ),
          const SizedBox(height: 12),
        ],

        // RENEWAL MODE vs 5-STEP APPLICATION / FIX-REAPPLY WIZARD
        if (draft.mode == WizardFlowMode.renewal)
          WizardRenewalView(
            state: wizard,
            controller: controller,
            captureService: captureService,
            strings: strings,
            renewableUnits: renewableUnits,
            franchiseFee: garage.settings.franchiseFee,
            cedulaSerialCtrl: _cedulaSerialCtrl,
            cedulaAddressCtrl: _cedulaAddressCtrl,
            orCrNoCtrl: _orCrNoCtrl,
            driverLicenseNoCtrl: _driverLicenseNoCtrl,
            onPickDate: _pickDate,
            onSubmit: () => controller.submit(isFil: strings.isFil),
          )
        else ...[
          // 5-Step Progress Indicator
          WizardStepIndicator(
            currentStep: draft.currentStep,
            strings: strings,
            onStepTapped: (step) {
              controller.setStep(step);
              _scrollToTop();
            },
          ),
          const SizedBox(height: 14),

          // Active Step Content
          if (draft.currentStep == 0)
            _buildStep1OperatorToda(context, wizard, controller, strings)
          else if (draft.currentStep == 1)
            _buildStep2VehicleOrCr(
              context,
              wizard,
              controller,
              captureService,
              strings,
            )
          else if (draft.currentStep == 2)
            _buildStep3LicenseClearance(
              context,
              wizard,
              controller,
              captureService,
              strings,
            )
          else if (draft.currentStep == 3)
            _buildStep4Cedula(
              context,
              wizard,
              controller,
              captureService,
              strings,
            )
          else
            _buildStep5SummarySubmit(
              context,
              wizard,
              strings,
              garage.settings.franchiseFee,
            ),

          const SizedBox(height: 18),

          // Step Navigation Footer (48dp touch height)
          Row(
            children: [
              if (draft.currentStep > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('wizard_back_button'),
                    onPressed: wizard.isSubmitting
                        ? null
                        : () {
                            controller.setStep(draft.currentStep - 1);
                            _scrollToTop();
                          },
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: Text(strings.backStep),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: draft.currentStep < 4
                    ? CivicPrimaryButton(
                        key: const Key('wizard_next_button'),
                        label: strings.nextStep,
                        icon: Icons.arrow_forward_rounded,
                        onPressed: wizard.isScanningAny
                            ? null
                            : () {
                                final err = controller.validateApplicationStep(
                                  draft.currentStep,
                                  isFil: strings.isFil,
                                );
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err)),
                                  );
                                  return;
                                }
                                controller.setStep(draft.currentStep + 1);
                                _scrollToTop();
                              },
                      )
                    : CivicPrimaryButton(
                        key: const Key('wizard_submit_button'),
                        label: draft.mode == WizardFlowMode.fixReapply
                            ? strings.resubmitApplication
                            : strings.submitApplication,
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: wizard.isSubmitting,
                        onPressed: (!(_privacyConfirmed) ||
                                wizard.isScanningAny ||
                                isQuotaFullForNew)
                            ? null
                            : () => controller.submit(isFil: strings.isFil),
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1: Operator & Accredited TODA (with Barangay -> Zone -> TODA Routing)
  // ---------------------------------------------------------------------------
  Widget _buildStep1OperatorToda(
    BuildContext context,
    FranchiseWizardState wizard,
    FranchiseWizardController controller,
    AppStrings strings,
  ) {
    final palette = context.civic;
    final d = wizard.draft;
    final matchedTodas = d.barangay.isNotEmpty && !_showAllTodas
        ? [
            ...GasanConstants.getTodasForBarangay(d.barangay),
            GasanConstants.todaDirectory.last, // NON-TODA always selectable
          ]
        : GasanConstants.todaDirectory;

    final todaIds = matchedTodas.map((t) => t.id).toList();
    if (d.todaName.isNotEmpty && !todaIds.contains(d.todaName)) {
      todaIds.insert(0, d.todaName);
    }

    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CivicFieldLabel(text: strings.fullNameLabel, isRequired: true),
          TextField(
            key: const Key('wizard_fullname_field'),
            controller: _fullNameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) =>
                controller.updateDraft((cur) => cur.copyWith(fullName: v)),
            decoration: InputDecoration(
              hintText: strings.fullNameHint,
              prefixIcon: Icon(Icons.person_outline_rounded, color: palette.muted),
            ),
          ),
          const SizedBox(height: 14),

          CivicFieldLabel(text: strings.barangayLabel, isRequired: true),
          DropdownButtonFormField<String>(
            key: const Key('wizard_barangay_dropdown'),
            initialValue: GasanConstants.barangays.contains(d.barangay)
                ? d.barangay
                : null,
            isExpanded: true,
            hint: Text(strings.selectBarangay),
            items: GasanConstants.barangays
                .map(
                  (b) => DropdownMenuItem<String>(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) controller.updateBarangay(val);
            },
          ),
          const SizedBox(height: 10),

          if (d.zone.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: palette.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.map_outlined, size: 16, color: palette.brandAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${strings.pick('Route Zone', 'Route Zone')}: ${d.zone.toUpperCase()}',
                      style: CivicTheme.monoStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: CivicFieldLabel(text: strings.todaLabel, isRequired: true),
              ),
              if (d.barangay.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => setState(() => _showAllTodas = !_showAllTodas),
                  child: Text(
                    _showAllTodas
                        ? strings.pick('Filter by Brgy', 'I-filter sa Brgy')
                        : strings.pick('Show All TODAs', 'Lahat ng TODA'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            key: const Key('wizard_toda_dropdown'),
            initialValue: todaIds.contains(d.todaName) ? d.todaName : null,
            isExpanded: true,
            hint: Text(strings.selectToda),
            items: todaIds.map((id) {
              final entry = GasanConstants.findTodaById(id);
              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  entry != null ? entry.name : id,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) controller.updateToda(val);
            },
          ),

          if (wizard.todaJurisdictionCheck?.isMismatch == true) ...[
            const SizedBox(height: 10),
            CivicBanner(
              tone: CivicStatusTone.inProgress,
              title: strings.pick(
                'TODA Jurisdiction Advisory',
                'Paalala sa Saklaw ng TODA',
              ),
              message: wizard.todaJurisdictionCheck!.jurisdictionWarning.isNotEmpty
                  ? wizard.todaJurisdictionCheck!.jurisdictionWarning
                  : strings.pick(
                      'Selected TODA does not normally cover this barangay. Verify with OVM — LLSA I.',
                      'Hindi karaniwang saklaw ng napiling TODA ang barangay na ito.',
                    ),
            ),
          ],
          const SizedBox(height: 14),

          CivicFieldLabel(
            text: strings.pick('Assigned Body / Sidecar Number (Optional)', 'Body / Sidecar Number (Opsyonal)'),
          ),
          TextField(
            controller: _bodyNoCtrl,
            textCapitalization: TextCapitalization.characters,
            onChanged: (v) => controller.updateDraft(
              (cur) => cur.copyWith(bodyNumber: v.trim().toUpperCase()),
            ),
            decoration: InputDecoration(
              hintText: strings.bodyNumberHint,
              prefixIcon: Icon(Icons.tag_rounded, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 2: Vehicle Specs & OR/CR (+ Smart Scanner + 3-Tier AI OCR + Unique Check)
  // ---------------------------------------------------------------------------
  Widget _buildStep2VehicleOrCr(
    BuildContext context,
    FranchiseWizardState wizard,
    FranchiseWizardController controller,
    DocumentCaptureService captureService,
    AppStrings strings,
  ) {
    final palette = context.civic;
    final d = wizard.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentScannerCard(
          key: const Key('scanner_card_cr'),
          title: strings.pick(
            'LTO Certificate of Registration (CR)',
            'LTO Certificate of Registration (CR)',
          ),
          subtitle: strings.pick(
            'Auto-fills Plate, Motor, Chassis, Make & Year.',
            'Auto-fill ng Plaka, Motor, Chassis, Taták at Taon.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['crDocument'],
          existingUrl: d.existingCrUrl.isNotEmpty ? d.existingCrUrl : d.existingOrCrUrl,
          isRequired: !wizard.hasAnyOrCrDoc,
          isScanning: wizard.scanningDocKey == 'crDocument',
          ocrFeedback: wizard.ocrFeedback['crDocument'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'crDocument',
            ocrDocType: 'orCr',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('crDocument'),
        ),
        const SizedBox(height: 12),

        DocumentScannerCard(
          key: const Key('scanner_card_or'),
          title: strings.pick(
            'LTO Official Receipt (OR)',
            'LTO Official Receipt (OR)',
          ),
          subtitle: strings.pick(
            'Latest LTO receipt, or skip if combined above.',
            'Pinakabagong resibo ng LTO (opsyonal kung kasama sa taas).',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['orDocument'],
          existingUrl: d.existingOrUrl,
          isScanning: wizard.scanningDocKey == 'orDocument',
          ocrFeedback: wizard.ocrFeedback['orDocument'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'orDocument',
            ocrDocType: 'orCr',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('orDocument'),
        ),
        const SizedBox(height: 14),

        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Vehicle Details', 'Detalye ng Tricycle'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 12),

              // Plate Number + Live Unique Check
              CivicFieldLabel(
                text: strings.pick('Plate / MV File Number', 'Plate / MV File Number'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_plate_field'),
                controller: _plateNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(plateNo: v.trim().toUpperCase()),
                ),
                onEditingComplete: () =>
                    controller.checkUniqueField('plateNo', _plateNoCtrl.text),
                decoration: InputDecoration(
                  hintText: 'e.g. 4528-TC or ABC-1234',
                  suffixIcon: _UniqueStatusIcon(
                    isChecking: wizard.checkingUniqueFields.contains('plateNo'),
                    result: wizard.uniqueChecks['plateNo'],
                    onVerify: () => controller.checkUniqueField(
                      'plateNo',
                      _plateNoCtrl.text,
                    ),
                  ),
                ),
              ),
              _UniqueCheckCaption(result: wizard.uniqueChecks['plateNo']),
              const SizedBox(height: 12),

              // Motor Number + Live Unique Check
              CivicFieldLabel(
                text: strings.pick('Motor / Engine Number', 'Motor / Engine Number'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_motor_field'),
                controller: _motorNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(motorNo: v.trim().toUpperCase()),
                ),
                onEditingComplete: () =>
                    controller.checkUniqueField('motorNo', _motorNoCtrl.text),
                decoration: InputDecoration(
                  hintText: 'e.g. KF51E7890123',
                  suffixIcon: _UniqueStatusIcon(
                    isChecking: wizard.checkingUniqueFields.contains('motorNo'),
                    result: wizard.uniqueChecks['motorNo'],
                    onVerify: () => controller.checkUniqueField(
                      'motorNo',
                      _motorNoCtrl.text,
                    ),
                  ),
                ),
              ),
              _UniqueCheckCaption(result: wizard.uniqueChecks['motorNo']),
              const SizedBox(height: 12),

              // Chassis Number + Live Unique Check
              CivicFieldLabel(
                text: strings.pick('Chassis Number', 'Chassis Number'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_chassis_field'),
                controller: _chassisNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(chassisNo: v.trim().toUpperCase()),
                ),
                onEditingComplete: () =>
                    controller.checkUniqueField('chassisNo', _chassisNoCtrl.text),
                decoration: InputDecoration(
                  hintText: 'e.g. MH1KF5178PK098231',
                  suffixIcon: _UniqueStatusIcon(
                    isChecking: wizard.checkingUniqueFields.contains('chassisNo'),
                    result: wizard.uniqueChecks['chassisNo'],
                    onVerify: () => controller.checkUniqueField(
                      'chassisNo',
                      _chassisNoCtrl.text,
                    ),
                  ),
                ),
              ),
              _UniqueCheckCaption(result: wizard.uniqueChecks['chassisNo']),
              const SizedBox(height: 12),

              // Make & Popular Quick-Pick Chips
              CivicFieldLabel(
                text: strings.pick('Motorcycle Make / Model', 'Taták / Modelo ng Motorsiklo'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_make_field'),
                controller: _makeCtrl,
                onChanged: (v) =>
                    controller.updateDraft((cur) => cur.copyWith(make: v)),
                decoration: const InputDecoration(
                  hintText: 'e.g. Honda TMX 125 Alpha',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: kPopularTricycleMakes.take(4).map((preset) {
                  return ActionChip(
                    label: Text(preset, style: const TextStyle(fontSize: 11.5)),
                    onPressed: () {
                      _syncField(_makeCtrl, preset);
                      controller.updateDraft((cur) => cur.copyWith(make: preset));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CivicFieldLabel(
                          text: strings.pick('Year Model', 'Taon (Model)'),
                          isRequired: true,
                        ),
                        TextField(
                          key: const Key('wizard_made_field'),
                          controller: _madeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          onChanged: (v) => controller.updateDraft(
                            (cur) => cur.copyWith(made: v.trim()),
                          ),
                          decoration: const InputDecoration(
                            hintText: '2024',
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CivicFieldLabel(
                          text: strings.pick('Color', 'Kulay'),
                        ),
                        TextField(
                          controller: _colorCtrl,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (v) => controller.updateDraft(
                            (cur) => cur.copyWith(color: v.trim().toUpperCase()),
                          ),
                          decoration: const InputDecoration(hintText: 'BLACK / RED'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('LTO OR/CR Expiry Date (Optional)', 'Pag-expire ng LTO OR/CR (Opsyonal)'),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pickDate(
                  d.orCrExpiryDate,
                  (iso) => controller.updateDraft(
                    (cur) => cur.copyWith(orCrExpiryDate: iso),
                  ),
                  allowFuture: true,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined, color: palette.muted),
                  ),
                  child: Text(
                    d.orCrExpiryDate.isNotEmpty
                        ? d.orCrExpiryDate
                        : strings.pick('Select OR/CR expiry date', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(
                      fontSize: 13,
                      color:
                          d.orCrExpiryDate.isNotEmpty ? palette.ink : palette.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Driver's License & Barangay Clearance (ZERO TODA Endorsement Upload!)
  // ---------------------------------------------------------------------------
  Widget _buildStep3LicenseClearance(
    BuildContext context,
    FranchiseWizardState wizard,
    FranchiseWizardController controller,
    DocumentCaptureService captureService,
    AppStrings strings,
  ) {
    final palette = context.civic;
    final d = wizard.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentScannerCard(
          key: const Key('scanner_card_license'),
          title: strings.pick("Driver's License (Front)", "Driver's License (Harap)"),
          subtitle: strings.pick(
            'Auto-fills License No., DL Codes, and expiry.',
            'Auto-fill ng License No., DL Codes, at expiry.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['license'],
          existingUrl: d.existingLicenseUrl,
          isRequired: true,
          isScanning: wizard.scanningDocKey == 'license',
          ocrFeedback: wizard.ocrFeedback['license'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'license',
            ocrDocType: 'license',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('license'),
        ),
        const SizedBox(height: 12),

        DocumentScannerCard(
          title: strings.pick("Driver's License (Back)", "Driver's License (Likod)"),
          subtitle: strings.pick(
            'Captures back serial number and restrictions.',
            'Kinokopya ang serial number sa likod.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['licenseBack'],
          existingUrl: d.existingLicenseBackUrl,
          isScanning: wizard.scanningDocKey == 'licenseBack',
          ocrFeedback: wizard.ocrFeedback['licenseBack'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'licenseBack',
            ocrDocType: 'licenseBack',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('licenseBack'),
        ),
        const SizedBox(height: 12),

        DocumentScannerCard(
          key: const Key('scanner_card_brgy'),
          title: strings.pick('Barangay Clearance', 'Barangay Clearance'),
          subtitle: strings.pick(
            'Issued by your Gasan Barangay Hall.',
            'Mula sa iyong Barangay Hall sa Gasan.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['brgyClearance'],
          existingUrl: d.existingBrgyClearanceUrl,
          isRequired: true,
          isScanning: wizard.scanningDocKey == 'brgyClearance',
          ocrFeedback: wizard.ocrFeedback['brgyClearance'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'brgyClearance',
            ocrDocType: 'brgyClearance',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('brgyClearance'),
        ),
        const SizedBox(height: 14),

        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Driver & Clearance', 'Driver at Clearance'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  strings.pick(
                    'Operator is also the Tricycle Driver',
                    'Ang Operator din ang Driver ng Tricycle',
                  ),
                ),
                value: d.isOperatorDriver,
                onChanged: (val) => controller.updateDraft(
                  (cur) => cur.copyWith(
                    isOperatorDriver: val,
                    driverName: val ? cur.fullName : cur.driverName,
                  ),
                ),
              ),
              if (!d.isOperatorDriver) ...[
                const SizedBox(height: 8),
                CivicFieldLabel(
                  text: strings.pick('Assigned Driver Full Name', 'Buong Pangalan ng Driver'),
                  isRequired: true,
                ),
                TextField(
                  controller: _driverNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => controller.updateDraft(
                    (cur) => cur.copyWith(driverName: v),
                  ),
                ),
                const SizedBox(height: 10),
                CivicFieldLabel(
                  text: strings.pick('Driver Contact Number', 'Cellphone ng Driver'),
                ),
                TextField(
                  controller: _driverContactCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => controller.updateDraft(
                    (cur) => cur.copyWith(driverContact: v.trim()),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              CivicFieldLabel(
                text: strings.pick("Driver's License Number", "Driver's License Number"),
              ),
              TextField(
                controller: _driverLicenseNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(driverLicenseNo: v.trim().toUpperCase()),
                ),
                decoration: const InputDecoration(hintText: 'e.g. D02-14-098231'),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('Authorized Tricycle DL Codes', 'Awtorisadong DL Codes'),
              ),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: kAllowedDlCodes
                      .map((code) => ButtonSegment(value: code, label: Text(code)))
                      .toList(),
                  selected: {
                    kAllowedDlCodes.contains(d.driverDlCodes)
                        ? d.driverDlCodes
                        : 'A, A1',
                  },
                  onSelectionChanged: (sel) => controller.updateDraft(
                    (cur) => cur.copyWith(driverDlCodes: sel.first),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick("Driver's License Expiry Date", 'Pag-expire ng Lisensya'),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pickDate(
                  d.driverLicenseExpiryDate,
                  (iso) => controller.updateDraft(
                    (cur) => cur.copyWith(driverLicenseExpiryDate: iso),
                  ),
                  allowFuture: true,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined, color: palette.muted),
                  ),
                  child: Text(
                    d.driverLicenseExpiryDate.isNotEmpty
                        ? d.driverLicenseExpiryDate
                        : strings.pick('Select expiry date', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(
                      fontSize: 13,
                      color: d.driverLicenseExpiryDate.isNotEmpty
                          ? palette.ink
                          : palette.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('Barangay Clearance No. (Optional)', 'Barangay Clearance No. (Opsyonal)'),
              ),
              TextField(
                controller: _brgyClearanceNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(brgyClearanceNo: v.trim().toUpperCase()),
                ),
                decoration: const InputDecoration(hintText: 'e.g. BC-2026-019'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 4: Review & Cedula (CTC) — RA 10173 Privacy Compliant
  // ---------------------------------------------------------------------------
  Widget _buildStep4Cedula(
    BuildContext context,
    FranchiseWizardState wizard,
    FranchiseWizardController controller,
    DocumentCaptureService captureService,
    AppStrings strings,
  ) {
    final palette = context.civic;
    final d = wizard.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DocumentScannerCard(
          key: const Key('scanner_card_cedula'),
          title: strings.pick(
            'Community Tax Certificate (Cedula)',
            'Community Tax Certificate (Cedula)',
          ),
          subtitle: strings.pick(
            'Auto-fills CTC Serial No., date, and place issued.',
            'Auto-fill ng CTC Serial No., petsa, at lugar.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: wizard.attachments['cedulaDoc'],
          existingUrl: d.existingCedulaUrl,
          isScanning: wizard.scanningDocKey == 'cedulaDoc',
          ocrFeedback: wizard.ocrFeedback['cedulaDoc'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'cedulaDoc',
            ocrDocType: 'cedula',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('cedulaDoc'),
        ),
        const SizedBox(height: 14),

        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Cedula Details', 'Detalye ng Cedula'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(
                text: strings.pick('Cedula Serial / CTC Number', 'Cedula Serial / CTC Number'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_cedula_serial_field'),
                controller: _cedulaSerialCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(cedulaSerialNo: v.trim().toUpperCase()),
                ),
                decoration: const InputDecoration(
                  hintText: 'e.g. CC12026-0928174',
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('Date Issued (Current Year)', 'Petsa ng Pag-isyu'),
                isRequired: true,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _pickDate(
                  d.cedulaDate,
                  (iso) => controller.updateDraft(
                    (cur) => cur.copyWith(
                      cedulaDate: iso,
                      cedulaYear: iso.length >= 4 ? iso.substring(0, 4) : cur.cedulaYear,
                    ),
                  ),
                  allowFuture: false,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: palette.muted),
                  ),
                  child: Text(
                    d.cedulaDate.isNotEmpty
                        ? d.cedulaDate
                        : strings.pick('Select Cedula date issued', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(fontSize: 13, color: palette.ink),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('Place Issued / Residence Address', 'Lugar ng Pag-isyu / Tirahan'),
                isRequired: true,
              ),
              TextField(
                key: const Key('wizard_cedula_address_field'),
                controller: _cedulaAddressCtrl,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(cedulaAddress: v),
                ),
                decoration: const InputDecoration(
                  hintText: 'Gasan, Marinduque',
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('Profession / Occupation (Optional)', 'Hanapbuhay (Opsyonal)'),
              ),
              TextField(
                controller: _cedulaProfessionCtrl,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(cedulaProfession: v),
                ),
                decoration: const InputDecoration(
                  hintText: 'Tricycle Operator / Driver',
                ),
              ),
              const SizedBox(height: 12),

              CivicFieldLabel(
                text: strings.pick('TIN (Optional)', 'TIN (Opsyonal)'),
              ),
              TextField(
                controller: _cedulaTinCtrl,
                onChanged: (v) => controller.updateDraft(
                  (cur) => cur.copyWith(cedulaTin: v.trim()),
                ),
                decoration: const InputDecoration(hintText: 'e.g. 432-819-021-000'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 5: Summary & Submit (Civic Ledger Review + RA 10173 Affirmation)
  // ---------------------------------------------------------------------------
  Widget _buildStep5SummarySubmit(
    BuildContext context,
    FranchiseWizardState wizard,
    AppStrings strings,
    num franchiseFee,
  ) {
    final palette = context.civic;
    final d = wizard.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Application Summary', 'Buod ng Aplikasyon'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 12),
              _SummaryRow(label: strings.fullNameLabel, value: d.fullName),
              _SummaryRow(label: 'Barangay / Zone', value: '${d.barangay} (${d.zone})'),
              _SummaryRow(label: 'TODA', value: d.todaName),
              if (d.bodyNumber.isNotEmpty)
                _SummaryRow(label: 'Body #', value: '#${d.bodyNumber}', mono: true),
              _SummaryRow(label: strings.plateNumberLabel, value: d.plateNo, mono: true),
              _SummaryRow(label: 'Make / Year', value: '${d.make} (${d.made})'),
              _SummaryRow(label: strings.motorNumberLabel, value: d.motorNo, mono: true),
              _SummaryRow(label: strings.chassisNumberLabel, value: d.chassisNo, mono: true),
              _SummaryRow(
                label: strings.pick('Driver', 'Driver'),
                value: d.isOperatorDriver ? d.fullName : d.driverName,
              ),
              if (d.driverLicenseNo.isNotEmpty)
                _SummaryRow(label: 'License #', value: '${d.driverLicenseNo} (${d.driverDlCodes})', mono: true),
              _SummaryRow(label: 'Cedula #', value: '${d.cedulaSerialNo} • ${d.cedulaDate}', mono: true),
              _SummaryRow(
                label: strings.franchiseFeeLabel,
                value: ManilaDateFormatter.formatPhp(franchiseFee),
                mono: true,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Documents', 'Mga Dokumento'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 10),
              _DocChecklistRow(
                label: 'LTO OR / CR',
                attached: wizard.hasAnyOrCrDoc,
                rejected: wizard.hasRejectedAttachmentOnStep(1),
                strings: strings,
              ),
              _DocChecklistRow(
                label: "Driver's License",
                attached: wizard.hasLicenseDoc,
                rejected: wizard.isDocRejected('license'),
                strings: strings,
              ),
              _DocChecklistRow(
                label: 'Barangay Clearance',
                attached: wizard.hasBrgyClearanceDoc,
                rejected: wizard.isDocRejected('brgyClearance'),
                strings: strings,
              ),
              _DocChecklistRow(
                label: 'Community Tax Certificate (Cedula)',
                attached: wizard.hasCedulaDoc,
                rejected: wizard.isDocRejected('cedulaDoc'),
                strings: strings,
                optional: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        CivicCard(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: CheckboxListTile(
            key: const Key('wizard_privacy_checkbox'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _privacyConfirmed,
            onChanged: (val) => setState(() => _privacyConfirmed = val == true),
            title: Text(
              strings.pick(
                'I affirm that all information and scanned documents are true and accurate, and consent to OVM — LLSA I verification under RA 10173 (Data Privacy Act).',
                'Pinatutunayan ko na tama ang lahat ng impormasyon at dokumento, at pumapayag akong suriin ito ng OVM — LLSA I alinsunod sa RA 10173.',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.ink,
                    height: 1.4,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UniqueStatusIcon extends StatelessWidget {
  const _UniqueStatusIcon({
    required this.isChecking,
    required this.result,
    required this.onVerify,
  });

  final bool isChecking;
  final UniqueFieldCheckResult? result;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    if (isChecking) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (result != null) {
      return Icon(
        result!.isUnique
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded,
        color: result!.isUnique
            ? CivicColors.civicGreen
            : CivicColors.crimsonAlert,
      );
    }
    return IconButton(
      tooltip: 'Check uniqueness',
      onPressed: onVerify,
      icon: const Icon(Icons.verified_outlined, size: 19),
    );
  }
}

class _UniqueCheckCaption extends StatelessWidget {
  const _UniqueCheckCaption({required this.result});

  final UniqueFieldCheckResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        result!.isUnique
            ? 'Available — no duplicate unit found'
            : (result!.message.isNotEmpty
                ? result!.message
                : 'Already registered to another active unit.'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: result!.isUnique
                  ? CivicColors.civicGreen
                  : CivicColors.crimsonAlert,
            ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool mono;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: mono
                  ? CivicTheme.monoStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    )
                  : Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocChecklistRow extends StatelessWidget {
  const _DocChecklistRow({
    required this.label,
    required this.attached,
    required this.strings,
    this.rejected = false,
    this.optional = false,
  });

  final String label;
  final bool attached;
  final AppStrings strings;
  final bool rejected;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final String badgeLabel;
    final CivicStatusTone badgeTone;
    if (rejected) {
      badgeLabel = strings.pick('Wrong Document', 'Mali');
      badgeTone = CivicStatusTone.danger;
    } else if (attached) {
      badgeLabel = strings.pick('Ready', 'Handa');
      badgeTone = CivicStatusTone.active;
    } else if (optional) {
      badgeLabel = strings.pick('Optional', 'Opsyonal');
      badgeTone = CivicStatusTone.neutral;
    } else {
      badgeLabel = strings.pick('Missing', 'Kulang');
      badgeTone = CivicStatusTone.danger;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
          CivicStatusBadge(
            label: badgeLabel,
            tone: badgeTone,
          ),
        ],
      ),
    );
  }
}
