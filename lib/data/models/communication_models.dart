import 'package:gtrams_mobile/core/constants/gasan_constants.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';

/// Sanitizes legacy office acronyms from server-generated messages or notifications
/// so mobile UI strictly displays "OVM — LLSA I" per Gasan LGU copy standards.
String sanitizeCivicCopy(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .replaceAll(
        RegExp(r'\bBPLO\s*Staff\b', caseSensitive: false),
        'OVM — LLSA I Staff',
      )
      .replaceAll(
        RegExp(r'\bBPLO\b', caseSensitive: false),
        'OVM — LLSA I',
      );
}

/// Participant or message sender metadata in Live Support Chat & Broadcasts.
class ChatSender {
  const ChatSender({
    required this.id,
    required this.name,
    this.role = '',
    this.profilePic = '',
  });

  final String id;
  final String name;
  final String role;
  final String profilePic;

  bool get isStaff {
    final norm = GasanConstants.normalizeRole(role);
    return norm != 'operator' && norm != 'toda_president' && norm.isNotEmpty;
  }

  String get displayLabel {
    if (isStaff) return 'OVM — LLSA I Support';
    return name.isNotEmpty ? name : 'Operator';
  }

  factory ChatSender.fromDynamic(dynamic raw, {String fallbackRole = ''}) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return ChatSender(
        id: (map['_id'] ?? map['id'] ?? '').toString().trim(),
        name: sanitizeCivicCopy((map['name'] ?? '').toString().trim()),
        role: (map['role'] ?? fallbackRole).toString().trim(),
        profilePic: (map['profilePic'] ?? '').toString().trim(),
      );
    }
    return ChatSender(
      id: (raw ?? '').toString().trim(),
      name: '',
      role: fallbackRole,
    );
  }
}

/// Thread returned by `GET /api/v1/chat/threads` (operator support or LGU announcement).
class ChatThreadItem {
  const ChatThreadItem({
    required this.id,
    this.isAnnouncement = false,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadCount = 0,
    this.participants = const [],
  });

  final String id;
  final bool isAnnouncement;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<ChatSender> participants;

  /// Picks the first staff participant ID for outgoing `chat_typing` socket events.
  String? get primaryStaffRecipientId {
    for (final p in participants) {
      if (p.isStaff && p.id.isNotEmpty) return p.id;
    }
    return null;
  }

  ChatThreadItem copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
    List<ChatSender>? participants,
  }) {
    return ChatThreadItem(
      id: id,
      isAnnouncement: isAnnouncement,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      participants: participants ?? this.participants,
    );
  }

  factory ChatThreadItem.fromJson(Map<String, dynamic> json) {
    final rawParts = json['participants'];
    final parts = rawParts is List
        ? rawParts.map((p) => ChatSender.fromDynamic(p)).toList()
        : const <ChatSender>[];
    return ChatThreadItem(
      id: (json['_id'] ?? json['id'] ?? '').toString().trim(),
      isAnnouncement: json['isAnnouncement'] == true,
      lastMessage: sanitizeCivicCopy((json['lastMessage'] ?? '').toString().trim()),
      lastMessageAt: ManilaDateFormatter.tryParseIso(json['lastMessageAt']),
      unreadCount: _parseInt(json['unreadCount']),
      participants: parts,
    );
  }
}

