import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/data/repositories/toda_repository.dart';
import 'package:gtrams_mobile/features/toda/view_models/toda_governance_controller.dart';
import 'package:gtrams_mobile/features/toda/views/toda_governance_hub_tab.dart';
import 'package:gtrams_mobile/features/toda/widgets/add_member_sheet.dart';
import 'package:gtrams_mobile/features/toda/widgets/request_removal_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTodaRepository extends TodaRepository {
  _FakeTodaRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  String? lastAddedName;
  String? lastAddedBody;
  String? lastRemovalReason;
  String? lastVerifiedId;
  int uploadedMemberCount = 0;

  @override
  Future<TodaMembersDirectory> fetchMyMembers() async {
    return const TodaMembersDirectory(
      todaName: 'BATODA',
      stats: TodaDirectoryStats(
        totalMembers: 2,
        totalUnits: 2,
        activeUnits: 1,
        pendingUnits: 1,
        expiredUnits: 0,
      ),
      members: [
        TodaMemberProfile(
          id: 'pres-1',
          name: 'Roberto President',
          bodyNumber: '001',
          contact: '09333333333',
          role: 'toda_president',
          isPresident: true,
          isCurrentUser: true,
        ),
        TodaMemberProfile(
          id: 'op-2',
          name: 'Mario Operator',
          bodyNumber: '014',
          plateNo: 'BAT-1414',
          contact: '09175551122',
          role: 'operator',
          units: [
            TodaMemberUnit(
              id: 'u-1',
              plateNo: 'BAT-1414',
              status: 'Active',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<String> fetchNextBodyNumber({String? todaAssociation}) async => '015';

  @override
  Future<String> addIndividualMember({
    required String operatorName,
    String bodyNumber = '',
    String plateNo = '',
    String contact = '',
    String remarks = '',
  }) async {
    lastAddedName = operatorName;
    lastAddedBody = bodyNumber;
    return 'Added $operatorName ($bodyNumber)';
  }

  @override
  Future<RosterScanResult> scanRosterDocument({
    required ScannedDocumentAttachment file,
  }) async {
    return const RosterScanResult(
      success: true,
      todaAssociation: 'BATODA',
      ocrNotes: '2 rows extracted cleanly',
      extractedMembers: [
        ExtractedRosterMember(operatorName: 'Carlos Dizon', bodyNumber: '016'),
        ExtractedRosterMember(operatorName: 'Elena Cruz', bodyNumber: '017', plateNo: 'BAT-1717'),
      ],
    );
  }

  @override
  Future<TodaSubmissionRecord> uploadRosterSubmission({
    required ScannedDocumentAttachment file,
    required List<ExtractedRosterMember> extractedMembers,
    String ocrNotes = '',
  }) async {
    uploadedMemberCount = extractedMembers.length;
    return TodaSubmissionRecord(
      id: 'sub-99',
      fileName: file.fileName,
      status: 'Pending',
      todaAssociation: 'BATODA',
      extractedCount: extractedMembers.length,
    );
  }

  @override
  Future<List<TodaSubmissionRecord>> fetchMySubmissions() async => [
        TodaSubmissionRecord(
          id: 'sub-1',
          fileName: 'BATODA_Roster_2026.pdf',
          status: 'Approved',
          todaAssociation: 'BATODA',
          extractedCount: 18,
          createdAt: DateTime.utc(2026, 2, 10),
        ),
      ];

  @override
  Future<List<TodaRemovalRequestRecord>> fetchRemovalRequests() async => [
        TodaRemovalRequestRecord(
          id: 'rem-1',
          todaName: 'BATODA',
          memberName: 'Old Operator',
          reason: 'No longer operating / Inactive',
          details: 'Stopped plying route since January 2026.',
          status: 'Pending',
          createdAt: DateTime.utc(2026, 11, 20),
        ),
      ];

  @override
  Future<TodaRemovalRequestRecord> submitRemovalRequest({
    required String memberId,
    required String reason,
    required String details,
    String? targetRosterId,
  }) async {
    lastRemovalReason = reason;
    return TodaRemovalRequestRecord(
      id: 'rem-2',
      todaName: 'BATODA',
      memberName: 'Mario Operator',
      reason: reason,
      details: details,
      status: 'Pending',
    );
  }

  @override
  Future<OperatorVerificationResult> verifyOperatorQr(String rawInput) async {
    lastVerifiedId = OperatorVerificationResult.extractVerificationId(rawInput);
    return OperatorVerificationResult(
      name: 'Mario Operator',
      todaAssociation: 'BATODA',
      validityStatus: 'VALID',
      isCurrentlyValid: true,
      contact: '0917***1122',
      franchises: [
        VerifiedFranchiseSummary(
          plateNo: 'BAT-1414',
          make: 'Kawasaki Barako II',
          mtopNo: '2026-0140',
          todaName: 'BATODA',
          status: 'Active',
          isCurrentlyValid: true,
          validityStatus: 'VALID',
          expiryDate: DateTime.utc(2029, 3, 15),
        ),
      ],
    );
  }
}

const _presidentUser = MobileUser(
  id: 'pres-1',
  name: 'Roberto President',
  role: 'toda_president',
  contact: '09333333333',
  todaAssociation: 'BATODA',
  bodyNumber: '001',
);

final _dummyRosterFile = ScannedDocumentAttachment(
  bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
  fileName: 'batoda_2026.pdf',
  mimeType: 'application/pdf',
  sourceLabel: 'Roster File',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4 TODA Models & QR URL Extraction', () {
    test('extracts verification ID from full Vercel QR URL, relative path, or raw plate/MTOP', () {
      expect(
        OperatorVerificationResult.extractVerificationId(
          'https://g-trams-official.vercel.app/verify/66f01234abcd5678ef901234',
        ),
        '66f01234abcd5678ef901234',
      );
      expect(
        OperatorVerificationResult.extractVerificationId('/verify/2026-0186'),
        '2026-0186',
      );
      expect(
        OperatorVerificationResult.extractVerificationId('BAT-1414'),
        'BAT-1414',
      );
    });

    test('TodaGovernanceController handles OCR scan, row edits, OVM upload & QR verify', () async {
      final repo = _FakeTodaRepository();
      final ctrl = TodaGovernanceController(
        repository: repo,
        user: _presidentUser,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(ctrl.state.directory.todaName, 'BATODA');
      expect(ctrl.state.directory.members.length, 2);

      // Search filters by body number
      ctrl.setSearchQuery('014');
      expect(ctrl.state.filteredMembers.single.name, 'Mario Operator');
      ctrl.setSearchQuery('');

      // Scan roster via AI OCR + edit + add manual row + upload to OVM
      await ctrl.scanRosterFile(_dummyRosterFile);
      expect(ctrl.state.rosterMembers.length, 2);
      ctrl.addRosterRow(operatorName: 'Dante Ramos', bodyNumber: '018');
      expect(ctrl.state.rosterMembers.length, 3);
      ctrl.removeRosterRow(0);
      expect(ctrl.state.rosterMembers.length, 2);

      final uploaded = await ctrl.submitRosterToOvm();
      expect(uploaded, isNotNull);
      expect(repo.uploadedMemberCount, 2);
      expect(ctrl.state.selectedRosterFile, isNull);

      // QR verification
      await ctrl.verifyQrPayload('https://g-trams-official.vercel.app/verify/op-2');
      expect(repo.lastVerifiedId, 'op-2');
      expect(ctrl.state.verificationResult?.validityStatus, 'VALID');
      expect(ctrl.state.verificationResult?.franchises.single.mtopNo, '2026-0140');
    });
  });

  group('Phase 4 TODA Hub, Add Member, Removal & QR Verifier Widgets', () {
    testWidgets(
      'TodaGovernanceHubTab renders KPIs, Members, Removals, and QR Verify at Extra Large (1.26x) Dark Mode with zero overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeTodaRepository();
        final ctrl = TodaGovernanceController(
          repository: repo,
          user: _presidentUser,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              documentCaptureServiceProvider
                  .overrideWithValue(DocumentCaptureService()),
              todaGovernanceControllerProvider.overrideWith((ref) => ctrl),
            ],
            child: MaterialApp(
              theme: CivicTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.26),
                ),
                child: child!,
              ),
              home: const Scaffold(
                body: TodaGovernanceHubTab(user: _presidentUser),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('BATODA'), findsOneWidget);
        expect(find.text('TODA PRESIDENT CONSOLE'), findsOneWidget);

        // Switch to QR Verify tab (scroll horizontal pill bar first on 360px 1.26x)
        final qrTab = find.byKey(const Key('toda_section_qrVerifier'));
        await tester.ensureVisible(qrTab);
        await tester.pumpAndSettle();
        await tester.tap(qrTab);
        await tester.pumpAndSettle();

        final mainScroll = find.descendant(
          of: find.byKey(const Key('toda_hub_list')),
          matching: find.byType(Scrollable),
        ).first;

        await tester.scrollUntilVisible(
          find.byKey(const Key('qr_manual_input_field')),
          200,
          scrollable: mainScroll,
        );
        await tester.enterText(
          find.byKey(const Key('qr_manual_input_field')),
          'https://g-trams-official.vercel.app/verify/op-2',
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('qr_verify_now_button')),
          200,
          scrollable: mainScroll,
        );
        await tester.tap(find.byKey(const Key('qr_verify_now_button')));
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('BAT-1414'),
          200,
          scrollable: mainScroll,
        );
        expect(find.text('BAT-1414'), findsOneWidget);
        expect(find.text('MTOP #2026-0140'), findsOneWidget);
      },
    );

    testWidgets('AddTodaMemberSheet auto-populates next Body# and submits cleanly',
        (WidgetTester tester) async {
      String? addedName;
      String? addedBody;

      await tester.pumpWidget(
        MaterialApp(
          theme: CivicTheme.light(),
          home: Scaffold(
            body: AddTodaMemberSheet(
              todaName: 'BATODA',
              strings: const AppStrings('en'),
              onFetchNextBodyNumber: () async => '042',
              onSubmit: ({
                required String operatorName,
                required String bodyNumber,
                required String plateNo,
                required String contact,
                required String remarks,
              }) async {
                addedName = operatorName;
                addedBody = bodyNumber;
                return 'OK';
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bodyField = tester.widget<TextField>(
        find.byKey(const Key('add_member_body_field')),
      );
      expect(bodyField.controller?.text, '042');

      await tester.enterText(
        find.byKey(const Key('add_member_name_field')),
        'Lito Mendoza',
      );
      await tester.ensureVisible(find.byKey(const Key('add_member_submit_button')));
      await tester.tap(find.byKey(const Key('add_member_submit_button')));
      await tester.pumpAndSettle();

      expect(addedName, 'Lito Mendoza');
      expect(addedBody, '042');
    });

    testWidgets('RequestRemovalSheet enforces details and submits official removal reason',
        (WidgetTester tester) async {
      String? submittedReason;
      String? submittedDetails;

      await tester.pumpWidget(
        MaterialApp(
          theme: CivicTheme.light(),
          home: Scaffold(
            body: RequestRemovalSheet(
              member: const TodaMemberProfile(
                id: 'op-2',
                name: 'Mario Operator',
                bodyNumber: '014',
              ),
              todaName: 'BATODA',
              strings: const AppStrings('en'),
              onSubmit: ({
                required String memberId,
                required String reason,
                required String details,
              }) async {
                submittedReason = reason;
                submittedDetails = details;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('removal_submit_button')));
      await tester.tap(find.byKey(const Key('removal_submit_button')));
      await tester.pumpAndSettle();
      expect(submittedReason, isNull);

      await tester.enterText(
        find.byKey(const Key('removal_details_field')),
        'Board resolution #2026-04 approved member transfer.',
      );
      await tester.ensureVisible(find.byKey(const Key('removal_submit_button')));
      await tester.tap(find.byKey(const Key('removal_submit_button')));
      await tester.pumpAndSettle();

      expect(submittedReason, kTodaRemovalReasons.first);
      expect(submittedDetails, contains('Board resolution #2026-04'));
    });
  });
}
