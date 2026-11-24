import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

enum RealtimeConnectionStatus { disconnected, connecting, connected }

class ChatTypingEvent {
  const ChatTypingEvent({
    required this.threadId,
    required this.userId,
  });

  final String threadId;
  final String userId;
}

enum NotificationSyncKind { readOne, deletedOne, allRead, allCleared }

class NotificationSyncEvent {
  const NotificationSyncEvent({
    required this.kind,
    this.notificationId = '',
  });

  final NotificationSyncKind kind;
  final String notificationId;
}

/// Abstract real-time client so controllers and widgets can be unit/widget tested
/// without opening real network sockets.
abstract class RealtimeSocketClient {
  RealtimeConnectionStatus get status;
  Stream<RealtimeConnectionStatus> get connectionStream;
  Stream<ChatMessageItem> get chatMessageStream;
  Stream<ChatTypingEvent> get chatTypingStream;
  Stream<String> get chatReadStream;
  Stream<AppNotificationItem> get notificationStream;
  Stream<NotificationSyncEvent> get notificationSyncStream;
  Stream<String> get sessionRevokedStream;

  void connect(String token);
  void disconnect();
  void emitTyping({required String threadId, required String recipientId});
  void dispose();
}

/// Live Socket.IO v4 client connected to `AppConfig.apiOrigin` with JWT auth handshake.
class SocketIoRealtimeClient implements RealtimeSocketClient {
  io.Socket? _socket;
  String? _activeToken;
  DateTime? _lastTypingEmit;
  RealtimeConnectionStatus _status = RealtimeConnectionStatus.disconnected;

  final _connectionCtrl =
      StreamController<RealtimeConnectionStatus>.broadcast();
  final _chatMessageCtrl = StreamController<ChatMessageItem>.broadcast();
  final _chatTypingCtrl = StreamController<ChatTypingEvent>.broadcast();
  final _chatReadCtrl = StreamController<String>.broadcast();
  final _notificationCtrl = StreamController<AppNotificationItem>.broadcast();
  final _notificationSyncCtrl =
      StreamController<NotificationSyncEvent>.broadcast();
  final _sessionRevokedCtrl = StreamController<String>.broadcast();

  @override
  RealtimeConnectionStatus get status => _status;

  @override
  Stream<RealtimeConnectionStatus> get connectionStream =>
      _connectionCtrl.stream;

  @override
  Stream<ChatMessageItem> get chatMessageStream => _chatMessageCtrl.stream;

  @override
  Stream<ChatTypingEvent> get chatTypingStream => _chatTypingCtrl.stream;

  @override
  Stream<String> get chatReadStream => _chatReadCtrl.stream;

  @override
  Stream<AppNotificationItem> get notificationStream =>
      _notificationCtrl.stream;

  @override
  Stream<NotificationSyncEvent> get notificationSyncStream =>
      _notificationSyncCtrl.stream;

  @override
  Stream<String> get sessionRevokedStream => _sessionRevokedCtrl.stream;

  void _setStatus(RealtimeConnectionStatus next) {
    if (_status == next) return;
    _status = next;
    if (!_connectionCtrl.isClosed) {
      _connectionCtrl.add(next);
    }
  }

  @override
  void connect(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;

    if (_socket != null && _activeToken == trimmed && _socket!.connected) {
      return;
    }

    disconnect();
    _activeToken = trimmed;
    _setStatus(RealtimeConnectionStatus.connecting);

    final socket = io.io(
      AppConfig.apiOrigin,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': trimmed})
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _setStatus(RealtimeConnectionStatus.connected);
    });

    socket.onDisconnect((_) {
      _setStatus(RealtimeConnectionStatus.disconnected);
    });

    socket.onReconnectAttempt((_) {
      _setStatus(RealtimeConnectionStatus.connecting);
    });

    socket.onConnectError((err) {
      final msg = err?.toString() ?? '';
      if (msg.contains('Session expired') ||
          msg.contains('Token expired') ||
          msg.contains('Account is inactive')) {
        _emitRevoked(msg);
      } else {
        _setStatus(RealtimeConnectionStatus.disconnected);
      }
    });

