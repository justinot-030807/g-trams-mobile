import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/application/views/apply_renew_wizard_tab.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWizardFranchiseRepo extends FranchiseRepository {
  _FakeWizardFranchiseRepo({
    this.duplicatePlate = false,
    this.ocrData,
    this.units = const [],
  }) : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  final bool duplicatePlate;
  final Map<String, dynamic>? ocrData;
  final List<FranchiseRecord> units;
  final List<String> checkedUniqueFields = [];
  bool submittedNew = false;
  bool submittedRenewal = false;

  @override
  Future<List<FranchiseRecord>> fetchMyFranchises() async => units;

  @override
  Future<UniqueFieldCheckResult> checkUniqueField({
    required String field,
    required String value,
    String? excludeId,
  }) async {
    checkedUniqueFields.add('$field:$value');
    final isDup = duplicatePlate && field == 'plateNo';
    return UniqueFieldCheckResult(
      field: field,
      value: value,
      isUnique: !isDup,
      message: isDup ? 'This Plate Number is already registered to another unit.' : 'Available',
    );
  }

  @override
  Future<TodaJurisdictionCheckResult> checkTodaJurisdiction({
    required String todaName,
    required String barangay,
  }) async {
    return TodaJurisdictionCheckResult(
      todaName: todaName,
      jurisdictionStatus: 'match',
    );
  }

  @override
  Future<OcrScanResult> scanDocument({
    required ScannedDocumentAttachment file,
    required String docType,
  }) async {
    return OcrScanResult.fromJson(
      {
        'success': ocrData != null,
        'docType': docType,
        'data': ocrData ?? const {},
      },
      fallbackDocType: docType,
    );
  }

  @override
  Future<FranchiseRecord> submitNewFranchise({
    required FranchiseWizardDraft draft,
    required Map<String, ScannedDocumentAttachment> attachments,
  }) async {
    submittedNew = true;
    return FranchiseRecord(
      id: 'fr-new-101',
      fullName: draft.fullName,
      plateNo: draft.plateNo,
      todaName: draft.todaName,
      zone: draft.zone,
      status: 'Pending',
    );
  }

  @override
  Future<FranchiseRecord> renewFranchise({
    required String franchiseId,
    required FranchiseWizardDraft draft,
    required Map<String, ScannedDocumentAttachment> attachments,
  }) async {
    submittedRenewal = true;
    return FranchiseRecord(
      id: franchiseId,
      fullName: draft.fullName,
      plateNo: draft.plateNo,
      todaName: draft.todaName,
      zone: draft.zone,
      status: 'Pending',
      applicationType: 'Renewal',
    );
  }
}

class _FakeSettingsRepo extends SettingsRepository {
  _FakeSettingsRepo()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<PortalSettings> fetchSettingsOrThrow() async => const PortalSettings(
        maxUnitsPerOperator: 2,
        franchiseFee: 500,
        renewalReminderDays: 60,
      );
}

const _testUser = MobileUser(
  id: 'op-phase3-1',
  name: 'Juan Dela Cruz',
  role: 'operator',
  contact: '09222222222',
  address: 'Barangay I (Poblacion)',
  todaAssociation: 'POB TODA',
  bodyNumber: '021',
);

