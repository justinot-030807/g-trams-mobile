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
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/application/views/apply_renew_wizard_tab.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWizardFranchiseRepo extends FranchiseRepository {
  _FakeWizardFranchiseRepo({
    this.duplicatePlate = false,
    this.ocrResponsesByDocType = const {},
    this.scanError,
    this.units = const [],
  }) : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  final bool duplicatePlate;
  final Map<String, Map<String, dynamic>> ocrResponsesByDocType;
  final Object? scanError;
  final List<FranchiseRecord> units;
  final List<String> checkedUniqueFields = [];
  final List<String> scannedDocTypes = [];
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
      message: isDup
          ? 'This Plate Number is already registered to another unit.'
          : 'Available',
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
    final canonical = OcrScanResult.canonicalBackendDocType(docType);
    scannedDocTypes.add(canonical);
    if (scanError != null) {
      throw scanError!;
    }
    if (ocrResponsesByDocType.containsKey(canonical)) {
      return OcrScanResult.fromJson(
        ocrResponsesByDocType[canonical]!,
        fallbackDocType: canonical,
      );
    }
    return OcrScanResult.fromJson(
      {
        'success': false,
        'docType': canonical,
        'data': const <String, dynamic>{},
      },
      fallbackDocType: canonical,
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

  group('OCR Strict Wrong-Document & DocType Validation', () {
    test('canonicalizes cr/or/orcr variants to backend-expected orCr', () {
      expect(OcrScanResult.canonicalBackendDocType('cr'), 'orCr');
      expect(OcrScanResult.canonicalBackendDocType('or'), 'orCr');
      expect(OcrScanResult.canonicalBackendDocType('orcr'), 'orCr');
      expect(OcrScanResult.canonicalBackendDocType('crDocument'), 'orCr');
      expect(OcrScanResult.canonicalBackendDocType('orDocument'), 'orCr');
      expect(OcrScanResult.canonicalBackendDocType('license'), 'license');
      expect(OcrScanResult.canonicalBackendDocType('licenseBack'), 'licenseBack');
      expect(OcrScanResult.canonicalBackendDocType('brgyClearance'), 'brgyClearance');
      expect(OcrScanResult.canonicalBackendDocType('cedulaDoc'), 'cedula');
    });

    test('rejects wrong documents flagged by backend OR with 0 key fields extracted', () {
      // Case 1: Backend explicit mismatch flags inside data
      final flagged = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'orCr',
          'data': {
            'isValidDocument': false,
            'isExpectedDocumentType': false,
            'detectedDocumentType': 'Non-document or Invalid Image (Selfie/Photo/Blank/Unrelated)',
            'message': 'Hindi ito valid na opisyal na LTO CR/OR document.',
          },
        },
        fallbackDocType: 'orCr',
      );
      expect(flagged.success, isFalse);
      expect(flagged.isValidDocument, isFalse);
      expect(flagged.isWrongDocument, isTrue);
      expect(flagged.isServiceUnavailable, isFalse);
      expect(flagged.detectedDocumentType, contains('Selfie'));

      // Case 2: Exact franchiseController.js rejection shape (success: false + needsManual: true + rejection message)
      final controllerRejected = OcrScanResult.fromJson(
        {
          'success': false,
          'docType': 'orCr',
          'needsManual': true,
          'message': 'Hindi ito valid na opisyal na LTO CR/OR document. Mangyaring mag-upload ng lehitimong kopya.',
        },
        fallbackDocType: 'orCr',
      );
      expect(controllerRejected.success, isFalse);
      expect(controllerRejected.isWrongDocument, isTrue);
      expect(controllerRejected.isServiceUnavailable, isFalse);

      // Case 3: Backend returns success: true with 0 key fields (hallucinated non-document JSON)
      final zeroFields = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'orCr',
          'data': {
            'description': 'A random photo of a motorcycle on the street',
            'color': 'RED',
          },
        },
        fallbackDocType: 'orCr',
      );
      expect(zeroFields.extractedFieldCount, 0);
      expect(zeroFields.success, isFalse);
      expect(zeroFields.isWrongDocument, isTrue);

      // Case 4: OR/CR data uploaded into Driver's License slot -> 0 license fields
      final wrongSlot = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'license',
          'data': {
            'plateNo': '4528-TC',
            'motorNo': 'KF51E7890123',
          },
        },
        fallbackDocType: 'license',
      );
      expect(wrongSlot.extractedFieldCount, 0);
      expect(wrongSlot.success, isFalse);
      expect(wrongSlot.isWrongDocument, isTrue);

      // Case 5: Low confidence or mismatch / verified:false flag
      final lowConf = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'cedula',
          'verified': false,
          'confidence': 0.22,
          'data': {'serialNo': 'CC-123'},
        },
        fallbackDocType: 'cedula',
      );
      expect(lowConf.success, isFalse);
      expect(lowConf.isWrongDocument, isTrue);

      // Case 6: licenseBack passes when backend explicitly confirms valid back card, rejects empty/unverified
      final validBack = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'licenseBack',
          'data': {
            'isValidDocument': true,
            'isExpectedDocumentType': true,
            'detectedDocumentType': "Driver's License (Back)",
            'conditions': 'None',
          },
        },
        fallbackDocType: 'licenseBack',
      );
      expect(validBack.success, isTrue);
      expect(validBack.isWrongDocument, isFalse);

      final invalidBack = OcrScanResult.fromJson(
        {
          'success': true,
          'docType': 'licenseBack',
          'data': <String, dynamic>{},
        },
        fallbackDocType: 'licenseBack',
      );
      expect(invalidBack.success, isFalse);
      expect(invalidBack.isWrongDocument, isTrue);

      // Case 7: OCR service temporarily unavailable -> amber manual fallback, NOT wrong-document rejection
      final serviceDown = OcrScanResult.fromJson(
        {
          'success': false,
          'docType': 'orCr',
          'message': 'AI document scanning service is temporarily unavailable. You can enter details manually.',
        },
        fallbackDocType: 'orCr',
      );
      expect(serviceDown.success, isFalse);
      expect(serviceDown.isServiceUnavailable, isTrue);
      expect(serviceDown.isWrongDocument, isFalse);
    });
  });

  group('FranchiseWizardController — AI OCR Auto-Fill, Unique Checks & Hive Drafts', () {
    test('auto-fills vehicle specs from CR OCR, runs unique checks, saves & clears Hive draft', () async {
      final draftCache = InMemoryWizardDraftCache();
      final repo = _FakeWizardFranchiseRepo(
        ocrResponsesByDocType: {
          'orCr': {
            'success': true,
            'docType': 'orCr',
            'data': {
              'isValidDocument': true,
              'isExpectedDocumentType': true,
              'plateNo': '4528-tc',
              'engineNo': 'kf51e7890123',
              'chassisNo': 'mh1kf5178pk098231',
              'make': 'HONDA',
              'series': 'TMX 125 ALPHA',
              'yearModel': '2024',
              'expiryDate': '2027-03-31',
            },
          },
          'license': {
            'success': true,
            'docType': 'license',
            'data': {
              'isValidDocument': true,
              'isExpectedDocumentType': true,
              'licenseNo': 'D02-14-098231',
              'driverName': 'DELA CRUZ, JUAN M.',
              'dlCodes': 'A, A1',
              'expiryDate': '2028-08-15',
            },
          },
          'brgyClearance': {
            'success': true,
            'docType': 'brgyClearance',
            'data': {
              'isValidDocument': true,
              'isExpectedDocumentType': true,
              'clearanceNo': 'BC-2026-POB-019',
              'residentName': 'JUAN DELA CRUZ',
              'barangay': 'Barangay I (Poblacion)',
              'dateIssued': '2026-04-10',
            },
          },
        },
      );
      var garageRefreshed = false;

      final ctrl = FranchiseWizardController(
        franchiseRepository: repo,
        draftCache: draftCache,
        user: _testUser,
        onSubmittedRefreshGarage: () async => garageRefreshed = true,
      );

      // Attach & scan CR -> canonicalizes 'cr' to 'orCr', auto-fills + runs unique checks + Hive auto-save
      await ctrl.attachAndScanDocument(
        fieldKey: 'crDocument',
        ocrDocType: 'cr',
        file: _dummyAttachment,
      );

      expect(repo.scannedDocTypes, contains('orCr'));
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

    test('blocks step progression on wrong document (mismatch OR 0 extracted fields) and distinguishes 503 OCR outage', () async {
      final draftCache = InMemoryWizardDraftCache();
      final wrongDocRepo = _FakeWizardFranchiseRepo(
        ocrResponsesByDocType: {
          'orCr': {
            'success': false,
            'docType': 'orCr',
            'needsManual': true,
            'message': 'Hindi ito valid na opisyal na LTO CR/OR document. Mangyaring mag-upload ng lehitimong kopya.',
          },
          'license': {
            'success': true,
            'docType': 'license',
            'data': {'randomNote': 'cat photo'}, // 0 key license fields!
          },
        },
      );

      final ctrl = FranchiseWizardController(
        franchiseRepository: wrongDocRepo,
        draftCache: draftCache,
        user: _testUser,
      );
      ctrl.updateDraft(
        (d) => d.copyWith(
          plateNo: '4528-TC',
          make: 'Honda TMX 125',
          made: '2024',
          motorNo: 'MTR-99',
          chassisNo: 'CHS-99',
        ),
      );

      // Upload wrong doc to CR -> MUST reject in danger state and NOT satisfy hasAnyOrCrDoc
      await ctrl.attachAndScanDocument(
        fieldKey: 'crDocument',
        ocrDocType: 'orCr',
        file: _dummyAttachment,
      );
      expect(ctrl.state.ocrFeedback['crDocument']?.isRejected, isTrue);
      expect(ctrl.state.ocrFeedback['crDocument']?.success, isFalse);
      expect(ctrl.state.hasAnyOrCrDoc, isFalse);
      expect(ctrl.validateApplicationStep(1), contains('rejected'));

      // Upload 0-field image to Driver's License -> MUST reject and NOT satisfy hasLicenseDoc
      await ctrl.attachAndScanDocument(
        fieldKey: 'license',
        ocrDocType: 'license',
        file: _dummyAttachment,
      );
      expect(ctrl.state.ocrFeedback['license']?.isRejected, isTrue);
      expect(ctrl.state.hasLicenseDoc, isFalse);
      expect(ctrl.validateApplicationStep(2), contains('rejected'));

      // Now test 503 OCR service outage -> amber manual fallback keeps file usable
      final outageRepo = _FakeWizardFranchiseRepo(
        scanError: const ApiException(
          statusCode: 503,
          message: 'OCR service temporarily offline',
        ),
      );
      final outageCtrl = FranchiseWizardController(
        franchiseRepository: outageRepo,
        draftCache: draftCache,
        user: _testUser,
      );
      await outageCtrl.attachAndScanDocument(
        fieldKey: 'crDocument',
        ocrDocType: 'orCr',
        file: _dummyAttachment,
      );
      expect(outageCtrl.state.ocrFeedback['crDocument']?.isServiceUnavailable, isTrue);
      expect(outageCtrl.state.ocrFeedback['crDocument']?.isRejected, isFalse);
      expect(outageCtrl.state.ocrFeedback['crDocument']?.success, isFalse);
      expect(outageCtrl.state.hasAnyOrCrDoc, isTrue);
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

    testWidgets(
      'wrong document (mismatch flag OR 0 extracted fields) displays red danger banner, never green Scanned, and zero sparkle icons',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        final walletCache = InMemoryOfflineWalletCache();
        final draftCache = InMemoryWizardDraftCache();
        final repo = _FakeWizardFranchiseRepo(
          ocrResponsesByDocType: {
            'orCr': {
              'success': true,
              'docType': 'orCr',
              'data': {
                'isValidDocument': false,
                'isExpectedDocumentType': false,
                'detectedDocumentType': 'Selfie / Unrelated Photo',
              },
            },
            'license': {
              'success': true,
              'docType': 'license',
              'data': {
                'description': 'random blank image with zero license fields',
              },
            },
          },
        );
        final settingsRepo = _FakeSettingsRepo();

        final wizardCtrl = FranchiseWizardController(
          franchiseRepository: repo,
          draftCache: draftCache,
          user: _testUser,
        )..setStep(1);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              offlineWalletCacheProvider.overrideWithValue(walletCache),
              wizardDraftCacheProvider.overrideWithValue(draftCache),
              documentCaptureServiceProvider
                  .overrideWithValue(DocumentCaptureService()),
              garageControllerProvider.overrideWith(
                (ref) => GarageController(
                  franchiseRepository: repo,
                  settingsRepository: settingsRepo,
                  walletCache: walletCache,
                  user: _testUser,
                ),
              ),
              franchiseWizardControllerProvider
                  .overrideWith((ref) => wizardCtrl),
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

        // 1. Mismatch flag on LTO CR -> red danger banner, never green Scanned!
        await wizardCtrl.attachAndScanDocument(
          fieldKey: 'crDocument',
          ocrDocType: 'orCr',
          file: _dummyAttachment,
        );
        await tester.pumpAndSettle();

        final rejectedBannerFinder =
            find.byKey(const Key('ocr_feedback_rejected'));
        expect(rejectedBannerFinder, findsOneWidget);
        final bannerWidget = tester.widget<CivicBanner>(rejectedBannerFinder);
        expect(bannerWidget.tone, CivicStatusTone.danger);
        expect(find.byKey(const Key('ocr_feedback_verified')), findsNothing);
        expect(find.text('WRONG DOCUMENT'), findsOneWidget);
        expect(find.text('SCANNED'), findsNothing);

        // 2. Zero extracted fields on Driver's License (even when backend returns success:true) -> red danger banner!
        wizardCtrl.setStep(2);
        await tester.pumpAndSettle();
        await wizardCtrl.attachAndScanDocument(
          fieldKey: 'license',
          ocrDocType: 'license',
          file: _dummyAttachment,
        );
        await tester.pumpAndSettle();

        final licenseRejectedFinder =
            find.byKey(const Key('ocr_feedback_rejected'));
        expect(licenseRejectedFinder, findsOneWidget);
        expect(
          tester.widget<CivicBanner>(licenseRejectedFinder).tone,
          CivicStatusTone.danger,
        );
        expect(find.byKey(const Key('ocr_feedback_verified')), findsNothing);
        expect(find.text('WRONG DOCUMENT'), findsOneWidget);

        // Zero star / sparkle AI icons anywhere on the screen
        expect(find.byIcon(Icons.auto_awesome), findsNothing);
        expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
        expect(find.byIcon(Icons.star), findsNothing);
        expect(find.byIcon(Icons.star_outline), findsNothing);
      },
    );
  });
}
