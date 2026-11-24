import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/biometric_service.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/auth/views/account_deactivated_screen.dart';
import 'package:gtrams_mobile/features/auth/views/biometric_lock_screen.dart';
import 'package:gtrams_mobile/features/auth/views/forgot_password_screen.dart';
import 'package:gtrams_mobile/features/auth/views/login_screen.dart';
import 'package:gtrams_mobile/features/auth/views/register_screen.dart';
import 'package:gtrams_mobile/shared/widgets/google_g_logo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _InMemorySessionStorage extends SecureSessionStorage {
  String? token;
  String? role;
  Map<String, dynamic>? userJson;

  @override
  Future<void> saveSession({
    required String token,
    required String role,
    required Map<String, dynamic> userJson,
  }) async {
    this.token = token;
    this.role = role;
    this.userJson = Map<String, dynamic>.from(userJson);
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readRole() async => role;

  @override
  Future<Map<String, dynamic>?> readUserJson() async => userJson;

  @override
  Future<void> clearSession() async {
    token = null;
    role = null;
    userJson = null;
  }
}

typedef _StubHandler = ({int statusCode, Map<String, dynamic> body}) Function(
  RequestOptions options,
  Map<String, dynamic> requestBody,
);

class _StubDioAdapter implements HttpClientAdapter {
  _StubDioAdapter(this.handler);

  final _StubHandler handler;
  final List<({String method, String path, Map<String, dynamic> body})> calls =
      [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> reqBody = const {};
    if (options.data is Map) {
      reqBody = Map<String, dynamic>.from(options.data as Map);
    }
    calls.add((method: options.method, path: options.path, body: reqBody));
    final result = handler(options, reqBody);
    return ResponseBody.fromString(
      jsonEncode(result.body),
      result.statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository()
      : super(apiClient: ApiClient(sessionStorage: _InMemorySessionStorage()));

  @override
  Future<PortalSettings> fetchSettings() async => const PortalSettings();
}

class _FakeBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate({required String localizedReason}) async => false;
}

class _FakeGoogleFlowAuthRepository extends AuthRepository {
  _FakeGoogleFlowAuthRepository({
    this.onSignIn,
    this.onCompleteOnboarding,
  }) : super(
          apiClient: ApiClient(sessionStorage: _InMemorySessionStorage()),
          sessionStorage: _InMemorySessionStorage(),
        );

  final Future<MobileUser> Function()? onSignIn;
  final Future<MobileUser> Function(Map<String, dynamic> payload)?
      onCompleteOnboarding;

  @override
  Future<MobileUser> signInWithGoogle() async {
    if (onSignIn != null) return onSignIn!();
    throw UnimplementedError();
  }

  @override
  Future<RosterVerificationResult> verifyTodaRoster({
    required String fullName,
    required String todaAssociation,
    required String bodyNumber,
  }) async {
    return const RosterVerificationResult(
      verified: true,
      status: 'verified',
      message: 'Verified in official TODA masterlist.',
    );
  }

  @override
  Future<MobileUser> completeGoogleOnboarding({
    required String email,
    required String fullName,
    required String address,
    required String todaAssociation,
    required String bodyNumber,
    String googleId = '',
    String picture = '',
    String onboardingToken = '',
    String idToken = '',
    String accessToken = '',
    String? emergencyContact,
  }) async {
    if (onCompleteOnboarding != null) {
      return onCompleteOnboarding!({
        'email': email,
        'fullName': fullName,
        'address': address,
        'todaAssociation': todaAssociation,
        'bodyNumber': bodyNumber,
        'googleId': googleId,
        'onboardingToken': onboardingToken,
        'idToken': idToken,
        'emergencyContact': emergencyContact,
      });
    }
    return MobileUser(
      id: 'google-op-1',
      name: fullName,
      role: 'operator',
      contact: email,
      email: email,
      address: address,
      todaAssociation: todaAssociation,
      bodyNumber: bodyNumber.toUpperCase(),
      authProvider: 'google',
      hasLocalPassword: false,
    );
  }
}

void main() {
  group('GoogleGLogo widget', () {
    testWidgets('renders 4-color official Google G CustomPaint at exact size',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: GoogleGLogo(size: 20)),
          ),
        ),
      );

