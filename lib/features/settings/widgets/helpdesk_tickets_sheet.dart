import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

typedef FetchMyTicketsCallback = Future<List<SupportTicketItem>> Function();
typedef CreateTicketCallback = Future<SupportTicketItem> Function({
  required String subject,
  required String contactNumber,
  required String message,
});

/// Helpdesk Tickets (`GET /api/v1/tickets/my-tickets`, `POST /api/v1/tickets`)
/// and Official Municipality of Gasan OVM — LLSA I Hotlines sheet.
class HelpdeskTicketsSheet extends StatefulWidget {
  const HelpdeskTicketsSheet({
    super.key,
    required this.user,
    required this.strings,
    required this.onFetchTickets,
    required this.onCreateTicket,
  });

  final MobileUser user;
  final AppStrings strings;
  final FetchMyTicketsCallback onFetchTickets;
  final CreateTicketCallback onCreateTicket;

  @override
  State<HelpdeskTicketsSheet> createState() => _HelpdeskTicketsSheetState();
}

class _HelpdeskTicketsSheetState extends State<HelpdeskTicketsSheet> {
  String _tab = 'tickets'; // 'tickets' | 'hotlines'
  final _subjectCtrl = TextEditingController();
  late final TextEditingController _contactCtrl;
  final _messageCtrl = TextEditingController();