/// Single chat or LGU broadcast message (`GET /api/v1/chat/messages/:threadId` & `chat_message`).
class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.threadId,
    required this.sender,
    required this.message,
    this.senderRole = '',
    this.targetToda = 'ALL',
    this.targetStatus = 'ALL',
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String threadId;
  final ChatSender sender;
  final String senderRole;
  final String message;
  final String targetToda;
  final String targetStatus;
  final bool isRead;
  final DateTime? createdAt;

  bool isSentBy(String currentUserId) =>
      currentUserId.isNotEmpty && sender.id == currentUserId;

  bool get isAutoReply =>
      message.trim().toLowerCase().startsWith('automated reply:');

  bool get isStaffMessage {
    final role = senderRole.isNotEmpty ? senderRole : sender.role;
    final norm = GasanConstants.normalizeRole(role);
    return norm != 'operator' && norm != 'toda_president' && norm.isNotEmpty;
  }

  /// Strips the `[ANNOUNCEMENT ...]` header tag from broadcast messages for crisp UI cards.
  String get cleanBroadcastBody {
    final trimmed = message.trim();
    final match = RegExp(r'^\[ANNOUNCEMENT[^\]]*\]\s*').firstMatch(trimmed);
    if (match != null) {
      return trimmed.substring(match.end).trim();
    }
    return trimmed;
  }

  ChatMessageItem copyWith({bool? isRead}) {
    return ChatMessageItem(
      id: id,
      threadId: threadId,
      sender: sender,
      senderRole: senderRole,
      message: message,
      targetToda: targetToda,
      targetStatus: targetStatus,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    final rawThread = json['thread'];
    final threadId = rawThread is Map
        ? (rawThread['_id'] ?? rawThread['id'] ?? '').toString().trim()
        : (rawThread ?? json['threadId'] ?? '').toString().trim();
    final senderRole = (json['senderRole'] ?? '').toString().trim();
    final sender = ChatSender.fromDynamic(
      json['sender'],
      fallbackRole: senderRole,
    );

    return ChatMessageItem(
      id: (json['_id'] ?? json['id'] ?? '').toString().trim(),
      threadId: threadId,
      sender: sender,
      senderRole: senderRole.isNotEmpty ? senderRole : sender.role,
      message: sanitizeCivicCopy((json['message'] ?? '').toString().trim()),
      targetToda: (json['targetToda'] ?? 'ALL').toString().trim(),
      targetStatus: (json['targetStatus'] ?? 'ALL').toString().trim(),
      isRead: json['isRead'] == true,
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
    );
  }
}

/// Real-time & stored notification (`GET /api/v1/notifications` & `notification` socket event).
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.type = 'general',
    this.relatedFranchiseId = '',
    this.relatedPlateNo = '',
    this.relatedFranchiseStatus = '',
    this.threadId = '',
    this.isRead = false,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String relatedFranchiseId;
  final String relatedPlateNo;
  final String relatedFranchiseStatus;
  final String threadId;
  final bool isRead;
  final DateTime? createdAt;

  CivicStatusTone get tone {
    switch (type.toLowerCase()) {
      case 'approval':
        return CivicStatusTone.active;
      case 'renewal_reminder':
        return CivicStatusTone.danger;
      case 'status_change':
      case 'chat':
        return CivicStatusTone.inProgress;
      default:
        return CivicStatusTone.neutral;
    }
  }

  String get categoryLabel {
    switch (type.toLowerCase()) {
      case 'approval':
        return 'APPROVAL';
      case 'status_change':
        return 'STATUS';
      case 'renewal_reminder':
        return 'RENEWAL';
      case 'chat':
        return 'MESSAGE';
      case 'system':
        return 'SYSTEM';
      default:
        return 'NOTICE';
    }
  }

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      relatedFranchiseId: relatedFranchiseId,
      relatedPlateNo: relatedPlateNo,
      relatedFranchiseStatus: relatedFranchiseStatus,
      threadId: threadId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final related = json['relatedFranchise'];
    String franchiseId = '';
    String plateNo = '';
    String franchiseStatus = '';
    if (related is Map) {
      final map = Map<String, dynamic>.from(related);
      franchiseId = (map['_id'] ?? map['id'] ?? '').toString().trim();
      plateNo = (map['plateNo'] ?? '').toString().trim();
      franchiseStatus = (map['status'] ?? '').toString().trim();
    } else if (related != null) {
      franchiseId = related.toString().trim();
    }

    final rawThread = json['threadId'];
    final threadId = rawThread is Map
        ? (rawThread['_id'] ?? rawThread['id'] ?? '').toString().trim()
        : (rawThread ?? '').toString().trim();

    return AppNotificationItem(
      id: (json['_id'] ?? json['id'] ?? '').toString().trim(),
      type: (json['type'] ?? 'general').toString().trim().toLowerCase(),
      title: sanitizeCivicCopy((json['title'] ?? 'Official Notice').toString().trim()),
      message: sanitizeCivicCopy((json['message'] ?? '').toString().trim()),
      relatedFranchiseId: franchiseId,
      relatedPlateNo: plateNo,
      relatedFranchiseStatus: franchiseStatus,
      threadId: threadId,
      isRead: json['isRead'] == true,
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
    );
  }
}

