import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/violation_models.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';

class _FakeFranchiseRepository extends FranchiseRepository {
  _FakeFranchiseRepository({
    this.franchisesResult,
    this.shouldFail = false,
  }) : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  List<FranchiseRecord>? franchisesResult;
  bool shouldFail;

  @override
  Future<List<FranchiseRecord>> fetchMyFranchises() async {
    if (shouldFail) {
      throw const ApiException(message: 'No internet connection.');
    }
    return franchisesResult ?? const [];
  }
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository({
    this.settings = const PortalSettings(
      maxUnitsPerOperator: 2,
      franchiseFee: 500,
      renewalReminderDays: 60,
    ),
    this.shouldFail = false,
  }) : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  PortalSettings settings;
  bool shouldFail;

  @override
  Future<PortalSettings> fetchSettingsOrThrow() async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/settings'),
        type: DioExceptionType.connectionError,
      );
    }
    return settings;
  }
}

void main() {
  group('FranchiseRecord models, 5-stage pipeline & Manila validity', () {
    test('parses complete franchise JSON and preserves roundtrip fields', () {
      final raw = <String, dynamic>{
        '_id': 'fr-001',
        'operator': {'_id': 'op-100', 'name': 'Juan Dela Cruz'},
        'fullName': 'Juan Dela Cruz',
        'address': 'Barangay I (Poblacion), Gasan, Marinduque',
        'zone': 'Zone 1',
        'make': 'Kawasaki',
        'made': '2024',
        'motorNo': 'MTR-9981',
        'chassisNo': 'CHS-5512',
        'plateNo': 'ABC-1234',
        'todaName': 'POB TODA',
        'mtopNo': '2026-0186',
        'bodyNumber': '012',
        'status': 'Active',
        'applicationType': 'New',
        'daysRemaining': 45,
        'expiryDate': '2027-01-07T15:59:59.000Z',
        'occupiesFleetSlot': true,
        'paymentStatus': 'Paid',
        'officialReceiptNo': 'OR-2026-88412',
        'amountPaid': 500,
        'paymentMethod': 'Cash',
        'cashierName': 'Maria Santos',
        'paymentHistory': [
          {
            'officialReceiptNo': 'OR-2023-10221',
            'amountPaid': 500,
            'mtopNo': '2023-0044',
            'applicationType': 'New',
            'previousStatus': 'Expired',
          },
        ],
      };

      final parsed = FranchiseRecord.fromJson(raw);
      expect(parsed.id, 'fr-001');
      expect(parsed.operatorId, 'op-100');
      expect(parsed.formattedZone, 'Central');
      expect(parsed.displayMtopNo, '2026-0186');
      expect(parsed.pipelineStage, LguPipelineStage.active);
      expect(parsed.filterCategory, GarageFilter.active);
      expect(parsed.countsTowardQuota, isTrue);
      expect(parsed.hasApprovedECopy, isTrue);
      expect(parsed.hasOfficialReceipt, isTrue);
      expect(parsed.canRequestVoluntaryCancellation, isTrue);
      expect(parsed.isWithdrawable, isFalse);
      expect(parsed.effectiveDaysRemaining(), 45);
      expect(parsed.isWithinRenewalWindow(60), isTrue);
      expect(parsed.paymentHistory.length, 1);

      final roundtrip = FranchiseRecord.fromJson(parsed.toJson());
      expect(roundtrip.plateNo, 'ABC-1234');
      expect(roundtrip.officialReceiptNo, 'OR-2026-88412');
      expect(roundtrip.paymentHistory.first.officialReceiptNo, 'OR-2023-10221');
    });

    test('maps all 5 LGU pipeline stages in exact payment-before-signing order', () {
      expect(
        const FranchiseRecord(id: '1', fullName: 'A', plateNo: 'P1', status: 'Pending').pipelineStage,
        LguPipelineStage.pending,
      );
      expect(
        const FranchiseRecord(id: '2', fullName: 'A', plateNo: 'P2', status: 'For Payment').pipelineStage,
        LguPipelineStage.forPayment,
      );
      expect(
        const FranchiseRecord(id: '3', fullName: 'A', plateNo: 'P3', status: 'For Signing').pipelineStage,
        LguPipelineStage.forSigning,
      );
      expect(
        const FranchiseRecord(id: '4', fullName: 'A', plateNo: 'P4', status: 'Ready for Pickup').pipelineStage,
        LguPipelineStage.readyForPickup,
      );
      expect(
        const FranchiseRecord(id: '5', fullName: 'A', plateNo: 'P5', status: 'Active').pipelineStage,
        LguPipelineStage.active,
      );
      expect(
        const FranchiseRecord(id: '6', fullName: 'A', plateNo: 'P6', status: 'Revoked').pipelineStage,
        isNull,
      );
    });

    test('computes Asia/Manila calendar days remaining accurately', () {
      // 2026-11-25T00:00:00+08:00 == 2026-11-24T16:00:00Z
      final expiryUtc = DateTime.utc(2026, 11, 24, 16, 0, 0);
      // Now in Manila: 2026-11-23 23:00 PHT
      final nowManila = DateTime.utc(2026, 11, 23, 23, 0, 0);
      expect(
        ManilaDateFormatter.calculateManilaDaysRemaining(
          expiryUtc,
          nowManilaOverride: nowManila,
        ),
        2,
      );
    });

    test('generates official OVM voluntary cancellation letter without BPLO copy', () {
      const unit = FranchiseRecord(
        id: 'fr-9',
        fullName: 'Pedro Reyes',
        plateNo: 'XYZ-7788',
        todaName: 'BATODA',
        mtopNo: '2026-0210',
        status: 'Active',
      );

      final letter = unit.buildVoluntaryCancellationLetter(
        reason: 'Unit Sale / Transfer of Ownership',
        remarks: 'Sold to new operator in Brgy. Bachao Ibaba.',
      );

      expect(letter, contains('Hon. Lidany A. Lao-Baldo'));
      expect(letter, contains('Office of the Vice Mayor (OVM)'));
      expect(letter, contains('LLSA I'));
      expect(letter, contains('Pedro Reyes'));
      expect(letter, contains('XYZ-7788'));
      expect(letter, contains('2026-0210'));
      expect(letter.toUpperCase(), isNot(contains('BPLO')));
      expect(letter.length, greaterThanOrEqualTo(30));
    });

    test('categorizes withdrawable, rejected, and archived units accurately', () {
      const unpaidPending = FranchiseRecord(
        id: '1',
        fullName: 'Op',
        plateNo: 'P1',
        status: 'Pending',
        paymentStatus: 'Unpaid',
      );
      expect(unpaidPending.isWithdrawable, isTrue);
      expect(unpaidPending.filterCategory, GarageFilter.inProgress);

      const paidForPayment = FranchiseRecord(
        id: '2',
        fullName: 'Op',
        plateNo: 'P2',
        status: 'For Payment',
        paymentStatus: 'Paid',
      );
      expect(paidForPayment.isWithdrawable, isFalse);

      const staffRejected = FranchiseRecord(
        id: '3',
        fullName: 'Op',
        plateNo: 'P3',
        status: 'Cancelled',
        cancellationOutcome: 'staff_rejected',
        canFixIssues: true,
        cancelReason: 'Blurry OR/CR scan',
      );
      expect(staffRejected.isRejectedNeedsFix, isTrue);
      expect(staffRejected.filterCategory, GarageFilter.inProgress);

      const voluntary = FranchiseRecord(
        id: '4',
        fullName: 'Op',
        plateNo: 'P4',
        status: 'Cancelled',
        cancellationOutcome: 'voluntary_surrender',
        isArchived: true,
      );
      expect(voluntary.isVoluntarilyCancelled, isTrue);
      expect(voluntary.filterCategory, GarageFilter.pastArchived);
      expect(voluntary.countsTowardQuota, isFalse);
    });
  });

  group('ViolationHistoryResponse & BPLO copy sanitization', () {
    test('parses 3-tier sanctions and sanitizes legacy BPLO staff labels', () {
      final res = ViolationHistoryResponse.fromJson({
        'franchise': {
          '_id': 'fr-1',
          'fullName': 'Juan Dela Cruz',
          'plateNo': 'ABC-1234',
          'todaName': 'POB TODA',
          'status': 'Suspended',
          'suspensionEndDate': '2026-12-10T00:00:00.000Z',
        },
        'activeViolationsCount': 2,
        'totalViolationsCount': 2,
        'nextOffenseNumber': 3,
        'expectedSanction': 'Revocation',
        'expectedStatus': 'Revoked',
        'policy': {
          'tiers': {
            'secondOffense': {
              'defaultFine': 750,
              'defaultSuspensionDays': 20,
            },
          },
        },
        'history': [
          {
            '_id': 'v-2',
            'violationType': 'Out-of-Zone Operation',
            'severity': 'High',
            'offenseNumber': 2,
            'recordedByName': 'BPLO Officer',
            'status': 'Active',
            'sanction': {
              'type': 'Suspension',
              'resultingStatus': 'Suspended',
              'fineAmount': 750,
              'suspensionDays': 20,
            },
          },
        ],
      });

      expect(res.activeViolationsCount, 2);
      expect(res.policy.secondOffenseFine, 750);
      expect(res.policy.secondOffenseSuspensionDays, 20);
      expect(res.history.single.offenseLabel, '2nd Offense');
      expect(res.history.single.recordedByName, 'OVM Franchising Staff (LLSA I)');
      expect(res.history.single.recordedByName.toUpperCase(), isNot(contains('BPLO')));
    });
  });

  group('OfflineWalletCache & GarageController offline resilience', () {
    test('persists per-user snapshots and falls back gracefully when offline', () async {
      final cache = InMemoryOfflineWalletCache();
      const user = MobileUser(
        id: 'op-offline-1',
        name: 'Ian Operator',
        role: 'operator',
        todaAssociation: 'BATODA',
        bodyNumber: '007',
        emergencyContact: '09171234567',
      );
      const cachedUnit = FranchiseRecord(
        id: 'fr-cached-1',
        fullName: 'Ian Operator',
        plateNo: 'MAR-4001',
        mtopNo: '2026-0099',
        todaName: 'BATODA',
        zone: 'South',
        status: 'Active',
        daysRemaining: 120,
        officialReceiptNo: 'OR-99100',
        amountPaid: 500,
        paymentStatus: 'Paid',
      );

      final syncedAt = DateTime.utc(2026, 11, 23, 12, 0, 0);
      await cache.writeSnapshot(
        user.id,
        OfflineWalletSnapshot(
          user: user,
          franchises: const [cachedUnit],
          settings: const PortalSettings(maxUnitsPerOperator: 2, franchiseFee: 500),
          lastSyncedAt: syncedAt,
        ),
      );

      final readBack = cache.readSnapshot(user.id);
      expect(readBack, isNotNull);
      expect(readBack!.franchises.single.plateNo, 'MAR-4001');
      expect(readBack.lastSyncedAt, syncedAt);
      expect(cache.readSnapshot('another-user'), isNull);

      // Boot GarageController while offline -> must preserve cached unit & flag offline fallback
      final controller = GarageController(
        franchiseRepository: _FakeFranchiseRepository(shouldFail: true),
        settingsRepository: _FakeSettingsRepository(shouldFail: true),
        walletCache: cache,
        user: user,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isOfflineFallback, isTrue);
      expect(controller.state.franchises.length, 1);
      expect(controller.state.franchises.first.mtopNo, '2026-0099');
      expect(controller.state.lastSyncedAt, syncedAt);

      await cache.clearUser(user.id);
      expect(cache.readSnapshot(user.id), isNull);

      // Online sync updates live state & writes Hive snapshot
      final onlineController = GarageController(
        franchiseRepository: _FakeFranchiseRepository(
          franchisesResult: const [cachedUnit],
          shouldFail: false,
        ),
        settingsRepository: _FakeSettingsRepository(
          settings: const PortalSettings(
            maxUnitsPerOperator: 3,
            franchiseFee: 600,
          ),
          shouldFail: false,
        ),
        walletCache: cache,
        user: user,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(onlineController.state.isOfflineFallback, isFalse);
      expect(onlineController.state.maxUnits, 3);
      expect(onlineController.state.settings.franchiseFee, 600);
      expect(cache.readSnapshot(user.id)?.franchises.length, 1);
    });
  });
}
