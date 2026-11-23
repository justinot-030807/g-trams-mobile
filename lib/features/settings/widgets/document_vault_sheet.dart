import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/communication_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Operator Document Vault displaying stored LGU compliance documents
/// (OR/CR, Driver's License Front/Back, Barangay Clearance, Cedula) across all units.
class DocumentVaultSheet extends StatefulWidget {
  const DocumentVaultSheet({
    super.key,
    required this.documents,
    required this.strings,
    this.onRefresh,
  });

  final List<VaultDocumentItem> documents;
  final AppStrings strings;
  final Future<List<VaultDocumentItem>> Function()? onRefresh;

  @override
  State<DocumentVaultSheet> createState() => _DocumentVaultSheetState();
}

class _DocumentVaultSheetState extends State<DocumentVaultSheet> {
  late List<VaultDocumentItem> _docs;
  bool _isRefreshing = false;
  String _selectedPlate = 'ALL';

  @override
  void initState() {
    super.initState();
    _docs = widget.documents;
  }

  Future<void> _refresh() async {
    if (widget.onRefresh == null || _isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final fresh = await widget.onRefresh!();
      if (mounted) {
        setState(() {
          _docs = fresh;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _openDocument(VaultDocumentItem doc) async {
    if (doc.isPdf) {
      final uri = Uri.tryParse(doc.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.civic.surface,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: ctx.civic.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: Theme.of(ctx)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 14),
                        ),
                        Text(
                          '${doc.plateNo} • ${doc.category}',
                          style: CivicTheme.monoStyle(
                            fontSize: 10,
                            color: ctx.civic.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open externally',
                    onPressed: () {
                      final uri = Uri.tryParse(doc.url);
                      if (uri != null) {
                        launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                  ),
                  IconButton(
                    tooltip: widget.strings.close,
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: ctx.civic.border),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.network(
                  doc.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 240,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (_, _, _) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          size: 36,
                          color: ctx.civic.muted,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.strings.pick(
                            'Preview unavailable offline. Tap open in browser when online.',
                            'Hindi ma-preview habang offline. Buksan sa browser kapag may internet.',
                          ),
                          textAlign: TextAlign.center,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final plates = <String>{'ALL', ..._docs.map((d) => d.plateNo)}.toList();
    final filtered = _selectedPlate == 'ALL'
        ? _docs
        : _docs.where((d) => d.plateNo == _selectedPlate).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      builder: (context, scrollController) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.documentVaultTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          '${_docs.length} ${strings.pick('STORED FILES', 'NAKAIMBAK NA FILE')}',
                          style: CivicTheme.monoStyle(
                            fontSize: 10.5,
                            color: palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onRefresh != null)
                    IconButton(
                      tooltip: strings.pick('Refresh vault', 'I-refresh'),
                      onPressed: _isRefreshing ? null : _refresh,
                      icon: _isRefreshing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (plates.length > 2) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: plates.map((p) {
                      final active = _selectedPlate == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            p == 'ALL'
                                ? strings.pick('All Units', 'Lahat ng Unit')
                                : p,
                          ),
                          selected: active,
                          onSelected: (_) => setState(() => _selectedPlate = p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: CivicCard(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open_rounded,
                                size: 38,
                                color: palette.muted,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.pick(
                                  'No uploaded compliance documents found yet.',
                                  'Wala pang na-upload na dokumento sa iyong vault.',
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.pick(
                                  'Documents submitted in your franchise applications or renewals automatically appear here.',
                                  'Ang mga dokumentong isinumite sa aplikasyon o renewal ay awtomatikong lalabas dito.',
                                ),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('document_vault_list'),
                        controller: scrollController,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          return Material(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: Key('vault_doc_${doc.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openDocument(doc),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: palette.brandAccent
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        doc.isPdf
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.description_outlined,
                                        color: palette.brandAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(fontSize: 14),
                                          ),
                                          const SizedBox(height: 3),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                doc.plateNo.toUpperCase(),
                                                style: CivicTheme.monoStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: palette.brandAccent,
                                                ),
                                              ),
                                              Text(
                                                doc.category,
                                                style: CivicTheme.monoStyle(
                                                  fontSize: 10,
                                                  color: palette.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      doc.isPdf
                                          ? Icons.open_in_new_rounded
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: palette.muted,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