/// IT / Helpdesk ticket (`GET /api/v1/tickets/my-tickets`, `POST /api/v1/tickets`).
class SupportTicketItem {
  const SupportTicketItem({
    required this.id,
    required this.subject,
    required this.contactNumber,
    required this.message,
    this.status = 'Open',
    this.adminResponse = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String subject;
  final String contactNumber;
  final String message;
  final String status;
  final String adminResponse;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CivicStatusTone get statusTone {
    switch (status.toLowerCase()) {
      case 'resolved':
        return CivicStatusTone.active;
      case 'in progress':
        return CivicStatusTone.inProgress;
      case 'closed':
        return CivicStatusTone.neutral;
      default:
        return CivicStatusTone.inProgress;
    }
  }

  factory SupportTicketItem.fromJson(Map<String, dynamic> json) {
    return SupportTicketItem(
      id: (json['_id'] ?? json['id'] ?? '').toString().trim(),
      subject: sanitizeCivicCopy((json['subject'] ?? '').toString().trim()),
      contactNumber: (json['contactNumber'] ?? json['contact'] ?? '')
          .toString()
          .trim(),
      message: sanitizeCivicCopy((json['message'] ?? '').toString().trim()),
      status: (json['status'] ?? 'Open').toString().trim(),
      adminResponse:
          sanitizeCivicCopy((json['adminResponse'] ?? '').toString().trim()),
      createdAt: ManilaDateFormatter.tryParseIso(json['createdAt']),
      updatedAt: ManilaDateFormatter.tryParseIso(json['updatedAt']),
    );
  }
}

/// Stored compliance document surfaced in the Operator Document Vault.
class VaultDocumentItem {
  const VaultDocumentItem({
    required this.id,
    required this.title,
    required this.category,
    required this.plateNo,
    required this.unitDesc,
    required this.url,
    required this.franchiseStatus,
    required this.docType,
  });

  final String id;
  final String title;
  final String category;
  final String plateNo;
  final String unitDesc;
  final String url;
  final String franchiseStatus;
  final String docType;

  bool get isPdf => url.toLowerCase().contains('.pdf');
}

/// Flattens uploaded Cloudinary documents across all of an operator's franchises
/// matching the exact Document Vault mapping on G-TRAMS Web.
List<VaultDocumentItem> extractVaultDocuments(List<FranchiseRecord> units) {
  final docs = <VaultDocumentItem>[];
  for (final unit in units) {
    final plate = unit.plateNo.isNotEmpty ? unit.plateNo : 'PENDING PLATE';
    final desc =
        '${unit.make.isNotEmpty ? unit.make : 'Tricycle'} (${unit.made.isNotEmpty ? unit.made : 'Unit'})';

    void addIfPresent(
      String key,
      String title,
      String category,
      String url,
    ) {
      if (url.trim().isEmpty) return;
      docs.add(
        VaultDocumentItem(
          id: '${unit.id}_$key',
          title: title,
          category: category,
          plateNo: plate,
          unitDesc: desc,
          url: url.trim(),
          franchiseStatus: unit.status,
          docType: key,
        ),
      );
    }

    addIfPresent(
      'orCr',
      'Tricycle OR / CR (LTO Registration)',
      'Vehicle Document',
      unit.orCrUrl,
    );
    if (unit.crUrl.isNotEmpty && unit.crUrl != unit.orCrUrl) {
      addIfPresent(
        'cr',
        'Certificate of Registration (LTO CR)',
        'Vehicle Document',
        unit.crUrl,
      );
    }
    if (unit.orUrl.isNotEmpty && unit.orUrl != unit.orCrUrl) {
      addIfPresent(
        'or',
        'Official Receipt (LTO OR)',
        'Vehicle Document',
        unit.orUrl,
      );
    }
    addIfPresent(
      'license',
      "Professional Driver's License (Front)",
      "Driver's Credential",
      unit.licenseUrl,
    );
    addIfPresent(
      'licenseBack',
      "Professional Driver's License (Back)",
      "Driver's Credential",
      unit.licenseBackUrl,
    );
    addIfPresent(
      'cedula',
      'Community Tax Certificate (Cedula / CTC)',
      'LGU Clearance',
      unit.cedulaUrl,
    );
    addIfPresent(
      'brgy',
      'Barangay Clearance (Gasan)',
      'LGU Clearance',
      unit.brgyClearanceUrl,
    );
  }
  return docs;
}

int _parseInt(dynamic val) {
  if (val is int) return val;
  if (val is num) return val.toInt();
  return int.tryParse(val?.toString() ?? '') ?? 0;
}
