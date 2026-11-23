import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/network/socket_service.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/biometric_service.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/data/repositories/communication_repository.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/data/repositories/toda_repository.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';
import 'package:gtrams_mobile/features/auth/views/login_screen.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/features/shell/views/mobile_shell_screen.dart';
import 'package:gtrams_mobile/features/toda/view_models/toda_governance_controller.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _uatOperator = MobileUser(
  id: 'uat-op-1',
  name: 'Juan Dela Cruz',
  role: 'operator',
  contact: '09222222222',
  email: 'operator.tester@gtrams.com',
  address: 'Brgy. Poblacion, Gasan, Marinduque',
  todaAssociation: 'BATODA',
  bodyNumber: '12',
  hasLocalPassword: true,
);

const _uatPresident = MobileUser(
  id: 'uat-pres-1',
  name: 'Roberto Mendoza',
  role: 'toda_president',
  contact: '09333333333',
  email: 'todapres.tester@gtrams.com',
  address: 'Brgy. Bachao Ibaba, Gasan, Marinduque',
  todaAssociation: 'BATODA',
  bodyNumber: '01',
  hasLocalPassword: true,
);

class _UatSocketClient implements RealtimeSocketClient {
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;
  final connectionCtrl =
      StreamController<RealtimeConnectionStatus>.broadcast();
  final chatMessageCtrl = StreamController<ChatMessageItem>.broadcast();
  final chatTypingCtrl = StreamController<ChatTypingEvent>.broadcast();
  final chatReadCtrl = StreamController<String>.broadcast();
  final notificationCtrl = StreamController<AppNotificationItem>.broadcast();
  final notificationSyncCtrl =
      StreamController<NotificationSyncEvent>.broadcast();
  final sessionRevokedCtrl = StreamController<String>.broadcast();

  @override
  RealtimeConnectionStatus get status => _status;
  @override
  Stream<RealtimeConnectionStatus> get connectionStream =>
      connectionCtrl.stream;
  @override
  Stream<ChatMessageItem> get chatMessageStream => chatMessageCtrl.stream;
  @override
  Stream<ChatTypingEvent> get chatTypingStream => chatTypingCtrl.stream;
  @override
  Stream<String> get chatReadStream => chatReadCtrl.stream;
  @override
  Stream<AppNotificationItem> get notificationStream => notificationCtrl.stream;
  @override
  Stream<NotificationSyncEvent> get notificationSyncStream =>
      notificationSyncCtrl.stream;
  @override
  Stream<String> get sessionRevokedStream => sessionRevokedCtrl.stream;

  @override
  void connect(String token) {
    _status = RealtimeConnectionStatus.connected;
    if (!connectionCtrl.isClosed) connectionCtrl.add(_status);
  }

  @override
  void disconnect() {
    _status = RealtimeConnectionStatus.disconnected;
    if (!connectionCtrl.isClosed) connectionCtrl.add(_status);
  }

  @override
  void emitTyping({required String threadId, required String recipientId}) {}

  @override
  void dispose() {
    connectionCtrl.close();
    chatMessageCtrl.close();
    chatTypingCtrl.close();
    chatReadCtrl.close();
    notificationCtrl.close();
    notificationSyncCtrl.close();
    sessionRevokedCtrl.close();
  }
}

class _UatAuthRepository extends AuthRepository {
  _UatAuthRepository({this.blockedRoleOnLogin})
      : super(
          apiClient: ApiClient(sessionStorage: SecureSessionStorage()),
          sessionStorage: SecureSessionStorage(),
        );

  final String? blockedRoleOnLogin;

  @override
  Future<MobileUser> login({
    required String contact,
    required String password,
  }) async {
    if (blockedRoleOnLogin != null) {
      throw StaffRoleBlockedException(
        rawRole: blockedRoleOnLogin!,
        displayRole: GasanConstants.blockedRoleDisplayName(blockedRoleOnLogin),
      );
    }
    return _uatOperator;
  }

  @override
  Future<void> logout() async {}

  @override
  Future<String?> readSessionToken() async => 'uat-jwt-token';
}

class _UatSettingsRepository extends SettingsRepository {
  _UatSettingsRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  static const _mockSettings = PortalSettings(
    maxUnitsPerOperator: 2,
    announcements: [
      PortalAnnouncement(
        title: '2026 Annual MTOP Renewal Open',
        desc: 'Visit OVM — LLSA I or submit directly in G-TRAMS Mobile.',
        type: 'info',
        date: '2026 Cycle',
      ),
    ],
  );

  @override
  Future<PortalSettings> fetchSettings() async => _mockSettings;

  @override
  Future<PortalSettings> fetchSettingsOrThrow() async => _mockSettings;
}

