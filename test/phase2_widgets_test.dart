import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/violation_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/features/garage/views/garage_dashboard_tab.dart';
import 'package:gtrams_mobile/features/garage/widgets/violations_history_sheet.dart';
import 'package:gtrams_mobile/features/garage/widgets/voluntary_cancellation_sheet.dart';
import 'package:gtrams_mobile/features/garage/widgets/withdraw_application_sheet.dart';
import 'package:gtrams_mobile/features/wallet/views/mtop_ecopy_receipt_sheet.dart';
import 'package:gtrams_mobile/features/wallet/widgets/digital_operator_id_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubFranchiseRepo extends FranchiseRepository {
  _StubFranchiseRepo(this.units)
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  final List<FranchiseRecord> units;

  @override
  Future<List<FranchiseRecord>> fetchMyFranchises() async => units;
}

class _StubSettingsRepo extends SettingsRepository {
  _StubSettingsRepo()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<PortalSettings> fetchSettingsOrThrow() async => const PortalSettings(
        maxUnitsPerOperator: 2,
        franchiseFee: 500,
        renewalReminderDays: 60,
      );
}

const _sampleUser = MobileUser(
  id: 'user-op-42',
  name: 'Juan Dela Cruz',
  role: 'operator',
  contact: '09222222222',
  todaAssociation: 'POB TODA',
  bodyNumber: '015',
  emergencyContact: '09178889999',
);

final _activeUnit = FranchiseRecord(
  id: 'fr-active-1',
  operatorId: 'user-op-42',
  fullName: 'Juan Dela Cruz',
  address: 'Barangay I (Poblacion), Gasan, Marinduque',
  zone: 'Central',
  make: 'Kawasaki',
  made: '2024',
  motorNo: 'MTR-001122',
  chassisNo: 'CHS-334455',
  plateNo: 'GTR-1001',
  todaName: 'POB TODA',
  mtopNo: '2026-0186',
  bodyNumber: '015',
  status: 'Active',
  daysRemaining: 210,
  approvalDate: DateTime.utc(2026, 1, 10),
  expiryDate: DateTime.utc(2029, 1, 10),
  occupiesFleetSlot: true,
  paymentStatus: 'Paid',
  officialReceiptNo: 'OR-2026-77120',
  amountPaid: 500,
  paymentMethod: 'Cash',
  paymentDate: DateTime.utc(2026, 1, 9),
  cashierName: 'Municipal Cashier',
);

