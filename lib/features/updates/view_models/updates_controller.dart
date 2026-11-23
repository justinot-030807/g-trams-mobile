import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/network/socket_service.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/data/repositories/communication_repository.dart';
import 'package:gtrams_mobile/data/repositories/settings_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';

enum UpdatesSection { supportChat, announcements, notifications }

class UpdatesState {
  const UpdatesState({
    this.section = UpdatesSection.supportChat,
    this.connectionStatus = RealtimeConnectionStatus.disconnected,
    this.isLoading = false,
    this.isSendingMessage = false,
    this.isLoadingEarlier = false,
    this.hasMoreSupportMessages = false,
    this.isStaffTyping = false,
    this.supportThread,
    this.announcementThread,
    this.supportMessages = const [],
    this.announcementMessages = const [],
    this.portalAnnouncements = const [],
    this.notifications = const [],
    this.errorMessage,
    this.actionError,
  });

  final UpdatesSection section;
  final RealtimeConnectionStatus connectionStatus;
  final bool isLoading;
  final bool isSendingMessage;
  final bool isLoadingEarlier;
  final bool hasMoreSupportMessages;
  final bool isStaffTyping;
  final ChatThreadItem? supportThread;
  final ChatThreadItem? announcementThread;
  final List<ChatMessageItem> supportMessages;
  final List<ChatMessageItem> announcementMessages;
  final List<PortalAnnouncement> portalAnnouncements;
  final List<AppNotificationItem> notifications;
  final String? errorMessage;
  final String? actionError;

  int get unreadChatCount => supportThread?.unreadCount ?? 0;

  int get unreadAnnouncementsCount => announcementThread?.unreadCount ?? 0;

  int get unreadNotificationsCount =>
      notifications.where((n) => !n.isRead).length;

  int get totalBadgeCount =>
      unreadNotificationsCount + unreadChatCount + unreadAnnouncementsCount;

  UpdatesState copyWith({
    UpdatesSection? section,
    RealtimeConnectionStatus? connectionStatus,
    bool? isLoading,
    bool? isSendingMessage,
    bool? isLoadingEarlier,
    bool? hasMoreSupportMessages,
    bool? isStaffTyping,
    ChatThreadItem? supportThread,
    ChatThreadItem? announcementThread,
    List<ChatMessageItem>? supportMessages,
    List<ChatMessageItem>? announcementMessages,
    List<PortalAnnouncement>? portalAnnouncements,
    List<AppNotificationItem>? notifications,
    String? errorMessage,
    bool clearError = false,
    String? actionError,
    bool clearActionError = false,
  }) {
    return UpdatesState(
      section: section ?? this.section,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoading: isLoading ?? this.isLoading,
      isSendingMessage: isSendingMessage ?? this.isSendingMessage,
      isLoadingEarlier: isLoadingEarlier ?? this.isLoadingEarlier,
      hasMoreSupportMessages:
          hasMoreSupportMessages ?? this.hasMoreSupportMessages,
      isStaffTyping: isStaffTyping ?? this.isStaffTyping,
      supportThread: supportThread ?? this.supportThread,
      announcementThread: announcementThread ?? this.announcementThread,
      supportMessages: supportMessages ?? this.supportMessages,
      announcementMessages: announcementMessages ?? this.announcementMessages,
      portalAnnouncements: portalAnnouncements ?? this.portalAnnouncements,
      notifications: notifications ?? this.notifications,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      actionError:
          clearActionError ? null : (actionError ?? this.actionError),
    );
  }
}

final Provider<CommunicationRepository> communicationRepositoryProvider =
    Provider<CommunicationRepository>((ref) {
  return CommunicationRepository(apiClient: ref.watch(apiClientProvider));
});

/// Manages Socket.IO live support chat, official LGU broadcast advisories,
/// and the real-time Notifications Center.
class UpdatesController extends StateNotifier<UpdatesState> {
  UpdatesController({
    required CommunicationRepository repository,
    required SettingsRepository settingsRepository,
    required RealtimeSocketClient socketClient,
    required String currentUserId,
    required Future<String?> Function() readToken,
    required void Function(String reason) onSessionRevoked,
    bool autoInit = true,
  })  : _repo = repository,
        _settingsRepo = settingsRepository,
        _socket = socketClient,
        _currentUserId = currentUserId,
        _readToken = readToken,
        _onSessionRevoked = onSessionRevoked,
        super(const UpdatesState()) {
    _bindSocketStreams();
    if (autoInit && currentUserId.isNotEmpty) {
      unawaited(initialize());
    }
  }