      expect(find.byType(GoogleGLogo), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GoogleGLogo),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(GoogleGLogo)), const Size(20, 20));
      expect(GoogleGLogo.googleBlue, const Color(0xFF4285F4));
      expect(GoogleGLogo.googleGreen, const Color(0xFF34A853));
      expect(GoogleGLogo.googleYellow, const Color(0xFFFBBC05));
      expect(GoogleGLogo.googleRed, const Color(0xFFEA4335));
    });
  });

  group('AuthRepository Google Sign-In response parsing & onboarding', () {
    AuthRepository buildRepo({
      required _InMemorySessionStorage storage,
      required _StubDioAdapter adapter,
      GoogleSignInRunner? googleRunner,
    }) {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.gtrams.local/api/v1'))
        ..httpClientAdapter = adapter;
      final apiClient = ApiClient(sessionStorage: storage, dio: dio);
      return AuthRepository(
        apiClient: apiClient,
        sessionStorage: storage,
        isWebOverride: false,
        googleSignInRunner: googleRunner ??
            (clientId) async => const GoogleAuthCredentials(
                  email: 'juan.operator@gmail.com',
                  name: 'Juan Dela Cruz',
                  googleId: 'google-sub-123',
                  picture: 'https://lh3.googleusercontent.com/avatar.png',
                  idToken: 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
                  accessToken: 'ya29.mock-access-token',
                ),
      );
    }

    test('parses backend isNewUser:true + onboardingToken without token error',
        () async {
      final storage = _InMemorySessionStorage();
      String? observedClientId;
      final adapter = _StubDioAdapter((options, body) {
        if (options.path == '/auth/google-client-id') {
          return (
            statusCode: 200,
            body: {
              'clientId': 'server-synced-client-id.apps.googleusercontent.com',
            },
          );
        }
        if (options.path == '/auth/google') {
          return (
            statusCode: 200,
            body: {
              'isNewUser': true,
              'message':
                  'Google account verified. Please complete your registration.',
              'googleProfile': {
                'email': 'juan.operator@gmail.com',
                'googleId': 'google-sub-123',
                'name': 'Juan Dela Cruz',
                'picture': 'https://lh3.googleusercontent.com/avatar.png',
                'onboardingToken': 'signed-onboarding-jwt-xyz',
              },
            },
          );
        }
        return (statusCode: 200, body: const {});
      });

      final repo = buildRepo(
        storage: storage,
        adapter: adapter,
        googleRunner: (clientId) async {
          observedClientId = clientId;
          return const GoogleAuthCredentials(
            email: 'juan.operator@gmail.com',
            name: 'Juan Dela Cruz',
            googleId: 'google-sub-123',
            idToken: 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
          );
        },
      );

      await expectLater(
        repo.signInWithGoogle(),
        throwsA(
          isA<GoogleOnboardingRequiredException>()
              .having((e) => e.email, 'email', 'juan.operator@gmail.com')
              .having((e) => e.name, 'name', 'Juan Dela Cruz')
              .having((e) => e.googleId, 'googleId', 'google-sub-123')
              .having(
                (e) => e.onboardingToken,
                'onboardingToken',
                'signed-onboarding-jwt-xyz',
              )
              .having(
                (e) => e.idToken,
                'idToken',
                'eyJhbGciOiJSUzI1NiJ9.payload.sig',
              ),
        ),
      );
      expect(
        observedClientId,
        'server-synced-client-id.apps.googleusercontent.com',
      );
    });

    test('also handles needsOnboarding and requiresOnboarding payload flags',
        () async {
      for (final flag in ['needsOnboarding', 'requiresOnboarding']) {
        final storage = _InMemorySessionStorage();
        final adapter = _StubDioAdapter((options, body) {
          if (options.path == '/auth/google') {
            return (
              statusCode: 200,
              body: {
                flag: true,
                'googleProfile': {
                  'email': 'new.op@gmail.com',
                  'name': 'Maria Santos',
                  'googleId': 'sub-456',
                  'onboardingToken': 'tok-$flag',
                },
              },
            );
          }
          return (statusCode: 200, body: const {});
        });

        final repo = buildRepo(storage: storage, adapter: adapter);
        await expectLater(
          repo.signInWithGoogle(),
          throwsA(
            isA<GoogleOnboardingRequiredException>().having(
              (e) => e.onboardingToken,
              'onboardingToken',
              'tok-$flag',
            ),
          ),
        );
      }
    });

    test('parses nested data.token and data.user payloads cleanly', () async {
      final storage = _InMemorySessionStorage();
      final adapter = _StubDioAdapter((options, body) {
        if (options.path == '/auth/google-client-id') {
          return (statusCode: 503, body: const {'message': 'waking up'});
        }
        if (options.path == '/auth/google') {
          return (
            statusCode: 200,
            body: {
              'success': true,
              'data': {
                'isNewUser': false,
                'token': 'nested-session-jwt-999',
                'user': {
                  '_id': 'op-nested-1',
                  'name': 'Pedro Reyes',
                  'role': 'operator',
                  'email': 'pedro@gmail.com',
                  'contact': 'pedro@gmail.com',
                  'todaAssociation': 'BATODA',
                  'bodyNumber': '07',
                  'authProvider': 'google',
                  'hasLocalPassword': false,
                },
              },
            },
          );
        }
        return (statusCode: 200, body: const {});
      });

      String? fallbackClientId;
      final repo = buildRepo(
        storage: storage,
        adapter: adapter,
        googleRunner: (clientId) async {
          fallbackClientId = clientId;
          return const GoogleAuthCredentials(
            email: 'pedro@gmail.com',
            idToken: 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
          );
        },
      );

      final user = await repo.signInWithGoogle();
      expect(fallbackClientId, AppConfig.defaultGoogleClientId);
      expect(user.id, 'op-nested-1');
      expect(user.name, 'Pedro Reyes');
      expect(user.todaAssociation, 'BATODA');
      expect(storage.token, 'nested-session-jwt-999');
    });

    test('handles accountDeactivated, pendingApproval, and informative message',
        () async {
      final storage = _InMemorySessionStorage();

      // 1. accountDeactivated in payload
      final deactivatedRepo = buildRepo(
        storage: storage,
        adapter: _StubDioAdapter((options, _) {
          if (options.path == '/auth/google') {
            return (
              statusCode: 200,
              body: {
                'accountDeactivated': true,
                'message': 'Your account has been deactivated.',
                'reason': 'Expired MTOP compliance hold',
                'appealStatus': 'none',
                'contact': 'juan.operator@gmail.com',
              },
            );
          }
          return (statusCode: 200, body: const {});
        }),
      );

      await expectLater(
        deactivatedRepo.signInWithGoogle(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.accountDeactivated, 'accountDeactivated', isTrue)
              .having(
                (e) => e.deactivationReason,
                'deactivationReason',
                'Expired MTOP compliance hold',
              ),
        ),
      );

      // 2. pendingApproval without token surfaces informative status
      final pendingRepo = buildRepo(
        storage: storage,
        adapter: _StubDioAdapter((options, _) {
          if (options.path == '/auth/google') {
            return (
              statusCode: 200,
              body: {
                'pendingApproval': true,
                'message': 'Awaiting TODA roster approval.',
              },
            );
          }
          return (statusCode: 200, body: const {});
        }),
      );

      await expectLater(
        pendingRepo.signInWithGoogle(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Awaiting TODA roster approval.',
          ),
        ),
      );
    });

    test('blocks staff roles from Google login and discards session', () async {
      final storage = _InMemorySessionStorage();
      final adapter = _StubDioAdapter((options, _) {
        if (options.path == '/auth/google') {
          return (
            statusCode: 200,
            body: {
              'isNewUser': false,
              'token': 'staff-jwt-should-be-discarded',
              'role': 'bplo_staff',
              'user': {
                '_id': 'staff-1',
                'name': 'OVM Licensing Officer',
                'role': 'bplo_staff',
              },
            },
          );
        }
        return (statusCode: 200, body: const {});
      });

      final repo = buildRepo(storage: storage, adapter: adapter);
      await expectLater(
        repo.signInWithGoogle(),
        throwsA(
          isA<StaffRoleBlockedException>()
              .having((e) => e.rawRole, 'rawRole', 'bplo_staff'),
        ),
      );
      expect(storage.token, isNull);
    });

    test('completeGoogleOnboarding posts exact backend contract and logs in',
        () async {
      final storage = _InMemorySessionStorage();
      final adapter = _StubDioAdapter((options, body) {
        if (options.path == '/auth/google') {
          return (
            statusCode: 201,
            body: {
              'isNewUser': false,
              'token': 'fresh-google-operator-jwt',
              'role': 'operator',
              'name': 'Juan Dela Cruz',
              'user': {
                '_id': 'new-google-op-1',
                'name': 'Juan Dela Cruz',
                'role': 'operator',
                'email': 'juan.operator@gmail.com',
                'contact': 'juan.operator@gmail.com',
                'address': 'Poblacion (Barangay I)',
                'todaAssociation': 'BATODA',
                'bodyNumber': 'B-12',
                'authProvider': 'google',
                'hasLocalPassword': false,
              },
            },
          );
        }
        return (statusCode: 200, body: const {});
      });

      final repo = buildRepo(storage: storage, adapter: adapter);
      final user = await repo.completeGoogleOnboarding(
        email: 'Juan.Operator@gmail.com',
        fullName: 'Juan Dela Cruz',
        address: 'Poblacion (Barangay I)',
        todaAssociation: 'BATODA',
        bodyNumber: 'b-12',
        googleId: 'google-sub-123',
        picture: 'https://lh3.googleusercontent.com/avatar.png',
        onboardingToken: 'signed-onboarding-jwt-xyz',
        idToken: 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
        emergencyContact: '+639171234567',
      );

      expect(user.id, 'new-google-op-1');
      expect(user.isGoogleOnlyAccount, isTrue);
      expect(storage.token, 'fresh-google-operator-jwt');

      final postCall =
          adapter.calls.firstWhere((c) => c.path == '/auth/google');
      expect(postCall.body['email'], 'juan.operator@gmail.com');
      expect(postCall.body['onboardingToken'], 'signed-onboarding-jwt-xyz');
      expect(postCall.body['idToken'], 'eyJhbGciOiJSUzI1NiJ9.payload.sig');

      final gp = postCall.body['googleProfile'] as Map<String, dynamic>;
      expect(gp['onboardingToken'], 'signed-onboarding-jwt-xyz');
      expect(gp['googleId'], 'google-sub-123');

      final od = postCall.body['onboardingData'] as Map<String, dynamic>;
      expect(od['fullName'], 'Juan Dela Cruz');
      expect(od['address'], 'Poblacion (Barangay I)');
      expect(od['todaAssociation'], 'BATODA');
      expect(od['bodyNumber'], 'B-12');
      expect(od['contact'], 'juan.operator@gmail.com');
      expect(od['emergencyContact'], '09171234567');
      expect(od['role'], 'operator');
    });

    test('maps Android Google Sign-In PlatformException codes clearly', () {
      final err10 = AuthRepository.mapGooglePlatformException(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 10: ',
        ),
      );
      expect(err10.message, contains('Error 10'));
      expect(err10.message, contains('SHA-1'));

      final err7 = AuthRepository.mapGooglePlatformException(
        PlatformException(
          code: 'network_error',
          message: 'com.google.android.gms.common.api.ApiException: 7: ',
        ),
      );
      expect(err7.message.toLowerCase(), contains('network'));

      final err12501 = AuthRepository.mapGooglePlatformException(
        PlatformException(
          code: 'sign_in_canceled',
          message: 'com.google.android.gms.common.api.ApiException: 12501: ',
        ),
      );
      expect(err12501.message.toLowerCase(), contains('cancelled'));

      final err12500 = AuthRepository.mapGooglePlatformException(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 12500: ',
        ),
      );
      expect(err12500.message, contains('12500'));

      final err12502 = AuthRepository.mapGooglePlatformException(
        PlatformException(
          code: 'sign_in_failed',
          message: 'com.google.android.gms.common.api.ApiException: 12502: ',
        ),
      );
      expect(err12502.message.toLowerCase(), contains('in progress'));
    });
  });

  group('Auth screens UI polish, GoogleGLogo & onboarding sheet flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'LoginScreen uses GoogleGLogo, gtrams-logo.png, zero stars/BPLO, and completes Google onboarding sheet',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        Map<String, dynamic>? submittedOnboarding;

        final authRepo = _FakeGoogleFlowAuthRepository(
          onSignIn: () async {
            throw const GoogleOnboardingRequiredException(
              email: 'new.operator@gmail.com',
              name: 'Juan Dela Cruz',
              googleId: 'google-sub-777',
              onboardingToken: 'signed-onboarding-token-777',
              idToken: 'eyJhbGciOiJSUzI1NiJ9.payload.sig',
            );
          },
          onCompleteOnboarding: (payload) async {
            submittedOnboarding = payload;
            return MobileUser(
              id: 'op-onboarded-1',
              name: payload['fullName'] as String,
              role: 'operator',
              email: payload['email'] as String,
              contact: payload['email'] as String,
              address: payload['address'] as String,
              todaAssociation: payload['todaAssociation'] as String,
              bodyNumber: payload['bodyNumber'] as String,
              authProvider: 'google',
              hasLocalPassword: false,
            );
          },
        );

        final authCtrl = AuthController(
          authRepository: authRepo,
          settingsRepository: _FakeSettingsRepository(),
          biometricService: _FakeBiometricService(),
          walletCache: InMemoryOfflineWalletCache(),
          wizardDraftCache: InMemoryWizardDraftCache(),
        );

        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(
              path: '/login',
              builder: (_, _) => const LoginScreen(),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('HOME_REACHED')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(authRepo),
              authControllerProvider.overrideWith((ref) => authCtrl),
            ],
            child: MaterialApp.router(
              theme: CivicTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Official 4-color GoogleGLogo replaces plain red G icon
        expect(find.byType(GoogleGLogo), findsOneWidget);
        expect(find.byIcon(Icons.g_mobiledata_rounded), findsNothing);
        expect(find.byIcon(Icons.auto_awesome), findsNothing);
        expect(find.byIcon(Icons.auto_awesome_outlined), findsNothing);
        expect(find.textContaining('BPLO'), findsNothing);

        // Uses main G-TRAMS logo (not gasan-logo.png)
        final images = tester.widgetList<Image>(find.byType(Image)).toList();
        expect(
          images.any(
            (img) =>
                img.image is AssetImage &&
                (img.image as AssetImage).assetName ==
                    'assets/images/gtrams-logo.png',
          ),
          isTrue,
        );
        expect(
          images.any(
            (img) =>
                img.image is AssetImage &&
                (img.image as AssetImage).assetName ==
                    'assets/images/gasan-logo.png',
          ),
          isFalse,
        );

        // Tap Continue with Google -> opens Complete Google Registration sheet
        final googleBtn = find.byKey(const Key('google_sign_in_button'));
        await tester.ensureVisible(googleBtn);
        await tester.tap(googleBtn);
        await tester.pumpAndSettle();

        expect(find.text('Complete Google Registration'), findsOneWidget);
        expect(find.text('new.operator@gmail.com'), findsOneWidget);

        // Pick Barangay
        await tester.tap(
          find.byKey(const Key('google_onboarding_barangay_picker')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Antipolo').first);
        await tester.pumpAndSettle();

        // Pick TODA
        final todaPicker =
            find.byKey(const Key('google_onboarding_toda_picker'));
        await tester.ensureVisible(todaPicker);
        await tester.tap(todaPicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('BATODA (Bachao TODA)'));
        await tester.pumpAndSettle();

        // Enter Body Number
        final bodyField =
            find.byKey(const Key('google_onboarding_body_field'));
        await tester.ensureVisible(bodyField);
        await tester.enterText(bodyField, '042');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        // Accept Terms & Submit
        final termsCheckbox =
            find.byKey(const Key('google_onboarding_terms_checkbox'));
        await tester.ensureVisible(termsCheckbox);
        await tester.tap(termsCheckbox);
        await tester.pumpAndSettle();

        final submitBtn =
            find.byKey(const Key('google_onboarding_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(submittedOnboarding, isNotNull);
        expect(submittedOnboarding!['email'], 'new.operator@gmail.com');
        expect(
          submittedOnboarding!['onboardingToken'],
          'signed-onboarding-token-777',
        );
        expect(submittedOnboarding!['bodyNumber'], '042');
        expect(find.text('HOME_REACHED'), findsOneWidget);
        expect(authCtrl.state.isAuthenticated, isTrue);
      },
    );

    testWidgets(
      'LoginScreen routes deactivated Google account to AccountDeactivatedScreen with GoogleGLogo',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();
        final authRepo = _FakeGoogleFlowAuthRepository(
          onSignIn: () async {
            throw const ApiException(
              message: 'Your account has been deactivated.',
              statusCode: 403,
              accountDeactivated: true,
              deactivationContact: 'blocked.op@gmail.com',
              deactivationReason: 'Unresolved violation notice',
              hasLocalPassword: false,
              authProvider: 'google',
            );
          },
        );
        final authCtrl = AuthController(
          authRepository: authRepo,
          settingsRepository: _FakeSettingsRepository(),
          biometricService: _FakeBiometricService(),
          walletCache: InMemoryOfflineWalletCache(),
          wizardDraftCache: InMemoryWizardDraftCache(),
        );

        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(
              path: '/account-deactivated',
              builder: (_, state) => AccountDeactivatedScreen(
                args: state.extra as DeactivatedAccountArgs,
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authRepositoryProvider.overrideWithValue(authRepo),
              authControllerProvider.overrideWith((ref) => authCtrl),
            ],
            child: MaterialApp.router(
              theme: CivicTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final googleBtn = find.byKey(const Key('google_sign_in_button'));
        await tester.ensureVisible(googleBtn);
        await tester.tap(googleBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AccountDeactivatedScreen), findsOneWidget);
        expect(find.text('Unresolved violation notice'), findsOneWidget);
        expect(find.text('Verify with Google'), findsOneWidget);
        expect(find.byType(GoogleGLogo), findsOneWidget);
      },
    );

    testWidgets(
      'Register, ForgotPassword, and BiometricLock screens use gtrams-logo.png with zero gasan-logo.png',
      (WidgetTester tester) async {
        final prefs = await SharedPreferences.getInstance();

        for (final screen in const <Widget>[
          RegisterScreen(),
          ForgotPasswordScreen(),
          BiometricLockScreen(),
        ]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                biometricServiceProvider
                    .overrideWithValue(_FakeBiometricService()),
              ],
              child: MaterialApp(
                theme: CivicTheme.light(),
                home: screen,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final images = tester.widgetList<Image>(find.byType(Image)).toList();
          expect(
            images.any(
              (img) =>
                  img.image is AssetImage &&
                  (img.image as AssetImage).assetName ==
                      'assets/images/gtrams-logo.png',
            ),
            isTrue,
            reason: '${screen.runtimeType} must display gtrams-logo.png',
          );
          expect(
            images.any(
              (img) =>
                  img.image is AssetImage &&
                  (img.image as AssetImage).assetName ==
                      'assets/images/gasan-logo.png',
            ),
            isFalse,
            reason: '${screen.runtimeType} must not use gasan-logo.png',
          );
          expect(find.textContaining('BPLO'), findsNothing);
        }
      },
    );
  });
}