class _UatFranchiseRepository extends FranchiseRepository {
  _UatFranchiseRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<List<FranchiseRecord>> fetchMyFranchises() async => [
        FranchiseRecord(
          id: 'uat-fr-1',
          fullName: 'Juan Dela Cruz',
          plateNo: 'BAT-2026',
          mtopNo: '2026-0186',
          bodyNumber: '12',
          todaName: 'BATODA',
          zone: 'Central',
          make: 'Honda',
          made: 'TMX 125',
          status: 'Active',
          daysRemaining: 120,
          officialReceiptNo: 'OR-2026-8812',
          amountPaid: 500,
          approvalDate: DateTime.utc(2026, 3, 1),
          expiryDate: DateTime.utc(2027, 3, 1),
          orCrUrl: 'https://cdn.example/orcr.jpg',
        ),
      ];
}

class _UatTodaRepository extends TodaRepository {
  _UatTodaRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<TodaMembersDirectory> fetchMyMembers() async =>
      const TodaMembersDirectory(
        todaName: 'BATODA',
        stats: TodaDirectoryStats(
          totalMembers: 14,
          totalUnits: 16,
          activeUnits: 13,
          pendingUnits: 2,
          expiredUnits: 1,
        ),
        members: [
          TodaMemberProfile(
            id: 'mem-1',
            name: 'Juan Dela Cruz',
            bodyNumber: '12',
            contact: '09222222222',
            units: [
              TodaMemberUnit(
                id: 'uat-fr-1',
                plateNo: 'BAT-2026',
                make: 'Honda',
                made: 'TMX 125',
                zone: 'Central',
                status: 'Active',
              ),
            ],
          ),
        ],
      );

  @override
  Future<List<TodaSubmissionRecord>> fetchMySubmissions() async => const [];

  @override
  Future<List<TodaRemovalRequestRecord>> fetchRemovalRequests() async =>
      const [];
}

class _UatCommunicationRepository extends CommunicationRepository {
  _UatCommunicationRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<List<ChatThreadItem>> fetchThreads() async => const [
        ChatThreadItem(
          id: 'uat-chat-1',
          isAnnouncement: false,
          lastMessage: 'Welcome to OVM — LLSA I Support.',
          unreadCount: 1,
        ),
      ];

  @override
  Future<List<ChatMessageItem>> fetchMessages(
    String threadId, {
    String? before,
    int limit = 50,
  }) async =>
      [
        ChatMessageItem(
          id: 'uat-msg-1',
          threadId: threadId,
          sender: const ChatSender(
            id: 'staff-1',
            name: 'OVM Staff',
            role: 'bplo_staff',
          ),
          senderRole: 'bplo_staff',
          message: 'Magandang araw! Ready to assist.',
          createdAt: DateTime.utc(2026, 11, 20, 2, 0),
        ),
      ];

  @override
  Future<void> markThreadRead(String threadId) async {}

  @override
  Future<List<AppNotificationItem>> fetchNotifications() async => [
        AppNotificationItem(
          id: 'uat-notif-1',
          type: 'approval',
          title: 'Franchise Approved',
          message: 'Unit BAT-2026 is now Active.',
          relatedPlateNo: 'BAT-2026',
          isRead: false,
          createdAt: DateTime.utc(2026, 11, 20, 2, 30),
        ),
      ];
}

class _UatBiometricService extends BiometricService {
  @override
  Future<bool> isAvailable() async => false;
}

AuthController _buildAuthenticatedAuthController({
  required MobileUser user,
  _UatAuthRepository? authRepo,
}) {
  final ctrl = AuthController(
    authRepository: authRepo ?? _UatAuthRepository(),
    settingsRepository: _UatSettingsRepository(),
    biometricService: _UatBiometricService(),
    walletCache: InMemoryOfflineWalletCache(),
    wizardDraftCache: InMemoryWizardDraftCache(),
  );
  ctrl.setAuthenticatedUser(user);
  return ctrl;
}

