import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/app.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/services/bounded_file_read.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/biometric_service.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/private_cache_box.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/auth/views/biometric_lock_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _operator = MobileUser(
  id: 'operator-test',
  name: 'Test Operator',
  role: 'operator',
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final FutureOr<ResponseBody> Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

class _UnavailableBiometrics extends BiometricService {
  bool unlockAllowed = false;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String localizedReason}) async =>
      unlockAllowed;
}

ResponseBody _jsonResponse(int code, [Map<String, dynamic> body = const {}]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _testToken(DateTime expiry) {
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'exp': expiry.millisecondsSinceEpoch ~/ 1000})),
  );
  return 'header.$payload.signature';
}

Future<void> _saveOperator(SecureSessionStorage storage, String token) =>
    storage.saveSession(
      token: token,
      role: _operator.role,
      userJson: _operator.toJson(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'valid cached session allows reads and requires profile validation for writes',
    () async {
      final storage = SecureSessionStorage();
      final token = _testToken(DateTime.now().add(const Duration(hours: 1)));
      await _saveOperator(storage, token);
      final dio = Dio();
      var online = false;
      var otpRequests = 0;
      dio.httpClientAdapter = _Adapter((request) {
        if (request.path == '/auth/profile') {
          return online
              ? _jsonResponse(200, _operator.toJson())
              : _jsonResponse(503);
        }
        if (request.path == '/auth/request-recovery-otp') otpRequests++;
        return _jsonResponse(200);
      });
      final api = ApiClient(dio: dio, sessionStorage: storage);
      final repo = AuthRepository(apiClient: api, sessionStorage: storage);

      expect((await repo.restoreSession())?.id, _operator.id);
      expect(await repo.readSessionToken(), isNull);
      await expectLater(
        repo.requestRecoveryOtp('test@example.test'),
        throwsA(isA<ApiException>()),
      );
      expect(otpRequests, 0);

      online = true;
      expect((await repo.fetchProfile()).id, _operator.id);
      expect(await repo.readSessionToken(), token);
      await repo.requestRecoveryOtp('test@example.test');
      expect(otpRequests, 1);
    },
  );

  for (final (label, lifetime, response) in [
    ('expired JWT', const Duration(minutes: -1), 503),
    ('unexpected server error', const Duration(hours: 1), 500),
  ]) {
    test('$label does not allow offline restore', () async {
      final storage = SecureSessionStorage();
      await _saveOperator(storage, _testToken(DateTime.now().add(lifetime)));
      final dio = Dio()
        ..httpClientAdapter = _Adapter((_) => _jsonResponse(response));
      final repo = AuthRepository(
        apiClient: ApiClient(dio: dio, sessionStorage: storage),
        sessionStorage: storage,
      );
      expect(await repo.restoreSession(), isNull);
      expect(repo.offlineSessionExpiresAt, isNull);
    });
  }

  test(
    'late errors and retries are scoped to the originating session',
    () async {
      final storage = SecureSessionStorage();
      await _saveOperator(storage, 'first-test-session');
      final oldRequestStarted = Completer<void>();
      final oldRequestResult = Completer<ResponseBody>();
      final lateRequestStarted = Completer<void>();
      final lateRequestResult = Completer<ResponseBody>();
      final requests = <String?>[];
      final dio = Dio()
        ..httpClientAdapter = _Adapter((request) {
          requests.add(request.headers['Authorization']?.toString());
          switch (request.path) {
            case '/test/retry':
              if (!oldRequestStarted.isCompleted) oldRequestStarted.complete();
              return oldRequestResult.future;
            case '/test/late':
              lateRequestStarted.complete();
              return lateRequestResult.future;
            default:
              return _jsonResponse(401);
          }
        });
      var logoutCount = 0;
      final api = ApiClient(
        dio: dio,
        sessionStorage: storage,
        onUnauthorized: () => logoutCount++,
      );
      final cancelled = throwsA(
        isA<DioException>().having(
          (error) => error.type,
          'type',
          DioExceptionType.cancel,
        ),
      );
      final retryExpectation = expectLater(
        api.dio.get<dynamic>('/test/retry'),
        cancelled,
      );
      final lateExpectation = expectLater(
        api.dio.get<dynamic>('/test/late'),
        cancelled,
      );
      await Future.wait([oldRequestStarted.future, lateRequestStarted.future]);
      oldRequestResult.complete(_jsonResponse(503));
      await Future<void>.delayed(const Duration(milliseconds: 25));

      await storage.clearSession();
      await _saveOperator(storage, 'second-test-session');
      lateRequestResult.complete(_jsonResponse(401));
      await Future.wait([retryExpectation, lateExpectation]);
      expect(requests, [
        'Bearer first-test-session',
        'Bearer first-test-session',
      ]);
      expect(logoutCount, 0);

      await expectLater(
        api.dio.get<dynamic>('/test/current'),
        throwsA(isA<DioException>()),
      );
      expect(requests.last, 'Bearer second-test-session');
      expect(logoutCount, 1);
    },
  );

  test(
    'enabled app lock stays locked when biometric capability is unavailable',
    () async {
      final storage = SecureSessionStorage();
      await _saveOperator(storage, 'saved-session');
      final dio = Dio()
        ..httpClientAdapter = _Adapter(
          (request) => _jsonResponse(
            200,
            request.path == '/auth/profile' ? _operator.toJson() : {},
          ),
        );
      final api = ApiClient(dio: dio, sessionStorage: storage);
      final controller = AuthController(
        authRepository: AuthRepository(apiClient: api, sessionStorage: storage),
        settingsRepository: SettingsRepository(apiClient: api),
        biometricService: _UnavailableBiometrics(),
        walletCache: InMemoryOfflineWalletCache(),
        wizardDraftCache: InMemoryWizardDraftCache(),
      );
      addTearDown(controller.dispose);

      await controller.bootstrap(requireBiometricLock: true);
      expect(controller.state.status, AuthStatus.biometricLocked);
      expect(await controller.unlockWithBiometrics('Unlock'), isFalse);
      expect(controller.state.status, AuthStatus.biometricLocked);

      controller.setAuthenticatedUser(_operator);
      expect(controller.lockOnResume(), isTrue);
      expect(controller.state.status, AuthStatus.biometricLocked);
    },
  );

  test(
    'legacy cache contents migrate and reopen using the encrypted box',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'gtrams-private-cache-test-',
      );
      Hive.init(temp.path);
      addTearDown(() async {
        await Hive.close();
        await temp.delete(recursive: true);
      });
      const legacyName = 'old_wallet_test';
      final legacy = await Hive.openBox<String>(legacyName);
      await legacy.put('record', 'sample private record');
      await legacy.close();

      final migrated = (await PrivateCacheBox.open(legacyName))!;
      expect(migrated.get('record'), 'sample private record');
      expect(await Hive.boxExists(legacyName), isFalse);
      await migrated.close();

      final reopened = (await PrivateCacheBox.open(legacyName))!;
      expect(reopened.get('record'), 'sample private record');
      final diskBytes = await File(reopened.path!).readAsBytes();
      expect(
        latin1.decode(diskBytes),
        isNot(contains('sample private record')),
      );
    },
  );

  test(
    'file size cap is checked before opening a stream and during reading',
    () async {
      var opened = false;
      Stream<List<int>> chunks() async* {
        opened = true;
        yield [1, 2];
        yield [3, 4, 5];
      }

      await expectLater(
        readBoundedFile(size: 5, maxBytes: 4, stream: chunks()),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(opened, isFalse);
      await expectLater(
        readBoundedFile(size: 3, maxBytes: 4, stream: chunks()),
        throwsA(isA<FileTooLargeException>()),
      );
      expect(await readBoundedFile(size: 5, maxBytes: 5, stream: chunks()), [
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );

  testWidgets(
    'resuming locks the app and unlock returns to the existing screen',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Private screen')),
          ),
          GoRoute(
            path: '/biometric-lock',
            builder: (_, _) => const BiometricLockScreen(),
          ),
        ],
      );
      final biometrics = _UnavailableBiometrics();
      final container = ProviderContainer(
        overrides: [
          appRouterProvider.overrideWithValue(router),
          sharedPreferencesProvider.overrideWithValue(prefs),
          biometricServiceProvider.overrideWithValue(biometrics),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(router.dispose);
      container
          .read(authControllerProvider.notifier)
          .setAuthenticatedUser(_operator);
      await container
          .read(appPreferencesProvider.notifier)
          .setBiometricEnabled(true);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const GtramsMobileApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private screen'), findsOneWidget);

      for (final state in [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(find.byType(BiometricLockScreen), findsOneWidget);
      expect(find.text('Private screen'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(BiometricLockScreen), findsOneWidget);

      biometrics.unlockAllowed = true;
      await tester.tap(find.text('Unlock with Biometrics'));
      await tester.pumpAndSettle();
      expect(find.text('Private screen'), findsOneWidget);
      expect(container.read(authControllerProvider).isAuthenticated, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('cached countdown advances at Manila midnight', () {
    final snapshot = OfflineWalletSnapshot.fromJson({
      'lastSyncedAt': '2026-11-23T15:59:00Z',
      'franchises': [
        {
          '_id': 'unit-test',
          'fullName': 'Test Driver',
          'plateNo': 'TEST',
          'status': 'Active',
          'daysRemaining': 1,
        },
      ],
    });
    final unit = snapshot.franchises.single;
    expect(
      unit.effectiveDaysRemaining(
        nowManilaOverride: DateTime.utc(2026, 11, 23),
      ),
      1,
    );
    expect(
      unit.effectiveDaysRemaining(
        nowManilaOverride: DateTime.utc(2026, 11, 24),
      ),
      0,
    );
    expect(
      unit.isEffectivelyExpired(nowManilaOverride: DateTime.utc(2026, 11, 24)),
      isTrue,
    );
    expect(
      const FranchiseRecord(
        id: '',
        fullName: '',
        plateNo: '',
        status: 'Active',
        daysRemaining: 1,
      ).effectiveDaysRemaining(),
      1,
    );
  });
}
