import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';

/// Response wrapper for `POST /api/v1/chat/messages`.
class SendMessageResult {
  const SendMessageResult({
    required this.message,
    this.thread,
  });

  final ChatMessageItem message;
  final ChatThreadItem? thread;
}

/// Handles Live Support Chat, Official LGU Broadcast Announcements,
/// Notifications Center, and Helpdesk Tickets endpoints.
class CommunicationRepository {
  CommunicationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  // ---------------------------------------------------------------------------
  // Support Chat & Official Broadcast Announcements (`/api/v1/chat`)
  // ---------------------------------------------------------------------------

  Future<List<ChatThreadItem>> fetchThreads() async {
    try {
      final res = await _api.dio.get<dynamic>('/chat/threads');
      final list = res.data is List ? res.data as List : const [];
      return list
          .whereType<Map>()
          .map((e) => ChatThreadItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<int> fetchChatUnreadCount() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/chat/unread-count');
      final raw = res.data?['unreadCount'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<List<ChatMessageItem>> fetchMessages(
    String threadId, {
    String? before,
    int limit = 50,
  }) async {
    try {
      final res = await _api.dio.get<dynamic>(
        '/chat/messages/$threadId',
        queryParameters: {
          'limit': limit,
          if (before != null && before.isNotEmpty) 'before': before,
        },
      );
      final list = res.data is List ? res.data as List : const [];
      return list
          .whereType<Map>()
          .map((e) => ChatMessageItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<SendMessageResult> sendMessage({
    String? threadId,
    required String message,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/chat/messages',
        data: {
          if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
          'message': message.trim(),
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final msgMap = data['message'] is Map
          ? Map<String, dynamic>.from(data['message'] as Map)
          : data;
      final threadMap = data['thread'] is Map
          ? Map<String, dynamic>.from(data['thread'] as Map)
          : null;

      return SendMessageResult(
        message: ChatMessageItem.fromJson(msgMap),
        thread: threadMap != null ? ChatThreadItem.fromJson(threadMap) : null,
      );
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<void> markThreadRead(String threadId) async {
    try {
      await _api.dio.put<dynamic>('/chat/messages/$threadId/read');
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Notifications Center (`/api/v1/notifications`)
  // ---------------------------------------------------------------------------

  Future<List<AppNotificationItem>> fetchNotifications() async {
    try {
      final res = await _api.dio.get<dynamic>('/notifications');
      final list = res.data is List ? res.data as List : const [];
      return list
          .whereType<Map>()
          .map(
            (e) => AppNotificationItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<int> fetchNotificationUnreadCount() async {
    try {
      final res =
          await _api.dio.get<Map<String, dynamic>>('/notifications/unread-count');
      final raw = res.data?['count'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await _api.dio.put<dynamic>('/notifications/read-all');
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _api.dio.delete<dynamic>('/notifications/clear-all');
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<AppNotificationItem?> markNotificationRead(String id) async {
    try {
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/notifications/$id/read',
      );
      if (res.data == null) return null;
      return AppNotificationItem.fromJson(res.data!);
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _api.dio.delete<dynamic>('/notifications/$id');
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // IT & Operator Support Helpdesk Tickets (`/api/v1/tickets`)
  // ---------------------------------------------------------------------------

  Future<List<SupportTicketItem>> fetchMyTickets() async {
    try {
      final res = await _api.dio.get<dynamic>('/tickets/my-tickets');
      final list = res.data is List ? res.data as List : const [];
      return list
          .whereType<Map>()
          .map((e) => SupportTicketItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }

  Future<SupportTicketItem> createTicket({
    required String subject,
    required String contactNumber,
    required String message,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/tickets',
        data: {
          'subject': subject.trim(),
          'contactNumber': contactNumber.trim(),
          'message': message.trim(),
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      final ticketMap = data['ticket'] is Map
          ? Map<String, dynamic>.from(data['ticket'] as Map)
          : data;
      return SupportTicketItem.fromJson(ticketMap);
    } catch (e) {
      throw ApiClient.mapDioError(e);
    }
  }
}