final _dummyAttachment = ScannedDocumentAttachment(
  bytes: Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]),
  fileName: 'sample_orcr.jpg',
  mimeType: 'image/jpeg',
  sourceLabel: 'Smart Scanner',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RA 10173 OCR Privacy Sanitizer & Field Normalizers', () {
    test('strips bloodType, payment amounts, body stats, and signatories from OCR JSON', () {
      final result = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'cedula',
          'data': {
            'serialNo': 'CC12026-0928174',
            'dateIssued': '2026-01-18',
            'placeIssued': 'Gasan, Marinduque',
            'bloodType': 'O+',
            'totalAmountPaid': '55.00',
            'basicCommunityTax': '5.00',
            'treasurer': 'MARIA CLARA',
            'signatory': 'HON. SAMPLE',
            'height': '5.6',
            'weight': '62',
          },
        },
        fallbackDocType: 'cedula',
      );

      expect(result.success, isTrue);
      expect(result.data['serialNo'], 'CC12026-0928174');
      expect(result.data.containsKey('bloodType'), isFalse);
      expect(result.data.containsKey('totalAmountPaid'), isFalse);
      expect(result.data.containsKey('basicCommunityTax'), isFalse);
      expect(result.data.containsKey('treasurer'), isFalse);
      expect(result.data.containsKey('signatory'), isFalse);
      expect(result.data.containsKey('height'), isFalse);
      expect(result.data.containsKey('weight'), isFalse);
    });

    test('normalizes Tricycle DL Codes and OCR date formats accurately', () {
      expect(FranchiseWizardDraft.normalizeTricycleDlCodes('A, A1, B'), 'A, A1');
      expect(FranchiseWizardDraft.normalizeTricycleDlCodes('A1'), 'A1');
      expect(FranchiseWizardDraft.normalizeTricycleDlCodes('B, C'), '');

      expect(FranchiseWizardDraft.normalizeOcrDate('03/31/2027'), '2027-03-31');
      expect(FranchiseWizardDraft.normalizeOcrDate('25/11/2026'), '2026-11-25');
      expect(FranchiseWizardDraft.normalizeOcrDate('2026-11-23T08:00:00Z'), '2026-11-23');
    });
  });

  group('FranchiseWizardController — AI OCR Auto-Fill, Unique Checks & Hive Drafts', () {
    test('auto-fills vehicle specs from CR OCR, runs unique checks, saves & clears Hive draft', () async {
      final draftCache = InMemoryWizardDraftCache();
      final repo = _FakeWizardFranchiseRepo(
        ocrData: {
          'plateNo': '4528-tc',
          'engineNo': 'kf51e7890123',
          'chassisNo': 'mh1kf5178pk098231',
          'make': 'HONDA',
          'series': 'TMX 125 ALPHA',
          'yearModel': '2024',
          'expiryDate': '2027-03-31',
        },
      );
      var garageRefreshed = false;

      final ctrl = FranchiseWizardController(
        franchiseRepository: repo,
        draftCache: draftCache,
        user: _testUser,
        onSubmittedRefreshGarage: () async => garageRefreshed = true,
      );

      // Attach & scan CR -> triggers OCR + auto-fill + live unique checks + Hive auto-save
      await ctrl.attachAndScanDocument(
        fieldKey: 'crDocument',
        ocrDocType: 'cr',
        file: _dummyAttachment,
      );

      expect(ctrl.state.draft.plateNo, '4528-TC');
      expect(ctrl.state.draft.motorNo, 'KF51E7890123');
      expect(ctrl.state.draft.chassisNo, 'MH1KF5178PK098231');
      expect(ctrl.state.draft.make, 'HONDA TMX 125 ALPHA');
      expect(ctrl.state.draft.made, '2024');
      expect(ctrl.state.ocrFeedback['crDocument']?.success, isTrue);
      expect(repo.checkedUniqueFields, contains('plateNo:4528-TC'));
      expect(draftCache.readApplyDraft(_testUser.id)?.plateNo, '4528-TC');

      // Attach remaining required docs (NO TODA endorsement!) + valid current-year Cedula
      await ctrl.attachAndScanDocument(
        fieldKey: 'license',
        ocrDocType: 'license',
        file: _dummyAttachment,
      );
      await ctrl.attachAndScanDocument(
        fieldKey: 'brgyClearance',
        ocrDocType: 'brgyClearance',
        file: _dummyAttachment,
      );
      ctrl.updateDraft(
        (d) => d.copyWith(
          cedulaSerialNo: 'CC12026-888999',
          cedulaAddress: 'Barangay I (Poblacion), Gasan, Marinduque',
        ),
      );

      final submitted = await ctrl.submit();
      expect(submitted, isNotNull);
      expect(repo.submittedNew, isTrue);
      expect(garageRefreshed, isTrue);
      expect(draftCache.readApplyDraft(_testUser.id), isNull);
    });

    test('blocks duplicate Plate No, expired Cedula year, and targets flagged Fix & Reapply step', () async {
      final draftCache = InMemoryWizardDraftCache();
      final dupRepo = _FakeWizardFranchiseRepo(duplicatePlate: true);

      final ctrl = FranchiseWizardController(
        franchiseRepository: dupRepo,
        draftCache: draftCache,
        user: _testUser,
      );

      ctrl.updateDraft(
        (d) => d.copyWith(
          plateNo: 'DUP-100',
          make: 'Honda TMX 125',
          made: '2024',
          motorNo: 'MTR-1',
          chassisNo: 'CHS-1',
          cedulaSerialNo: 'CC-OLD',
          cedulaDate: '2024-01-15',
          cedulaAddress: 'Gasan, Marinduque',
        ),
      );
      await ctrl.checkUniqueField('plateNo', 'DUP-100');

      expect(ctrl.state.hasDuplicateConflict, isTrue);
      expect(ctrl.validateApplicationStep(1), contains('already registered'));
      expect(ctrl.validateApplicationStep(3), contains('Expired Cedula (2024)'));

      // Fix & Reapply targets Step 2 (index 1) when rejectedField is motorNo
      const rejectedUnit = FranchiseRecord(
        id: 'fr-rej-1',
        fullName: 'Juan Dela Cruz',
        plateNo: 'REJ-505',
        todaName: 'POB TODA',
        zone: 'Central',
        status: 'Cancelled',
        cancellationOutcome: 'staff_rejected',
        canFixIssues: true,
        rejectedField: 'motorNo',
        cancelReason: 'Motor number mismatch on CR scan',
      );
      ctrl.startFixReapply(rejectedUnit);
      expect(ctrl.state.draft.mode, WizardFlowMode.fixReapply);
      expect(ctrl.state.draft.currentStep, 1);
      expect(ctrl.state.draft.plateNo, 'REJ-505');
    });
  });

  group('ApplyRenewWizardTab Widget & Responsive QA', () {
    testWidgets(
      'renders 5-Step Wizard in Dark Mode at Extra Large (1.26x) on 360px screen with zero overflow and NO TODA Endorsement upload',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final walletCache = InMemoryOfflineWalletCache();
        final draftCache = InMemoryWizardDraftCache();
        final repo = _FakeWizardFranchiseRepo();
        final settingsRepo = _FakeSettingsRepo();

        final wizardCtrl = FranchiseWizardController(
          franchiseRepository: repo,
          draftCache: draftCache,
          user: _testUser,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              offlineWalletCacheProvider.overrideWithValue(walletCache),
              wizardDraftCacheProvider.overrideWithValue(draftCache),
              documentCaptureServiceProvider.overrideWithValue(DocumentCaptureService()),
              garageControllerProvider.overrideWith(
                (ref) => GarageController(
                  franchiseRepository: repo,
                  settingsRepository: settingsRepo,
                  walletCache: walletCache,
                  user: _testUser,
                ),
              ),
              franchiseWizardControllerProvider.overrideWith((ref) => wizardCtrl),
            ],
            child: MaterialApp(
              theme: CivicTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.26),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: ApplyRenewWizardTab(onGoToGarage: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Franchise Application'), findsOneWidget);
        expect(find.text('1/5'), findsOneWidget);

        // Jump to Step 3 (Driver's License & Barangay Clearance) -> verify NO TODA Endorsement upload card
        wizardCtrl.setStep(2);
        await tester.pumpAndSettle();

        expect(find.text('3/5'), findsOneWidget);
        expect(find.byKey(const Key('scanner_card_license')), findsOneWidget);
        expect(find.byKey(const Key('scanner_card_brgy')), findsOneWidget);
        expect(find.text('TODA Endorsement Certificate'), findsNothing);
      },
    );

    testWidgets('Renewal mode validates Cedula and submits PUT /renew cleanly',
        (WidgetTester tester) async {
      final prefs = await SharedPreferences.getInstance();
      final walletCache = InMemoryOfflineWalletCache();
      final draftCache = InMemoryWizardDraftCache();
      const expiredUnit = FranchiseRecord(
        id: 'fr-exp-77',
        fullName: 'Juan Dela Cruz',
        plateNo: 'EXP-777',
        mtopNo: '2023-0102',
        todaName: 'POB TODA',
        zone: 'Central',
        status: 'Expired',
      );
      final repo = _FakeWizardFranchiseRepo(units: const [expiredUnit]);
      final settingsRepo = _FakeSettingsRepo();

      final wizardCtrl = FranchiseWizardController(
        franchiseRepository: repo,
        draftCache: draftCache,
        user: _testUser,
      )..startRenewal(expiredUnit);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            offlineWalletCacheProvider.overrideWithValue(walletCache),
            wizardDraftCacheProvider.overrideWithValue(draftCache),
            garageControllerProvider.overrideWith(
              (ref) => GarageController(
                franchiseRepository: repo,
                settingsRepository: settingsRepo,
                walletCache: walletCache,
                user: _testUser,
              ),
            ),
            franchiseWizardControllerProvider.overrideWith((ref) => wizardCtrl),
          ],
          child: MaterialApp(
            theme: CivicTheme.light(),
            home: Scaffold(
              body: ApplyRenewWizardTab(onGoToGarage: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Renew Tricycle Franchise'), findsOneWidget);
      expect(find.text('EXP-777'), findsOneWidget);

      final mainScrollable = find.descendant(
        of: find.byKey(const Key('apply_wizard_list')),
        matching: find.byType(Scrollable),
      ).first;

      await tester.scrollUntilVisible(
        find.byKey(const Key('renewal_cedula_serial_field')),
        220,
        scrollable: mainScrollable,
      );
      await tester.enterText(
        find.byKey(const Key('renewal_cedula_serial_field')),
        'CC12026-554433',
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('renewal_submit_button')),
        250,
        scrollable: mainScrollable,
      );
      await tester.tap(find.byKey(const Key('renewal_submit_button')));
      await tester.pumpAndSettle();

      expect(repo.submittedRenewal, isTrue);
      expect(find.text('Renewal Application Submitted!'), findsOneWidget);
    });
  });
}
