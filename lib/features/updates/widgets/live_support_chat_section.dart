import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/core/network/socket_service.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/features/updates/view_models/updates_controller.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Quick Tagalog FAQ prompts aligned with backend automated instant replies.
const List<({String labelEn, String labelFil, String prompt})>
    _kQuickFaqPrompts = [
  (
    labelEn: 'How to renew?',
    labelFil: 'Paano mag-renew?',
    prompt: 'Paano po mag-renew ng prangkisa?',
  ),
  (
    labelEn: 'New requirements',
    labelFil: 'Requirements ng bago',
    prompt: 'Ano ang requirements para sa bagong prangkisa?',
  ),
  (
    labelEn: 'Payment & claiming',
    labelFil: 'Saan magbabayad / claim?',
    prompt: 'Saan po magbabayad sa cashier at paano mag-claim ng MTOP?',
  ),
];

/// Live Support Chat view backed by Socket.IO (`chat_message`, `chat_typing`, `chat_read`)
/// and `/api/v1/chat/messages`.
class LiveSupportChatSection extends StatefulWidget {
  const LiveSupportChatSection({
    super.key,
    required this.currentUserId,
    required this.state,
    required this.controller,
    required this.strings,
  });

  final String currentUserId;
  final UpdatesState state;
  final UpdatesController controller;
  final AppStrings strings;

  @override
  State<LiveSupportChatSection> createState() => _LiveSupportChatSectionState();
}

class _LiveSupportChatSectionState extends State<LiveSupportChatSection> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void didUpdateWidget(covariant LiveSupportChatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.supportMessages.length >
        oldWidget.state.supportMessages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _msgCtrl.clear();
    final ok = await widget.controller.sendMessage(text);
    if (!ok && preset == null && mounted) {
      _msgCtrl.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final state = widget.state;

    final (connLabel, connTone) = switch (state.connectionStatus) {
      RealtimeConnectionStatus.connected => (
          strings.liveConnected,
          CivicStatusTone.active,
        ),
      RealtimeConnectionStatus.connecting => (
          strings.reconnectingLabel,
          CivicStatusTone.inProgress,
        ),
      RealtimeConnectionStatus.disconnected => (
          strings.offlineStatusLabel,
          CivicStatusTone.neutral,
        ),
    };

    return Column(
      children: [
        // Support Desk Status Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: CivicCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: CivicColors.gasanMaroon,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: CivicColors.purePaper,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.supportDeskTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.pick(
                          'Licensing desk & instant FAQ replies',
                          'Tulong mula sa OVM at instant FAQ',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                CivicStatusBadge(label: connLabel, tone: connTone),
              ],
            ),
          ),
        ),

        if (state.actionError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CivicBanner(
              tone: CivicStatusTone.danger,
              message: state.actionError!,
            ),
          ),

        // Message Feed
        Expanded(
          child: RefreshIndicator(
            color: palette.brandAccent,
            onRefresh: () => widget.controller.loadAll(isPullToRefresh: true),
            child: ListView(
              key: const Key('support_chat_list'),
              controller: _scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              children: [
                if (state.hasMoreSupportMessages)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextButton.icon(
                        onPressed: state.isLoadingEarlier
                            ? null
                            : widget.controller.loadEarlierSupportMessages,
                        icon: state.isLoadingEarlier
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.history_rounded, size: 16),
                        label: Text(strings.loadEarlierMessages),
                      ),
                    ),
                  ),

                if (state.supportMessages.isEmpty)
                  CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.pick(
                            'Start a conversation with OVM — LLSA I',
                            'Magsimula ng mensahe sa OVM — LLSA I',
                          ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.pick(
                            'Ask about renewals, requirements, or cashier payments — or tap a quick question below.',
                            'Magtanong tungkol sa renewal, requirements, o bayarin — o pumili ng tanong sa ibaba.',
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  )
                else
                  ...state.supportMessages.map(
                    (msg) => _ChatMessageBubble(
                      message: msg,
                      isMine: msg.isSentBy(widget.currentUserId),
                      isFil: strings.isFil,
                    ),
                  ),

                if (state.isStaffTyping) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: Text(
                        strings.pick(
                          'OVM — LLSA I Staff is typing...',
                          'Nagta-type ang OVM — LLSA I Staff...',
                        ),
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          color: palette.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Quick Tagalog FAQ Chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _kQuickFaqPrompts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final faq = _kQuickFaqPrompts[index];
              return ActionChip(
                key: Key('chat_faq_chip_$index'),
                backgroundColor: palette.surface,
                side: BorderSide(color: palette.border),
                label: Text(
                  strings.isFil ? faq.labelFil : faq.labelEn,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.ink,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                onPressed: state.isSendingMessage
                    ? null
                    : () => _send(faq.prompt),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // Bottom Sticky Message Composer (48dp minimum height)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat_composer_field'),
                  controller: _msgCtrl,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onChanged: (_) => widget.controller.notifyTyping(),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: strings.typeMessageHint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                width: 48,
                child: ElevatedButton(
                  key: const Key('chat_send_button'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: state.isSendingMessage ? null : () => _send(),
                  child: state.isSendingMessage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CivicColors.purePaper,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMine,
    required this.isFil,
  });

  final ChatMessageItem message;
  final bool isMine;
  final bool isFil;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final bgColor = isMine ? CivicColors.gasanMaroon : palette.surface;
    final textColor = isMine ? CivicColors.purePaper : palette.ink;
    final metaColor = isMine
        ? CivicColors.purePaper.withValues(alpha: 0.78)
        : palette.muted;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          border: isMine ? null : Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                message.isAutoReply
                    ? 'G-TRAMS Guide'
                    : message.sender.displayLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: palette.brandAccent,
                    ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.4,
                  ),
            ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                ManilaDateFormatter.formatTimestamp(
                  message.createdAt,
                  isFil: isFil,
                ),
                style: CivicTheme.monoStyle(
                  fontSize: 9.5,
                  color: metaColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
