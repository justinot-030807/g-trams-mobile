import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/network/socket_service.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/storage/app_preferences.dart';
import 'package:gtrams_mobile/core/storage/offline_wallet_cache.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';
import 'package:gtrams_mobile/core/storage/wizard_draft_cache.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/repositories/auth_repository.dart';
import 'package:gtrams_mobile/data/repositories/communication_repository.dart';
import 'package:gtrams_mobile/data/repositories/franchise_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/garage/view_models/garage_controller.dart';
import 'package:gtrams_mobile/features/settings/views/settings_hub_tab.dart';
import 'package:gtrams_mobile/features/settings/widgets/account_recovery_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/change_password_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/document_vault_sheet.dart';
import 'package:gtrams_mobile/features/settings/widgets/helpdesk_tickets_sheet.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/features/updates/views/updates_hub_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _operatorUser = MobileUser(
  id: 'op-501',
  name: 'Juan Dela Cruz',
  role: 'operator',
  contact: '09222222222',
  email: 'operator.tester@gtrams.com',
  address: 'Brgy. Poblacion, Gasan, Marinduque',
  todaAssociation: 'BATODA',
  bodyNumber: '12',
  hasLocalPassword: true,
);

class _FakeRealtimeSocketClient implements RealtimeSocketClient {
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;
  String? connectedToken;
  int disconnectCalls = 0;

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
    connectedToken = token;
    _status = RealtimeConnectionStatus.connected;
    connectionCtrl.add(_status);
  }

  @override
  void disconnect() {
    disconnectCalls += 1;
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

class _FakeCommunicationRepository extends CommunicationRepository {
  _FakeCommunicationRepository()
      : super(
          apiClient: ApiClient(sessionStorage: SecureSessionStorage()),
        );

  final List<String> sentMessages = [];
  final List<String> deletedNotificationIds = [];

  @override
  Future<List<ChatThreadItem>> fetchThreads() async => const [
        ChatThreadItem(
          id: 'thread-support-1',
          isAnnouncement: false,
          lastMessage: 'Magandang araw! Paano kami makakatulong?',
          unreadCount: 1,
          participants: [
            ChatSender(id: 'op-501', name: 'Juan Dela Cruz', role: 'operator'),
            ChatSender(
              id: 'staff-1',
              name: 'LLSA Licensing Officer',
              role: 'bplo_staff',
            ),
          ],
        ),
        ChatThreadItem(
          id: 'thread-announce-1',
          isAnnouncement: true,
          lastMessage: '[ANNOUNCEMENT - TODA: BATODA]\n\nAnnual renewal starts Monday.',
          unreadCount: 1,
        ),
      ];

  @override
  Future<List<ChatMessageItem>> fetchMessages(
    String threadId, {
    String? before,
    int limit = 50,
  }) async {
    if (threadId == 'thread-announce-1') {
      return [
        ChatMessageItem(
          id: 'ann-msg-1',
          threadId: 'thread-announce-1',
          sender: const ChatSender(
            id: 'staff-1',
            name: 'OVM Staff',
            role: 'bplo_staff',
          ),
          senderRole: 'bplo_staff',
          message:
              '[ANNOUNCEMENT - TODA: BATODA]\n\nAnnual MTOP inspection starts Monday at Gasan Municipal Hall.',
          targetToda: 'BATODA',
          targetStatus: 'ALL',
          isRead: false,
          createdAt: DateTime.utc(2026, 11, 20, 1, 30),
        ),
      ];
    }

    return [
      ChatMessageItem(
        id: 'chat-msg-1',
        threadId: 'thread-support-1',
        sender: const ChatSender(
          id: 'staff-1',
          name: 'LLSA Licensing Officer',
          role: 'bplo_staff',
        ),
        senderRole: 'bplo_staff',
        message: 'Magandang araw! Welcome sa OVM — LLSA I Support Desk.',
        createdAt: DateTime.utc(2026, 11, 20, 2, 0),
      ),
    ];
  }

  @override
  Future<SendMessageResult> sendMessage({
    String? threadId,
    required String message,
  }) async {
    sentMessages.add(message);
    return SendMessageResult(
      message: ChatMessageItem(
        id: 'chat-msg-${sentMessages.length + 10}',
        threadId: threadId ?? 'thread-support-1',
        sender: const ChatSender(
          id: 'op-501',
          name: 'Juan Dela Cruz',
          role: 'operator',
        ),
        senderRole: 'operator',
        message: message,
        createdAt: DateTime.utc(2026, 11, 20, 2, 5),
      ),
    );
  }

  @override
  Future<void> markThreadRead(String threadId) async {}

  @override
  Future<List<AppNotificationItem>> fetchNotifications() async => [
        AppNotificationItem(
          id: 'notif-1',
          type: 'approval',
          title: 'MTOP Ready for Pickup',
          message:
              'Your MTOP for plate BAT-1234 is ready for release at OVM — LLSA I.',
          relatedPlateNo: 'BAT-1234',
          isRead: false,
          createdAt: DateTime.utc(2026, 11, 20, 3, 0),
        ),
      ];

  @override
  Future<AppNotificationItem?> markNotificationRead(String id) async => null;

  @override
  Future<void> markAllNotificationsRead() async {}

  @override
  Future<void> deleteNotification(String id) async {
    deletedNotificationIds.add(id);
  }

  @override
  Future<void> clearAllNotifications() async {}
}

class _FakeSettingsRepository extends SettingsRepository {
  _FakeSettingsRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<PortalSettings> fetchSettings() async => const PortalSettings(
        maxUnitsPerOperator: 2,
        announcements: [
          PortalAnnouncement(
            title: '2026 Franchise Renewal Advisory',
            desc: 'Complete annual MTOP renewal at Gasan Municipal Hall.',
            type: 'alert',
            date: 'Annual Cycle',
            isActive: true,
          ),
        ],
      );
}

class _FakeFranchiseRepository extends FranchiseRepository {
  _FakeFranchiseRepository()
      : super(apiClient: ApiClient(sessionStorage: SecureSessionStorage()));

  @override
  Future<List<FranchiseRecord>> fetchMyFranchises() async => const [
        FranchiseRecord(
          id: 'fr-501',
          fullName: 'Juan Dela Cruz',
          plateNo: 'BAT-1234',
          status: 'Active',
          make: 'Honda',
          made: 'TMX 125',
          orCrUrl: 'https://res.cloudinary.com/demo/image/upload/orcr.jpg',
          licenseUrl: 'https://res.cloudinary.com/demo/image/upload/lic.jpg',
          cedulaUrl: 'https://res.cloudinary.com/demo/image/upload/ctc.pdf',
        ),
      ];
}

void main() {
  group('Phase 5 Models, OVM Copy Sanitizer & Document Vault', () {
    test('sanitizes legacy office acronym and extracts vault documents cleanly',
        () {
      expect(
        sanitizeCivicCopy('Approved by BPLO Staff at BPLO desk'),
        'Approved by OVM — LLSA I Staff at OVM — LLSA I desk',
      );

      final docs = extractVaultDocuments(const [
        FranchiseRecord(
          id: 'u1',
          fullName: 'Juan Dela Cruz',
          plateNo: 'BAT-9001',
          status: 'Active',
          make: 'Kawasaki',
          made: 'Barako 175',
          orCrUrl: 'https://cdn.example/orcr.jpg',
          crUrl: 'https://cdn.example/orcr.jpg', // deduplicated
          orUrl: 'https://cdn.example/or.jpg',
          licenseUrl: 'https://cdn.example/lic_front.jpg',
          licenseBackUrl: 'https://cdn.example/lic_back.jpg',
          brgyClearanceUrl: 'https://cdn.example/brgy.pdf',
          cedulaUrl: 'https://cdn.example/cedula.jpg',
        ),
      ]);

      expect(docs.length, 6);
      expect(docs.any((d) => d.docType == 'cr'), isFalse);
      expect(docs.firstWhere((d) => d.docType == 'brgy').isPdf, isTrue);

      final legacyUser = MobileUser.fromJson({
        '_id': 'u-legacy',
        'name': 'Legacy Op',
        'role': 'operator',
        'backupContact': 'backup@example.com',
      });
      expect(legacyUser.effectiveRecoveryEmail, 'backup@example.com');
      expect(legacyUser.effectiveRecoveryPhone, isEmpty);
    });

    test('UpdatesController handles live Socket.IO events & session_revoked',
        () async {
      final socket = _FakeRealtimeSocketClient();
      final repo = _FakeCommunicationRepository();
      String? revokedReason;

      final ctrl = UpdatesController(
        repository: repo,
        settingsRepository: _FakeSettingsRepository(),
        socketClient: socket,
        currentUserId: _operatorUser.id,
        readToken: () async => 'jwt-phase5-token',
        onSessionRevoked: (reason) => revokedReason = reason,
        autoInit: false,
      );

      await ctrl.initialize();
      expect(socket.connectedToken, 'jwt-phase5-token');
      expect(ctrl.state.connectionStatus, RealtimeConnectionStatus.connected);
      expect(ctrl.state.supportMessages.length, 1);
      expect(ctrl.state.announcementMessages.length, 1);
      expect(ctrl.state.portalAnnouncements.length, 1);
      expect(ctrl.state.notifications.length, 1);

      // Push live Socket.IO staff reply & notification
      socket.chatTypingCtrl.add(
        const ChatTypingEvent(threadId: 'thread-support-1', userId: 'staff-1'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.state.isStaffTyping, isTrue);

      socket.chatMessageCtrl.add(
        ChatMessageItem(
          id: 'live-reply-1',
          threadId: 'thread-support-1',
          sender: const ChatSender(
            id: 'staff-1',
            name: 'OVM Staff',
            role: 'bplo_staff',
          ),
          senderRole: 'bplo_staff',
          message: 'Your MTOP has been signed!',
          createdAt: DateTime.utc(2026, 11, 20, 4, 0),
        ),
      );
      socket.notificationCtrl.add(
        const AppNotificationItem(
          id: 'notif-live-2',
          type: 'status_change',
          title: 'Permit Signed',
          message: 'Ready for pickup at OVM — LLSA I.',
          isRead: false,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(ctrl.state.supportMessages.length, 2);
      expect(ctrl.state.isStaffTyping, isFalse);
      expect(ctrl.state.unreadNotificationsCount, 2);

      // Test sendMessage
      final sent = await ctrl.sendMessage('Salamat po!');
      expect(sent, isTrue);
      expect(repo.sentMessages, ['Salamat po!']);

      // Test session_revoked immediate logout callback
      socket.sessionRevokedCtrl
          .add('Session expired due to security update.');
      await Future<void>.delayed(Duration.zero);
      expect(revokedReason, 'Session expired due to security update.');

      ctrl.dispose();
      socket.dispose();
    });
  });

  group('Phase 5 Updates Hub & Settings Hub Widgets (Extra Large 1.26x Dark)',
      () {
    testWidgets(
      'UpdatesHubTab renders Chat, Announcements & Notifications at 1.26x Dark Mode with zero overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final socket = _FakeRealtimeSocketClient();
        final repo = _FakeCommunicationRepository();
        final ctrl = UpdatesController(
          repository: repo,
          settingsRepository: _FakeSettingsRepository(),
          socketClient: socket,
          currentUserId: _operatorUser.id,
          readToken: () async => 'jwt-token',
          onSessionRevoked: (_) {},
          autoInit: false,
        );
        await ctrl.initialize();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              updatesControllerProvider.overrideWith((ref) => ctrl),
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
                body: UpdatesHubTab(user: _operatorUser),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('OVM — LLSA I Support Desk'), findsOneWidget);

        // Send message from chat composer
        await tester.enterText(
          find.byKey(const Key('chat_composer_field')),
          'Paano po mag-renew?',
        );
        await tester.tap(find.byKey(const Key('chat_send_button')));
        await tester.pumpAndSettle();
        expect(repo.sentMessages, ['Paano po mag-renew?']);

        // Switch to Advisories (Announcements)
        final annTab = find.byKey(const Key('updates_section_announcements'));
        await tester.ensureVisible(annTab);
        await tester.tap(annTab);
        await tester.pumpAndSettle();
        expect(find.text('2026 Franchise Renewal Advisory'), findsOneWidget);

        // Switch to Alerts (Notifications)
        final notifTab = find.byKey(const Key('updates_section_notifications'));
        await tester.ensureVisible(notifTab);
        await tester.tap(notifTab);
        await tester.pumpAndSettle();
        expect(find.text('MTOP Ready for Pickup'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        socket.dispose();
      },
    );

    testWidgets(
      'SettingsHubTab renders all sections at Extra Large (1.26x) Dark Mode with zero overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 820);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues({
          'gtrams_text_scale': AppTextScaleOption.extraLarge.name,
        });
        final prefs = await SharedPreferences.getInstance();
        final garageCtrl = GarageController(
          franchiseRepository: _FakeFranchiseRepository(),
          settingsRepository: _FakeSettingsRepository(),
          walletCache: InMemoryOfflineWalletCache(),
          user: _operatorUser,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              garageControllerProvider.overrideWith((ref) => garageCtrl),
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
              home: const Scaffold(
                body: SettingsHubTab(
                  user: _operatorUser,
                  biometricSupported: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Juan Dela Cruz'), findsOneWidget);
        expect(
          find.byKey(const Key('settings_open_wallet_button')),
          findsOneWidget,
        );
        expect(find.text('Digital Operator ID & Wallet'), findsOneWidget);
        expect(find.byKey(const Key('settings_edit_profile_tile')), findsOneWidget);
        expect(find.byKey(const Key('settings_recovery_tile')), findsOneWidget);

        final settingsScroll = find.descendant(
          of: find.byKey(const Key('settings_hub_list')),
          matching: find.byType(Scrollable),
        ).first;
        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_document_vault_tile')),
          200,
          scrollable: settingsScroll,
        );
        expect(find.byKey(const Key('settings_document_vault_tile')), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_sign_out_button')),
          250,
          scrollable: settingsScroll,
        );
        expect(find.byKey(const Key('settings_sign_out_button')), findsOneWidget);
      },
    );

    testWidgets(
      'AccountRecoverySheet sends OTP and submits verified backup email',
      (WidgetTester tester) async {
        String? requestedTarget;
        String? savedEmail;
        String? savedOtp;

        await tester.pumpWidget(
          MaterialApp(
            theme: CivicTheme.light(),
            home: Scaffold(
              body: AccountRecoverySheet(
                user: _operatorUser,
                strings: const AppStrings('en'),
                onRequestOtp: (target) async {
                  requestedTarget = target;
                  return const RecoveryOtpResult(
                    destination: 'b***@example.com',
                    message: 'Verification code sent to b***@example.com.',
                  );
                },
                onSaveRecovery: ({
                  recoveryEmail,
                  recoveryPhone,
                  clearRecovery = false,
                  required currentPassword,
                  verificationTarget,
                  recoveryOtp,
                }) async {
                  savedEmail = recoveryEmail;
                  savedOtp = recoveryOtp;
                  return _operatorUser.copyWith(
                    recoveryEmail: recoveryEmail,
                    isRecoveryEmailVerified: true,
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('recovery_target_field')),
          'backup.op@example.com',
        );
        await tester.tap(find.byKey(const Key('recovery_send_otp_button')));
        await tester.pumpAndSettle();
        expect(requestedTarget, 'backup.op@example.com');

        await tester.enterText(
          find.byKey(const Key('recovery_otp_field')),
          '123456',
        );
        await tester.enterText(
          find.byKey(const Key('recovery_password_field')),
          'Password123!',
        );
        final saveBtn = find.byKey(const Key('recovery_save_button'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(savedEmail, 'backup.op@example.com');
        expect(savedOtp, '123456');
      },
    );

    testWidgets(
      'ChangePasswordSheet submits oldPassword + newPassword and returns rotated token',
      (WidgetTester tester) async {
        String? sentOld;
        String? sentNew;

        await tester.pumpWidget(
          MaterialApp(
            theme: CivicTheme.light(),
            home: Scaffold(
              body: ChangePasswordSheet(
                user: _operatorUser,
                strings: const AppStrings('en'),
                onChangePassword: ({
                  required oldPassword,
                  required newPassword,
                }) async {
                  sentOld = oldPassword;
                  sentNew = newPassword;
                  return const ChangePasswordResult(
                    message: 'Password changed successfully.',
                    newToken: 'fresh-jwt-v2',
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('change_pass_old_field')),
          'Password123!',
        );
        await tester.enterText(
          find.byKey(const Key('change_pass_new_field')),
          'GasanNew@2026!',
        );
        await tester.enterText(
          find.byKey(const Key('change_pass_confirm_field')),
          'GasanNew@2026!',
        );

        final submitBtn = find.byKey(const Key('change_pass_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(sentOld, 'Password123!');
        expect(sentNew, 'GasanNew@2026!');
      },
    );

    testWidgets(
      'HelpdeskTicketsSheet renders tickets & submits with exact contactNumber payload',
      (WidgetTester tester) async {
        String? submittedSubject;
        String? submittedContact;

        await tester.pumpWidget(
          MaterialApp(
            theme: CivicTheme.light(),
            home: Scaffold(
              body: HelpdeskTicketsSheet(
                user: _operatorUser,
                strings: const AppStrings('en'),
                onFetchTickets: () async => [
                  SupportTicketItem(
                    id: 'tk-1',
                    subject: 'OR/CR Upload Question',
                    contactNumber: '09222222222',
                    message: 'Where should I scan my CR?',
                    status: 'Resolved',
                    adminResponse: 'Use Step 2 Smart Scan in Apply Franchise.',
                    createdAt: DateTime.utc(2026, 11, 18, 4, 0),
                  ),
                ],
                onCreateTicket: ({
                  required subject,
                  required contactNumber,
                  required message,
                }) async {
                  submittedSubject = subject;
                  submittedContact = contactNumber;
                  return SupportTicketItem(
                    id: 'tk-2',
                    subject: subject,
                    contactNumber: contactNumber,
                    message: message,
                    status: 'Open',
                    createdAt: DateTime.utc(2026, 11, 20, 5, 0),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('ticket_subject_field')),
          'MTOP Renewal Clarification',
        );
        await tester.enterText(
          find.byKey(const Key('ticket_message_field')),
          'Please confirm the updated renewal schedule for BATODA units.',
        );
        final submitBtn = find.byKey(const Key('ticket_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(submittedSubject, 'MTOP Renewal Clarification');
        expect(submittedContact, '09222222222');
        expect(find.text('MTOP Renewal Clarification'), findsOneWidget);
      },
    );

    testWidgets('DocumentVaultSheet displays and filters stored documents',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CivicTheme.light(),
          home: Scaffold(
            body: DocumentVaultSheet(
              strings: const AppStrings('en'),
              documents: const [
                VaultDocumentItem(
                  id: 'd1',
                  title: 'Tricycle OR / CR (LTO Registration)',
                  category: 'Vehicle Document',
                  plateNo: 'BAT-1234',
                  unitDesc: 'Honda (TMX 125)',
                  url: 'https://cdn.example/orcr.jpg',
                  franchiseStatus: 'Active',
                  docType: 'orCr',
                ),
                VaultDocumentItem(
                  id: 'd2',
                  title: 'Barangay Clearance (Gasan)',
                  category: 'LGU Clearance',
                  plateNo: 'BAT-5678',
                  unitDesc: 'Kawasaki (Barako)',
                  url: 'https://cdn.example/brgy.pdf',
                  franchiseStatus: 'Pending',
                  docType: 'brgy',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tricycle OR / CR (LTO Registration)'), findsOneWidget);
      expect(find.text('Barangay Clearance (Gasan)'), findsOneWidget);

      await tester.tap(find.text('BAT-1234').first);
      await tester.pumpAndSettle();
      expect(find.text('Tricycle OR / CR (LTO Registration)'), findsOneWidget);
      expect(find.text('Barangay Clearance (Gasan)'), findsNothing);
    });
  });
}