  final CommunicationRepository _repo;
  final SettingsRepository _settingsRepo;
  final RealtimeSocketClient _socket;
  final String _currentUserId;
  final Future<String?> Function() _readToken;
  final void Function(String reason) _onSessionRevoked;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _typingClearTimer;
  bool _isUpdatesTabActive = false;

  void setUpdatesTabActive(bool active) {
    _isUpdatesTabActive = active;
    if (active) {
      _markVisibleThreadReadIfNeeded();
    }
  }

  void setSection(UpdatesSection section) {
    state = state.copyWith(section: section, clearActionError: true);
    _markVisibleThreadReadIfNeeded();
  }

  void _markVisibleThreadReadIfNeeded() {
    if (!_isUpdatesTabActive) return;
    if (state.section == UpdatesSection.supportChat &&
        state.supportThread != null &&
        state.supportThread!.unreadCount > 0) {
      unawaited(markSupportRead());
    } else if (state.section == UpdatesSection.announcements &&
        state.announcementThread != null &&
        state.announcementThread!.unreadCount > 0) {
      unawaited(markAnnouncementsRead());
    }
  }

  void _bindSocketStreams() {
    _subs.add(
      _socket.connectionStream.listen((status) {
        if (!mounted) return;
        state = state.copyWith(connectionStatus: status);
      }),
    );

    _subs.add(
      _socket.chatMessageStream.listen(_handleIncomingChatMessage),
    );

    _subs.add(
      _socket.chatTypingStream.listen((event) {
        if (!mounted) return;
        if (event.userId == _currentUserId) return;
        final supportId = state.supportThread?.id ?? '';
        if (supportId.isNotEmpty && event.threadId != supportId) return;
        state = state.copyWith(isStaffTyping: true);
        _typingClearTimer?.cancel();
        _typingClearTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted) {
            state = state.copyWith(isStaffTyping: false);
          }
        });
      }),
    );

    _subs.add(
      _socket.chatReadStream.listen((threadId) {
        if (!mounted) return;
        if (state.supportThread?.id == threadId) {
          state = state.copyWith(
            supportThread: state.supportThread!.copyWith(unreadCount: 0),
          );
        } else if (state.announcementThread?.id == threadId) {
          state = state.copyWith(
            announcementThread:
                state.announcementThread!.copyWith(unreadCount: 0),
          );
        }
      }),
    );

    _subs.add(
      _socket.notificationStream.listen((incoming) {
        if (!mounted || incoming.id.isEmpty) return;
        final exists = state.notifications.any((n) => n.id == incoming.id);
        final updated = exists
            ? state.notifications
                .map((n) => n.id == incoming.id ? incoming : n)
                .toList()
            : [incoming, ...state.notifications];
        state = state.copyWith(notifications: updated);
      }),
    );

    _subs.add(
      _socket.notificationSyncStream.listen((sync) {
        if (!mounted) return;
        switch (sync.kind) {
          case NotificationSyncKind.readOne:
            state = state.copyWith(
              notifications: state.notifications
                  .map(
                    (n) => n.id == sync.notificationId
                        ? n.copyWith(isRead: true)
                        : n,
                  )
                  .toList(),
            );
            break;
          case NotificationSyncKind.deletedOne:
            state = state.copyWith(
              notifications: state.notifications
                  .where((n) => n.id != sync.notificationId)
                  .toList(),
            );
            break;
          case NotificationSyncKind.allRead:
            state = state.copyWith(
              notifications: state.notifications
                  .map((n) => n.copyWith(isRead: true))
                  .toList(),
            );
            break;
          case NotificationSyncKind.allCleared:
            state = state.copyWith(notifications: const []);
            break;
        }
      }),
    );

    _subs.add(
      _socket.sessionRevokedStream.listen((reason) {
        if (!mounted) return;
        _onSessionRevoked(reason);
      }),
    );
  }

  void _handleIncomingChatMessage(ChatMessageItem msg) {
    if (!mounted || msg.id.isEmpty) return;

    final isAnnouncement =
        (state.announcementThread != null &&
            msg.threadId == state.announcementThread!.id) ||
            msg.message.startsWith('[ANNOUNCEMENT');

    if (isAnnouncement) {
      final alreadyExists =
          state.announcementMessages.any((m) => m.id == msg.id);
      final updatedList = alreadyExists
          ? state.announcementMessages
          : [...state.announcementMessages, msg];
      final viewingAnnouncements =
          _isUpdatesTabActive && state.section == UpdatesSection.announcements;
      final currentThread = state.announcementThread ??
          ChatThreadItem(id: msg.threadId, isAnnouncement: true);
      final nextUnread = viewingAnnouncements
          ? 0
          : currentThread.unreadCount + (alreadyExists ? 0 : 1);

      state = state.copyWith(
        announcementThread: currentThread.copyWith(
          lastMessage: msg.message,
          lastMessageAt: msg.createdAt ?? DateTime.now(),
          unreadCount: nextUnread,
        ),
        announcementMessages: updatedList,
      );
      if (viewingAnnouncements && currentThread.id.isNotEmpty) {
        unawaited(markAnnouncementsRead());
      }
      return;
    }

    // Live Support Chat message
    final alreadyExists = state.supportMessages.any((m) => m.id == msg.id);
    final updatedList =
        alreadyExists ? state.supportMessages : [...state.supportMessages, msg];
    final fromSelf = msg.isSentBy(_currentUserId);
    final viewingChat =
        _isUpdatesTabActive && state.section == UpdatesSection.supportChat;

    final currentThread = state.supportThread ??
        ChatThreadItem(id: msg.threadId, isAnnouncement: false);
    final nextUnread = (fromSelf || viewingChat)
        ? 0
        : currentThread.unreadCount + (alreadyExists ? 0 : 1);

    state = state.copyWith(
      isStaffTyping: fromSelf ? state.isStaffTyping : false,
      supportThread: currentThread.copyWith(
        lastMessage: msg.message,
        lastMessageAt: msg.createdAt ?? DateTime.now(),
        unreadCount: nextUnread,
      ),
      supportMessages: updatedList,
    );

    if (!fromSelf && viewingChat && currentThread.id.isNotEmpty) {
      unawaited(markSupportRead());
    }
  }

  /// Connects Socket.IO with current JWT and hydrates Threads, Messages,
  /// Portal Advisories, and Notifications in parallel.
  Future<void> initialize() async {
    await connectSocket();
    await loadAll();
  }

  Future<void> connectSocket({String? overrideToken}) async {
    final token = (overrideToken ?? await _readToken())?.trim() ?? '';
    if (token.isNotEmpty) {
      _socket.connect(token);
    }
  }

  void disconnectSocket() {
    _socket.disconnect();
  }

  Future<void> loadAll({bool isPullToRefresh = false}) async {
    if (!isPullToRefresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true, clearActionError: true);
    }

    try {
      final results = await Future.wait([
        _repo.fetchThreads(),
        _repo.fetchNotifications(),
        _settingsRepo.fetchSettings(),
      ]);

      final threads = results[0] as List<ChatThreadItem>;
      final notifications = results[1] as List<AppNotificationItem>;
      final settings = results[2] as PortalSettings;

      ChatThreadItem? supportThread;
      ChatThreadItem? announcementThread;
      for (final t in threads) {
        if (t.isAnnouncement) {
          announcementThread ??= t;
        } else {
          supportThread ??= t;
        }
      }

      List<ChatMessageItem> supportMsgs = const [];
      List<ChatMessageItem> announcementMsgs = const [];

      final msgFutures = <Future<void>>[];
      if (supportThread != null && supportThread.id.isNotEmpty) {
        msgFutures.add(
          _repo.fetchMessages(supportThread.id, limit: 50).then((list) {
            supportMsgs = list;
          }),
        );
      }
      if (announcementThread != null && announcementThread.id.isNotEmpty) {
        msgFutures.add(
          _repo.fetchMessages(announcementThread.id, limit: 50).then((list) {
            announcementMsgs = list;
          }),
        );
      }
      if (msgFutures.isNotEmpty) {
        await Future.wait(msgFutures);
      }

      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        supportThread: supportThread,
        announcementThread: announcementThread,
        supportMessages: supportMsgs,
        hasMoreSupportMessages: supportMsgs.length >= 50,
        announcementMessages: announcementMsgs,
        portalAnnouncements: settings.activeAnnouncements,
        notifications: notifications,
        clearError: true,
      );

      _markVisibleThreadReadIfNeeded();
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.message);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load updates. Please pull to refresh.',
      );
    }
  }

  Future<void> loadEarlierSupportMessages() async {
    final thread = state.supportThread;
    if (thread == null ||
        thread.id.isEmpty ||
        state.isLoadingEarlier ||
        state.supportMessages.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingEarlier: true, clearActionError: true);
    try {
      final oldestId = state.supportMessages.first.id;
      final older = await _repo.fetchMessages(
        thread.id,
        before: oldestId,
        limit: 50,
      );
      if (!mounted) return;
      final existingIds = state.supportMessages.map((m) => m.id).toSet();
      final uniqueOlder =
          older.where((m) => !existingIds.contains(m.id)).toList();
      state = state.copyWith(
        isLoadingEarlier: false,
        supportMessages: [...uniqueOlder, ...state.supportMessages],
        hasMoreSupportMessages: older.length >= 50,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoadingEarlier: false, actionError: e.message);
    }
  }

  void notifyTyping() {
    final thread = state.supportThread;
    final staffId = thread?.primaryStaffRecipientId;
    if (thread != null &&
        thread.id.isNotEmpty &&
        staffId != null &&
        staffId.isNotEmpty) {
      _socket.emitTyping(threadId: thread.id, recipientId: staffId);
    }
  }

  Future<bool> sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || state.isSendingMessage) return false;

    state = state.copyWith(isSendingMessage: true, clearActionError: true);
    try {
      final result = await _repo.sendMessage(
        threadId: state.supportThread?.id,
        message: clean,
      );
      if (!mounted) return false;

      final exists = state.supportMessages.any((m) => m.id == result.message.id);
      final updatedMessages = exists
          ? state.supportMessages
          : [...state.supportMessages, result.message];

      final nextThread = result.thread ??
          (state.supportThread ??
                  ChatThreadItem(
                    id: result.message.threadId,
                    isAnnouncement: false,
                  ))
              .copyWith(
            lastMessage: result.message.message,
            lastMessageAt: result.message.createdAt ?? DateTime.now(),
            unreadCount: 0,
          );

      state = state.copyWith(
        isSendingMessage: false,
        supportThread: nextThread.copyWith(unreadCount: 0),
        supportMessages: updatedMessages,
      );
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      state = state.copyWith(isSendingMessage: false, actionError: e.message);
      return false;
    }
  }

  Future<void> markSupportRead() async {
    final thread = state.supportThread;
    if (thread == null || thread.id.isEmpty) return;

    state = state.copyWith(supportThread: thread.copyWith(unreadCount: 0));
    try {
      await _repo.markThreadRead(thread.id);
    } catch (_) {
      // Non-blocking read sync
    }
  }

  Future<void> markAnnouncementsRead() async {
    final thread = state.announcementThread;
    if (thread == null || thread.id.isEmpty) return;

    state = state.copyWith(
      announcementThread: thread.copyWith(unreadCount: 0),
      announcementMessages: state.announcementMessages
          .map((m) => m.copyWith(isRead: true))
          .toList(),
    );
    try {
      await _repo.markThreadRead(thread.id);
    } catch (_) {
      // Non-blocking read sync
    }
  }

  Future<void> markNotificationRead(String id) async {
    if (id.isEmpty) return;
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    );
    try {
      await _repo.markNotificationRead(id);
    } catch (_) {
      // Keep optimistic state
    }
  }

  Future<void> markAllNotificationsRead() async {
    state = state.copyWith(
      notifications:
          state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );
    try {
      await _repo.markAllNotificationsRead();
    } on ApiException catch (e) {
      if (mounted) state = state.copyWith(actionError: e.message);
    }
  }

  Future<void> deleteNotification(String id) async {
    if (id.isEmpty) return;
    final previous = state.notifications;
    state = state.copyWith(
      notifications: previous.where((n) => n.id != id).toList(),
    );
    try {
      await _repo.deleteNotification(id);
    } on ApiException catch (e) {
      if (mounted) {
        state = state.copyWith(notifications: previous, actionError: e.message);
      }
    }
  }

  Future<void> clearAllNotifications() async {
    final previous = state.notifications;
    state = state.copyWith(notifications: const []);
    try {
      await _repo.clearAllNotifications();
    } on ApiException catch (e) {
      if (mounted) {
        state = state.copyWith(notifications: previous, actionError: e.message);
      }
    }
  }

  @override
  void dispose() {
    _typingClearTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _socket.disconnect();
    super.dispose();
  }
}

final StateNotifierProvider<UpdatesController, UpdatesState>
    updatesControllerProvider =
    StateNotifierProvider<UpdatesController, UpdatesState>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.user?.id ?? ''));
  return UpdatesController(
    repository: ref.watch(communicationRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    socketClient: ref.watch(realtimeSocketClientProvider),
    currentUserId: userId,
    readToken: () => ref.read(authControllerProvider.notifier).readSessionToken(),
    onSessionRevoked: (reason) {
      ref.read(authControllerProvider.notifier).forceLogout(reason: reason);
    },
  );
});