    socket.on('chat_message', (data) {
      if (data is Map && !_chatMessageCtrl.isClosed) {
        _chatMessageCtrl.add(
          ChatMessageItem.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on('chat_typing', (data) {
      if (data is Map && !_chatTypingCtrl.isClosed) {
        final map = Map<String, dynamic>.from(data);
        final threadId = (map['threadId'] ?? '').toString().trim();
        final userId = (map['userId'] ?? '').toString().trim();
        if (threadId.isNotEmpty) {
          _chatTypingCtrl.add(
            ChatTypingEvent(threadId: threadId, userId: userId),
          );
        }
      }
    });

    socket.on('chat_read', (data) {
      if (data is Map && !_chatReadCtrl.isClosed) {
        final threadId = (data['threadId'] ?? '').toString().trim();
        if (threadId.isNotEmpty) {
          _chatReadCtrl.add(threadId);
        }
      }
    });

    socket.on('notification', (data) {
      if (data is Map && !_notificationCtrl.isClosed) {
        _notificationCtrl.add(
          AppNotificationItem.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    });

    socket.on('notification_read', (data) {
      final id = data is Map ? (data['id'] ?? '').toString().trim() : '';
      if (!_notificationSyncCtrl.isClosed) {
        _notificationSyncCtrl.add(
          NotificationSyncEvent(
            kind: NotificationSyncKind.readOne,
            notificationId: id,
          ),
        );
      }
    });

    socket.on('notification_deleted', (data) {
      final id = data is Map ? (data['id'] ?? '').toString().trim() : '';
      if (!_notificationSyncCtrl.isClosed) {
        _notificationSyncCtrl.add(
          NotificationSyncEvent(
            kind: NotificationSyncKind.deletedOne,
            notificationId: id,
          ),
        );
      }
    });

    socket.on('notifications_marked_read', (_) {
      if (!_notificationSyncCtrl.isClosed) {
        _notificationSyncCtrl.add(
          const NotificationSyncEvent(kind: NotificationSyncKind.allRead),
        );
      }
    });

    socket.on('notifications_read_all', (_) {
      if (!_notificationSyncCtrl.isClosed) {
        _notificationSyncCtrl.add(
          const NotificationSyncEvent(kind: NotificationSyncKind.allCleared),
        );
      }
    });

    socket.on('session_revoked', (data) {
      if (!identical(socket, _socket)) return;
      final reason = data is Map
          ? (data['reason'] ??
                  'Your session expired due to a security update. Please sign in again.')
              .toString()
          : 'Your session expired due to a security update. Please sign in again.';
      _emitRevoked(reason);
    });

    _socket = socket;
    socket.connect();
  }

  void _emitRevoked(String reason) {
    disconnect();
    if (!_sessionRevokedCtrl.isClosed) {
      _sessionRevokedCtrl.add(reason);
    }
  }

  @override
  void emitTyping({required String threadId, required String recipientId}) {
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    if (threadId.isEmpty || recipientId.isEmpty) return;

    final now = DateTime.now();
    if (_lastTypingEmit != null &&
        now.difference(_lastTypingEmit!).inMilliseconds < 2000) {
      return;
    }
    _lastTypingEmit = now;
    socket.emit('chat_typing', {
      'threadId': threadId,
      'recipientId': recipientId,
    });
  }

  @override
  void disconnect() {
    _activeToken = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      try {
        socket.clearListeners();
        socket.disconnect();
        socket.dispose();
      } catch (_) {
        // Ignore teardown errors during disconnect
      }
    }
    _setStatus(RealtimeConnectionStatus.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    _connectionCtrl.close();
    _chatMessageCtrl.close();
    _chatTypingCtrl.close();
    _chatReadCtrl.close();
    _notificationCtrl.close();
    _notificationSyncCtrl.close();
    _sessionRevokedCtrl.close();
  }
}

final Provider<RealtimeSocketClient> realtimeSocketClientProvider =
    Provider<RealtimeSocketClient>((ref) {
  final client = SocketIoRealtimeClient();
  ref.onDispose(client.dispose);
  return client;
});