final _pendingUnit = FranchiseRecord(
  id: 'fr-pending-2',
  operatorId: 'user-op-42',
  fullName: 'Juan Dela Cruz',
  zone: 'Central',
  make: 'Honda',
  made: '2025',
  motorNo: 'MTR-778899',
  chassisNo: 'CHS-667788',
  plateNo: 'GTR-2002',
  todaName: 'POB TODA',
  bodyNumber: '016',
  status: 'For Payment',
  occupiesFleetSlot: true,
  paymentStatus: 'Unpaid',
  dateApplied: DateTime.utc(2026, 11, 20),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'GarageDashboardTab renders quota bar, 5-stage stepper, filter tabs, and handles Extra Large dark mode with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({
      'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
      'gtrams_lang': 'fil',
    });
    final prefs = await SharedPreferences.getInstance();
    final cache = InMemoryOfflineWalletCache();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          offlineWalletCacheProvider.overrideWithValue(cache),
          franchiseRepositoryProvider
              .overrideWithValue(_StubFranchiseRepo([_activeUnit, _pendingUnit])),
          settingsRepositoryProvider.overrideWithValue(_StubSettingsRepo()),
          garageControllerProvider.overrideWith(
            (ref) => GarageController(
              franchiseRepository: _StubFranchiseRepo([_activeUnit, _pendingUnit]),
              settingsRepository: _StubSettingsRepo(),
              walletCache: cache,
              user: _sampleUser,
            ),
          ),
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
            body: GarageDashboardTab(
              user: _sampleUser,
              onNavigateToApply: ({unit, actionLabel}) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Digital ID button is moved exclusively to Settings (NOT on Dashboard)
    expect(find.byKey(const Key('hero_digital_id_button')), findsNothing);
    expect(find.byIcon(Icons.badge_outlined), findsNothing);

    // Unit Quota Bar shows 2 / 2
    expect(find.byKey(const Key('unit_quota_ratio_text')), findsOneWidget);
    expect(find.textContaining('2 / 2'), findsOneWidget);

    final mainScrollable = find.descendant(
      of: find.byKey(const Key('garage_dashboard_list')),
      matching: find.byType(Scrollable),
    ).first;

    await tester.scrollUntilVisible(
      find.text('GTR-1001'),
      250,
      scrollable: mainScrollable,
    );
    expect(find.text('GTR-1001'), findsOneWidget);

    // Scroll back up to filter bar and filter to In-Progress -> shows For Payment unit + 2/5 pipeline
    await tester.scrollUntilVisible(
      find.byKey(const Key('garage_filter_inProgress')),
      -250,
      scrollable: mainScrollable,
    );
    await tester.tap(find.byKey(const Key('garage_filter_inProgress')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('GTR-2002'),
      250,
      scrollable: mainScrollable,
    );
    expect(find.text('GTR-1001'), findsNothing);
    expect(find.text('GTR-2002'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets(
      'GarageDashboardTab unifies Fleet Quota & Quick-Apply card when a slot is open and hides Digital ID',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cache = InMemoryOfflineWalletCache();
    var applyTapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          offlineWalletCacheProvider.overrideWithValue(cache),
          franchiseRepositoryProvider
              .overrideWithValue(_StubFranchiseRepo([_activeUnit])),
          settingsRepositoryProvider.overrideWithValue(_StubSettingsRepo()),
          garageControllerProvider.overrideWith(
            (ref) => GarageController(
              franchiseRepository: _StubFranchiseRepo([_activeUnit]),
              settingsRepository: _StubSettingsRepo(),
              walletCache: cache,
              user: _sampleUser,
            ),
          ),
        ],
        child: MaterialApp(
          theme: CivicTheme.light(),
          home: Scaffold(
            body: GarageDashboardTab(
              user: _sampleUser,
              onNavigateToApply: ({unit, actionLabel}) {
                applyTapped = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hero_digital_id_button')), findsNothing);
    expect(find.text('Franchise Slot Available'), findsNothing);
    expect(find.byKey(const Key('unit_quota_ratio_text')), findsOneWidget);
    expect(find.textContaining('1 / 2'), findsOneWidget);
    expect(find.byKey(const Key('fleet_quick_apply_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('fleet_quick_apply_button')));
    await tester.pumpAndSettle();
    expect(applyTapped, isTrue);
  });

  testWidgets('DigitalOperatorIdCard flips in 3D from front seal/info to back verification QR',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CivicTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DigitalOperatorIdCard(
              user: _sampleUser,
              strings: const AppStrings('en'),
              lastSyncedAt: DateTime.utc(2026, 11, 23, 14, 30),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Front face
    expect(find.text('DIGITAL OPERATOR ID'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('POB TODA'), findsOneWidget);
    expect(find.text('OFFICIAL LGU VERIFICATION QR'), findsNothing);

    // Flip to back face
    await tester.tap(find.byKey(const Key('digital_id_flip_button')));
    await tester.pumpAndSettle();

    expect(find.text('OFFICIAL LGU VERIFICATION QR'), findsOneWidget);
    expect(
      find.text('https://g-trams-official.vercel.app/verify/user-op-42'),
      findsOneWidget,
    );
    expect(find.text('09178889999'), findsOneWidget);
  });

  testWidgets('MtopECopyReceiptSheet switches between watermarked MTOP E-Copy and Payment E-Receipt (OR#)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CivicTheme.light(),
        home: Scaffold(
          body: MtopECopyReceiptSheet(
            unit: _activeUnit,
            user: _sampleUser,
            strings: const AppStrings('en'),
            lastSyncedAt: DateTime.utc(2026, 11, 23, 14, 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('2026-0186'), findsOneWidget);
    expect(find.text('HON. LIDANY A. LAO-BALDO'), findsOneWidget);

    // Switch to Payment E-Receipt tab
    await tester.tap(find.text('Payment E-Receipt'));
    await tester.pumpAndSettle();

    expect(find.text('OR-2026-77120'), findsOneWidget);
    expect(find.text('PHP 500.00'), findsOneWidget);
  });

  testWidgets('ViolationsHistorySheet renders 3-tier ladder, suspended banner, and citations',
      (WidgetTester tester) async {
    final mockResponse = ViolationHistoryResponse(
      franchiseId: 'fr-active-1',
      plateNo: 'GTR-1001',
      franchiseStatus: 'Suspended',
      activeViolationsCount: 2,
      totalViolationsCount: 2,
      suspensionEndDate: DateTime.utc(2026, 12, 5),
      history: const [
        ViolationRecord(
          id: 'v-1',
          violationType: 'No Uniform / ID Displayed',
          offenseNumber: 2,
          status: 'Active',
          sanction: ViolationSanction(
            type: 'Suspension',
            resultingStatus: 'Suspended',
            fineAmount: 500,
            suspensionDays: 15,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CivicTheme.light(),
        home: Scaffold(
          body: ViolationsHistorySheet(
            unit: _activeUnit,
            strings: const AppStrings('en'),
            onFetchHistory: () async => mockResponse,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Franchise Suspended (2nd Offense)'), findsOneWidget);
    expect(find.text('3-TIER PROGRESSIVE SANCTIONS'), findsOneWidget);
    expect(find.text('No Uniform / ID Displayed'), findsOneWidget);
    expect(find.text('FINE: PHP 500.00'), findsOneWidget);
  });

  testWidgets('WithdrawApplicationSheet validates custom reason and submits selected reason',
      (WidgetTester tester) async {
    String? capturedReason;

    await tester.pumpWidget(
      MaterialApp(
        theme: CivicTheme.light(),
        home: Scaffold(
          body: WithdrawApplicationSheet(
            unit: _pendingUnit,
            strings: const AppStrings('en'),
            onSubmit: (reason) async {
              capturedReason = reason;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Other reason (Please specify below)'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('withdraw_confirm_button')));
    await tester.tap(find.byKey(const Key('withdraw_confirm_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Please enter your specific reason for withdrawing this application.'),
      findsOneWidget,
    );
    expect(capturedReason, isNull);

    await tester.enterText(
      find.byKey(const Key('withdraw_custom_reason_field')),
      'Updating engine serial number first',
    );
    await tester.ensureVisible(find.byKey(const Key('withdraw_confirm_button')));
    await tester.tap(find.byKey(const Key('withdraw_confirm_button')));
    await tester.pumpAndSettle();

    expect(capturedReason, 'Updating engine serial number first');
  });

  testWidgets('VoluntaryCancellationSheet pre-fills Hon. Lidany A. Lao-Baldo letter and submits cleanly',
      (WidgetTester tester) async {
    VoluntaryCancellationPayload? submitted;

    await tester.pumpWidget(
      MaterialApp(
        theme: CivicTheme.light(),
        home: Scaffold(
          body: VoluntaryCancellationSheet(
            unit: _activeUnit,
            strings: const AppStrings('en'),
            onSubmit: (payload) async {
              submitted = payload;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Auto-generated template addressed to Hon. Lidany A. Lao-Baldo
    final letterField = tester.widget<TextField>(
      find.byKey(const Key('voluntary_letter_text_field')),
    );
    expect(letterField.controller?.text, contains('Hon. Lidany A. Lao-Baldo'));
    expect(letterField.controller?.text, contains('GTR-1001'));

    // Submit directly with valid template
    final submitBtn = find.byKey(const Key('voluntary_submit_button'));
    final sheetScrollable = find.descendant(
      of: find.byKey(const Key('voluntary_cancel_list')),
      matching: find.byType(Scrollable),
    ).first;
    await tester.scrollUntilVisible(
      submitBtn,
      200,
      scrollable: sheetScrollable,
    );
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted!.reason, 'Relocation / TODA Transfer');
    expect(submitted!.letterText, contains('Hon. Lidany A. Lao-Baldo'));
  });
}