  List<SupportTicketItem> _tickets = const [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _contactCtrl = TextEditingController(
      text: widget.user.contact.isNotEmpty
          ? widget.user.contact
          : widget.user.email,
    );
    _loadTickets();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _contactCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.onFetchTickets();
      if (!mounted) return;
      setState(() {
        _tickets = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _submitTicket() async {
    if (_isSubmitting) return;
    final subject = _subjectCtrl.text.trim();
    final contactNumber = _contactCtrl.text.trim();
    final message = _messageCtrl.text.trim();

    if (subject.length < 3 || contactNumber.isEmpty || message.length < 10) {
      setState(() {
        _error = widget.strings.pick(
          'Enter a clear subject, contact number/email, and details (at least 10 characters).',
          'Maglagay ng malinaw na paksa, contact, at detalye (hindi bababa sa 10 karakter).',
        );
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final created = await widget.onCreateTicket(
        subject: subject,
        contactNumber: contactNumber,
        message: message,
      );
      if (!mounted) return;
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() {
        _isSubmitting = false;
        _tickets = [created, ..._tickets];
        _successMessage = widget.strings.pick(
          'Support ticket submitted! Our technical support team has been notified.',
          'Naipadala na ang iyong support ticket! Makakatanggap ka ng tugon sa app.',
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + bottomInset),
          child: ListView(
            key: const Key('helpdesk_sheet_list'),
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.helpdeskTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),

              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'tickets',
                    label: Text(
                      strings.pick('Support Tickets', 'Support Tickets'),
                    ),
                    icon: const Icon(Icons.confirmation_number_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: 'hotlines',
                    label: Text(
                      strings.pick('LGU Hotlines', 'LGU Hotlines'),
                    ),
                    icon: const Icon(Icons.account_balance_outlined, size: 16),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (sel) => setState(() => _tab = sel.first),
              ),
              const SizedBox(height: 14),

              if (_tab == 'hotlines')
                _LguHotlinesPanel(strings: strings)
              else ...[
                // New Ticket Form Card
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.submitTicketAction,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.pick(
                          'Report technical issues, account concerns, or franchise record discrepancies directly to G-TRAMS IT Support.',
                          'Mag-ulat ng teknikal na problema o concern sa iyong account direkta sa G-TRAMS Support.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),

                      if (_error != null) ...[
                        CivicBanner(
                          tone: CivicStatusTone.danger,
                          message: _error!,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (_successMessage != null) ...[
                        CivicBanner(
                          tone: CivicStatusTone.active,
                          message: _successMessage!,
                        ),
                        const SizedBox(height: 10),
                      ],

                      CivicFieldLabel(
                        text: strings.pick('Subject / Concern', 'Paksa'),
                        isRequired: true,
                      ),
                      TextField(
                        key: const Key('ticket_subject_field'),
                        controller: _subjectCtrl,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          hintText: strings.pick(
                            'e.g. Cannot upload OR/CR photo',
                            'hal. Hindi ma-upload ang OR/CR',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      CivicFieldLabel(
                        text: strings.pick(
                          'Active Contact Number / Email',
                          'Aktibong Numero o Email',
                        ),
                        isRequired: true,
                      ),
                      TextField(
                        key: const Key('ticket_contact_field'),
                        controller: _contactCtrl,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          hintText: '09XXXXXXXXX',
                        ),
                      ),
                      const SizedBox(height: 10),

                      CivicFieldLabel(
                        text: strings.pick(
                          'Issue Details',
                          'Detalye ng Problema',
                        ),
                        isRequired: true,
                      ),
                      TextField(
                        key: const Key('ticket_message_field'),
                        controller: _messageCtrl,
                        enabled: !_isSubmitting,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: strings.pick(
                            'Describe the issue, Plate#, or MTOP# involved...',
                            'Ipaliwanag ang problema, Plaka, o MTOP#...',
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      CivicPrimaryButton(
                        key: const Key('ticket_submit_button'),
                        label: strings.submitTicketAction,
                        icon: Icons.send_outlined,
                        isLoading: _isSubmitting,
                        onPressed: _submitTicket,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Past Tickets List
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.pick(
                          'MY SUBMITTED TICKETS (${_tickets.length})',
                          'AKING MGA SUPPORT TICKET (${_tickets.length})',
                        ),
                        style: CivicTheme.monoStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: palette.muted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: strings.pick('Refresh tickets', 'I-refresh'),
                      onPressed: _isLoading ? null : _loadTickets,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_tickets.isEmpty)
                  CivicCard(
                    child: Text(
                      strings.pick(
                        'You have no submitted support tickets yet.',
                        'Wala ka pang naisumiteng support ticket.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  ..._tickets.map(
                    (ticket) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CivicCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket.subject,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontSize: 14.5),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CivicStatusBadge(
                                  label: ticket.status,
                                  tone: ticket.statusTone,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ticket.message,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: palette.ink.withValues(alpha: 0.85),
                                    height: 1.4,
                                  ),
                            ),
                            if (ticket.adminResponse.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: palette.canvas,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'OFFICIAL SUPPORT RESPONSE',
                                      style: CivicTheme.monoStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: palette.brandAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      ticket.adminResponse,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (ticket.createdAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                ManilaDateFormatter.formatTimestamp(
                                  ticket.createdAt,
                                  isFil: strings.isFil,
                                ),
                                style: CivicTheme.monoStyle(
                                  fontSize: 9.5,
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LguHotlinesPanel extends StatelessWidget {
  const _LguHotlinesPanel({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;

    return Column(
      children: [
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OFFICE OF THE MUNICIPAL VICE MAYOR (OVM)',
                style: CivicTheme.monoStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.brandAccent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.pick(
                  'Local Legislative Staff Assistant I (LLSA I) — Tricycle Franchising Desk',
                  'Local Legislative Staff Assistant I (LLSA I) — Tanggapan ng Prangkisa',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                strings.pick(
                  '2nd Floor, Sangguniang Bayan / Municipal Hall, Poblacion, Gasan, Marinduque\nOffice Hours: Monday – Friday, 8:00 AM – 5:00 PM (PST)',
                  '2nd Floor, Sangguniang Bayan / Munisipyo ng Gasan, Marinduque\nOras ng Opisina: Lunes – Biyernes, 8:00 AM – 5:00 PM',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MUNICIPAL TREASURER / CASHIER',
                style: CivicTheme.monoStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: palette.brandAccent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.pick(
                  'Franchise & Renewal Payment Window',
                  'Window ng Bayaran ng Prangkisa at Renewal',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                strings.pick(
                  'Ground Floor, Gasan Municipal Hall. Present your approved application or plate number to obtain your Official Receipt (OR#).',
                  'Ground Floor, Munisipyo ng Gasan. Ipakita ang aprubadong aplikasyon o plaka para makakuha ng Official Receipt (OR#).',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final uri = Uri.tryParse(AppConfig.webPortalUrl);
              if (uri != null) {
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.public_rounded, size: 18),
            label: Text(
              strings.pick(
                'Open Official G-TRAMS Web Portal',
                'Buksan ang Opisyal na G-TRAMS Web Portal',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