void main() {
  group('Phase 6 — Full E2E UAT QA & Release Hardening Suite', () {
    testWidgets(
      'E2E UAT #1: Staff Role Guard blocks OVM/LLSA I (bplo_staff), Cashier & System Admin with zero legacy BPLO copy',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        for (final entry in [
          ('bplo_staff', 'OVM / LLSA I Licensing Officer'),
          ('cashier', 'Municipal Cashier / Treasury'),
          ('system_admin', 'System Administrator'),
        ]) {
          final authRepo = _UatAuthRepository(blockedRoleOnLogin: entry.$1);
          final authCtrl = AuthController(
            authRepository: authRepo,
            settingsRepository: _UatSettingsRepository(),
            biometricService: _UatBiometricService(),
            walletCache: InMemoryOfflineWalletCache(),
            wizardDraftCache: InMemoryWizardDraftCache(),
          );

          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('role_guard_${entry.$1}'),
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                authRepositoryProvider.overrideWithValue(authRepo),
                authControllerProvider.overrideWith((ref) => authCtrl),
              ],
              child: MaterialApp(
                theme: CivicTheme.light(),
                home: const LoginScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final fields = find.byType(TextFormField);
          await tester.enterText(fields.at(0), 'staff.tester@gtrams.com');
          await tester.enterText(fields.at(1), 'Password123!');

          final signInBtn = find.byType(ElevatedButton).first;
          await tester.ensureVisible(signInBtn);
          await tester.tap(signInBtn);
          await tester.pumpAndSettle();

          expect(find.textContaining(entry.$2), findsOneWidget);
          expect(find.textContaining('BPLO'), findsNothing);
          expect(authCtrl.state.isAuthenticated, isFalse);

          // Dismiss dialog for next role iteration
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
        }
      },
    );

    testWidgets(
      'E2E UAT #2: Operator 4-tab Shell Journey (Garage, Bell -> Alerts, Wallet, EN/FIL, Apply, Settings) at 1.26x Dark Mode 360px',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final socket = _UatSocketClient();
        final authCtrl = _buildAuthenticatedAuthController(user: _uatOperator);
        final garageCtrl = GarageController(
          franchiseRepository: _UatFranchiseRepository(),
          settingsRepository: _UatSettingsRepository(),
          walletCache: InMemoryOfflineWalletCache(),
          user: _uatOperator,
        );
        final updatesCtrl = UpdatesController(
          repository: _UatCommunicationRepository(),
          settingsRepository: _UatSettingsRepository(),
          socketClient: socket,
          currentUserId: _uatOperator.id,
          readToken: () async => 'uat-jwt-token',
          onSessionRevoked: (_) {},
          autoInit: false,
        );
        await updatesCtrl.initialize();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => authCtrl),
              garageControllerProvider.overrideWith((ref) => garageCtrl),
              updatesControllerProvider.overrideWith((ref) => updatesCtrl),
              franchiseWizardControllerProvider.overrideWith(
                (ref) => FranchiseWizardController(
                  franchiseRepository: _UatFranchiseRepository(),
                  draftCache: InMemoryWizardDraftCache(),
                  user: _uatOperator,
                ),
              ),
              offlineWalletCacheProvider
                  .overrideWithValue(InMemoryOfflineWalletCache()),
              wizardDraftCacheProvider
                  .overrideWithValue(InMemoryWizardDraftCache()),
              documentCaptureServiceProvider
                  .overrideWithValue(DocumentCaptureService()),
            ],
            child: MaterialApp(
              theme: CivicTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.26),
                ),
                child: child!,
              ),
              home: const MobileShellScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Operator gets 4 tabs (Home, Apply, Updates, Settings) — NO TODA tab
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(find.text('REGISTERED OPERATOR'), findsOneWidget);

        // Tap AppBar Notification Bell -> opens Updates -> Alerts
        await tester.tap(find.byKey(const Key('appbar_notifications_button')));
        await tester.pumpAndSettle();
        expect(find.text('Franchise Approved'), findsOneWidget);

        // Toggle EN -> FIL live
        await tester.tap(find.text('EN'));
        await tester.pumpAndSettle();
        expect(find.text('FIL'), findsOneWidget);

        // Switch to Settings tab
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Juan Dela Cruz'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        socket.dispose();
      },
    );

    testWidgets(
      'E2E UAT #3: TODA President 5-tab Shell Journey renders all 5 tabs & TODA Hub on 360px with zero overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final socket = _UatSocketClient();
        final authCtrl = _buildAuthenticatedAuthController(user: _uatPresident);
        final garageCtrl = GarageController(
          franchiseRepository: _UatFranchiseRepository(),
          settingsRepository: _UatSettingsRepository(),
          walletCache: InMemoryOfflineWalletCache(),
          user: _uatPresident,
        );
        final todaCtrl = TodaGovernanceController(
          repository: _UatTodaRepository(),
          user: _uatPresident,
        );
        final updatesCtrl = UpdatesController(
          repository: _UatCommunicationRepository(),
          settingsRepository: _UatSettingsRepository(),
          socketClient: socket,
          currentUserId: _uatPresident.id,
          readToken: () async => 'uat-jwt-token',
          onSessionRevoked: (_) {},
          autoInit: false,
        );
        await updatesCtrl.initialize();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => authCtrl),
              garageControllerProvider.overrideWith((ref) => garageCtrl),
              todaGovernanceControllerProvider.overrideWith((ref) => todaCtrl),
              updatesControllerProvider.overrideWith((ref) => updatesCtrl),
              documentCaptureServiceProvider
                  .overrideWithValue(DocumentCaptureService()),
            ],
            child: MaterialApp(
              theme: CivicTheme.light(),
              home: const MobileShellScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // TODA President gets 5 tabs (Home, TODA, Apply, Updates, Settings)
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        expect(find.text('TODA PRESIDENT'), findsOneWidget);

        // Tap TODA destination in NavigationBar -> opens TodaGovernanceHubTab
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.byIcon(Icons.groups_outlined),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('BATODA'), findsOneWidget);
        expect(find.text('TODA PRESIDENT CONSOLE'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        socket.dispose();
      },
    );

    testWidgets(
      'E2E UAT #4: Live Socket.IO session_revoked redirects /home -> /login with security banner',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final socket = _UatSocketClient();
        final authCtrl = _buildAuthenticatedAuthController(user: _uatOperator);
        final garageCtrl = GarageController(
          franchiseRepository: _UatFranchiseRepository(),
          settingsRepository: _UatSettingsRepository(),
          walletCache: InMemoryOfflineWalletCache(),
          user: _uatOperator,
        );
        final updatesCtrl = UpdatesController(
          repository: _UatCommunicationRepository(),
          settingsRepository: _UatSettingsRepository(),
          socketClient: socket,
          currentUserId: _uatOperator.id,
          readToken: () async => 'uat-jwt-token',
          onSessionRevoked: (reason) => authCtrl.forceLogout(reason: reason),
          autoInit: false,
        );
        await updatesCtrl.initialize();

        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => const MobileShellScreen(),
            ),
            GoRoute(
              path: '/login',
              builder: (_, _) => const LoginScreen(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authControllerProvider.overrideWith((ref) => authCtrl),
              garageControllerProvider.overrideWith((ref) => garageCtrl),
              updatesControllerProvider.overrideWith((ref) => updatesCtrl),
            ],
            child: MaterialApp.router(
              theme: CivicTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MobileShellScreen), findsOneWidget);

        // Emit live Socket.IO session_revoked event
        socket.sessionRevokedCtrl.add(
          'Password changed on another device. Please sign in again.',
        );
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.text('Session Signed Out'), findsOneWidget);
        expect(
          find.text('Password changed on another device. Please sign in again.'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        socket.dispose();
      },
    );

    test(
      'E2E UAT #5: Production Android Release Signing, R8 ProGuard, Manifest Security & API Invariants',
      () {
        // Production API & Web Portal endpoints
        expect(AppConfig.apiOrigin, 'https://g-trams-web2.onrender.com');
        expect(AppConfig.apiOrigin.startsWith('https://'), isTrue);
        expect(AppConfig.apiOrigin.contains('workers.dev'), isFalse);
        expect(AppConfig.webPortalUrl, 'https://g-trams-official.vercel.app');

        // Android Gradle release signing & R8 shrinking config
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();
        expect(gradle.contains('ph.gov.gasan.gtrams.gtrams_mobile'), isTrue);
        expect(gradle.contains('minSdk = maxOf(flutter.minSdkVersion, 24)'), isTrue);
        expect(gradle.contains('key.properties'), isTrue);
        expect(gradle.contains('isMinifyEnabled = true'), isTrue);
        expect(gradle.contains('isShrinkResources = true'), isTrue);
        expect(gradle.contains('proguard-rules.pro'), isTrue);

        // ProGuard keep rules for ML Kit, CameraX/Mobile Scanner & Secure Storage
        final proguard = File('android/app/proguard-rules.pro').readAsStringSync();
        expect(proguard.contains('com.google.mlkit'), isTrue);
        expect(proguard.contains('dev.steenbakker.mobile_scanner'), isTrue);
        expect(proguard.contains('com.google.crypto.tink'), isTrue);

        // Release Manifest security hardening
        final mainManifest =
            File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
        expect(mainManifest.contains('android:usesCleartextTraffic="false"'), isTrue);
        expect(mainManifest.contains('android:allowBackup="false"'), isTrue);
        expect(mainManifest.contains('android.permission.CAMERA'), isTrue);
        expect(mainManifest.contains('android.permission.USE_BIOMETRIC'), isTrue);

        // Debug Manifest permits local dev HTTP only
        final debugManifest =
            File('android/app/src/debug/AndroidManifest.xml').readAsStringSync();
        expect(debugManifest.contains('android:usesCleartextTraffic="true"'), isTrue);

        // Gitignore prevents keystore secret leaks
        final gitignore = File('.gitignore').readAsStringSync();
        expect(gitignore.contains('/android/key.properties'), isTrue);
        expect(gitignore.contains('*.jks'), isTrue);
        expect(gitignore.contains('*.keystore'), isTrue);

        // GitHub Actions release pipeline checks
        final ci = File('.github/workflows/build-android-apk.yml').readAsStringSync();
        expect(ci.contains('ANDROID_KEYSTORE_BASE64'), isTrue);
        expect(ci.contains('--split-per-abi'), isTrue);
        expect(ci.contains('SHA256SUMS.txt'), isTrue);
      },
    );
  });
}
