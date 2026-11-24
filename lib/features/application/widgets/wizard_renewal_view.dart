import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/core/utils/manila_date_formatter.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/features/application/view_models/franchise_wizard_controller.dart';
import 'package:gtrams_mobile/features/application/widgets/document_scanner_card.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

/// Streamlined Franchise Renewal view (`PUT /api/v1/franchises/:id/renew`)
/// with current-year Cedula AI OCR auto-fill and optional updated LTO/License/Barangay uploads.
class WizardRenewalView extends StatelessWidget {
  const WizardRenewalView({
    super.key,
    required this.state,
    required this.controller,
    required this.captureService,
    required this.strings,
    required this.renewableUnits,
    required this.franchiseFee,
    required this.cedulaSerialCtrl,
    required this.cedulaAddressCtrl,
    required this.orCrNoCtrl,
    required this.driverLicenseNoCtrl,
    required this.onPickDate,
    required this.onSubmit,
  });

  final FranchiseWizardState state;
  final FranchiseWizardController controller;
  final DocumentCaptureService captureService;
  final AppStrings strings;
  final List<FranchiseRecord> renewableUnits;
  final num franchiseFee;
  final TextEditingController cedulaSerialCtrl;
  final TextEditingController cedulaAddressCtrl;
  final TextEditingController orCrNoCtrl;
  final TextEditingController driverLicenseNoCtrl;
  final Future<void> Function(
    String currentIso,
    ValueChanged<String> onSelected, {
    bool allowFuture,
  }) onPickDate;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final draft = state.draft;
    final targetUnit = state.targetUnitForRenewal ??
        (renewableUnits.isNotEmpty ? renewableUnits.first : null);

    if (targetUnit == null) {
      return CivicCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.autorenew_rounded,
              size: 40,
              color: palette.brandAccent,
            ),
            const SizedBox(height: 12),
            Text(
              strings.pick(
                'No Units Eligible for Renewal Yet',
                'Wala Pang Unit na Pwedeng I-renew',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              strings.pick(
                'Renewal opens automatically when an Active franchise enters its renewal window or expires.',
                'Awtomatikong magbubukas ang renewal kapag malapit nang mag-expire o nag-expire na ang iyong prangkisa.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: () => controller.startNewApplication(),
              child: Text(strings.wizardNewTitle),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector if multiple units can be renewed
        if (renewableUnits.length > 1) ...[
          CivicFieldLabel(
            text: strings.pick(
              'Select Unit to Renew',
              'Piliin ang Unit na Ire-renew',
            ),
            isRequired: true,
          ),
          DropdownButtonFormField<String>(
            initialValue: renewableUnits.any((u) => u.id == targetUnit.id)
                ? targetUnit.id
                : renewableUnits.first.id,
            isExpanded: true,
            items: renewableUnits
                .map(
                  (u) => DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(
                      '${u.plateNo.isNotEmpty ? u.plateNo : 'PENDING'} • ${u.todaName} (${u.status})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              if (id == null) return;
              final found = renewableUnits.firstWhere((u) => u.id == id);
              controller.startRenewal(found);
            },
          ),
          const SizedBox(height: 14),
        ],

        // Target Unit Summary Card
        CivicCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      targetUnit.plateNo.isNotEmpty
                          ? targetUnit.plateNo.toUpperCase()
                          : 'PENDING',
                      style: CivicTheme.monoStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  CivicStatusBadge(
                    label: targetUnit.status,
                    tone: targetUnit.statusTone,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    '${targetUnit.todaName} • ${targetUnit.formattedZone}',
                    style: CivicTheme.monoStyle(fontSize: 11, color: palette.muted),
                  ),
                  if (targetUnit.displayMtopNo.isNotEmpty)
                    Text(
                      'MTOP #${targetUnit.displayMtopNo}',
                      style: CivicTheme.monoStyle(fontSize: 11, color: palette.muted),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${strings.franchiseFeeLabel}: ${ManilaDateFormatter.formatPhp(franchiseFee)} • ${strings.pick('Paid at Cashier after OVM review', 'Babayaran sa Cashier pagkatapos ng OVM')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Required Current-Year Cedula (CTC) Scanner + OCR
        DocumentScannerCard(
          title: strings.pick(
            'Current-Year Cedula (CTC)',
            'Cedula (CTC) para sa Kasalukuyang Taon',
          ),
          subtitle: strings.pick(
            'Auto-fills serial number, issue date, and place.',
            'Auto-fill ng serial number, petsa, at lugar.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: state.attachments['cedulaDoc'],
          existingUrl: draft.existingCedulaUrl,
          isRequired: true,
          isScanning: state.scanningDocKey == 'cedulaDoc',
          ocrFeedback: state.ocrFeedback['cedulaDoc'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'cedulaDoc',
            ocrDocType: 'cedula',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('cedulaDoc'),
        ),
        const SizedBox(height: 14),

        // Cedula Fields Card
        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Cedula (CTC) Details', 'Detalye ng Cedula (CTC)'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(
                text: strings.pick('Cedula Serial / CTC No.', 'Cedula Serial / CTC No.'),
                isRequired: true,
              ),
              TextField(
                key: const Key('renewal_cedula_serial_field'),
                controller: cedulaSerialCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (d) => d.copyWith(cedulaSerialNo: v.trim().toUpperCase()),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. CC12026-0928174',
                  prefixIcon: Icon(Icons.tag_rounded, color: palette.muted),
                ),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(
                text: strings.pick('Date Issued (Current Fiscal Year)', 'Petsa ng Pag-isyu'),
                isRequired: true,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onPickDate(
                  draft.cedulaDate,
                  (iso) => controller.updateDraft(
                    (d) => d.copyWith(
                      cedulaDate: iso,
                      cedulaYear: iso.length >= 4 ? iso.substring(0, 4) : d.cedulaYear,
                    ),
                  ),
                  allowFuture: false,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.calendar_today_outlined, color: palette.muted),
                  ),
                  child: Text(
                    draft.cedulaDate.isNotEmpty
                        ? draft.cedulaDate
                        : strings.pick('Select date', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(fontSize: 13, color: palette.ink),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CivicFieldLabel(
                text: strings.pick('Place Issued', 'Lugar ng Pag-isyu'),
                isRequired: true,
              ),
              TextField(
                controller: cedulaAddressCtrl,
                onChanged: (v) => controller.updateDraft(
                  (d) => d.copyWith(cedulaAddress: v),
                ),
                decoration: const InputDecoration(
                  hintText: 'Gasan, Marinduque',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Optional Updated LTO OR/CR & Driver's License
        DocumentScannerCard(
          title: strings.pick('Updated LTO OR/CR', 'Bagong LTO OR/CR'),
          subtitle: strings.pick(
            'Upload only if renewed with LTO this year.',
            'I-upload lamang kung nag-renew sa LTO.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: state.attachments['orCrDocument'],
          existingUrl: draft.existingOrCrUrl,
          isScanning: state.scanningDocKey == 'orCrDocument',
          ocrFeedback: state.ocrFeedback['orCrDocument'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'orCrDocument',
            ocrDocType: 'orCr',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('orCrDocument'),
        ),
        const SizedBox(height: 12),

        DocumentScannerCard(
          title: strings.pick("Updated Driver's License", "Bagong Driver's License"),
          subtitle: strings.pick(
            'Upload only if your previous license expired.',
            'I-upload lamang kung nag-expire ang lisensya.',
          ),
          captureService: captureService,
          strings: strings,
          attachment: state.attachments['license'],
          existingUrl: draft.existingLicenseUrl,
          isScanning: state.scanningDocKey == 'license',
          ocrFeedback: state.ocrFeedback['license'],
          onFileCaptured: (file) => controller.attachAndScanDocument(
            fieldKey: 'license',
            ocrDocType: 'license',
            file: file,
            isFil: strings.isFil,
          ),
          onRemove: () => controller.removeAttachment('license'),
        ),
        const SizedBox(height: 12),

        CivicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.pick('Optional Document Updates', 'Opsyonal na Update'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 14.5,
                    ),
              ),
              const SizedBox(height: 10),
              CivicFieldLabel(text: strings.pick('LTO OR/CR No.', 'LTO OR/CR No.')),
              TextField(
                controller: orCrNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (d) => d.copyWith(orCrNo: v.trim().toUpperCase()),
                ),
                decoration: const InputDecoration(hintText: 'e.g. 1204-0000089271'),
              ),
              const SizedBox(height: 10),
              CivicFieldLabel(text: strings.pick('LTO OR/CR Expiry Date', 'Petsa ng Pag-expire ng OR/CR')),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onPickDate(
                  draft.orCrExpiryDate,
                  (iso) => controller.updateDraft(
                    (d) => d.copyWith(orCrExpiryDate: iso),
                  ),
                  allowFuture: true,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined, color: palette.muted),
                  ),
                  child: Text(
                    draft.orCrExpiryDate.isNotEmpty
                        ? draft.orCrExpiryDate
                        : strings.pick('Select expiry date', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(
                      fontSize: 13,
                      color: draft.orCrExpiryDate.isNotEmpty
                          ? palette.ink
                          : palette.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              CivicFieldLabel(text: strings.pick("Driver's License No.", "Driver's License No.")),
              TextField(
                controller: driverLicenseNoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => controller.updateDraft(
                  (d) => d.copyWith(driverLicenseNo: v.trim().toUpperCase()),
                ),
                decoration: const InputDecoration(hintText: 'e.g. D02-14-098231'),
              ),
              const SizedBox(height: 10),
              CivicFieldLabel(text: strings.pick("Driver's License Expiry Date", 'Petsa ng Pag-expire ng Lisensya')),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onPickDate(
                  draft.driverLicenseExpiryDate,
                  (iso) => controller.updateDraft(
                    (d) => d.copyWith(driverLicenseExpiryDate: iso),
                  ),
                  allowFuture: true,
                ),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.event_outlined, color: palette.muted),
                  ),
                  child: Text(
                    draft.driverLicenseExpiryDate.isNotEmpty
                        ? draft.driverLicenseExpiryDate
                        : strings.pick('Select expiry date', 'Piliin ang petsa'),
                    style: CivicTheme.monoStyle(
                      fontSize: 13,
                      color: draft.driverLicenseExpiryDate.isNotEmpty
                          ? palette.ink
                          : palette.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        CivicPrimaryButton(
          key: const Key('renewal_submit_button'),
          label: strings.submitRenewal,
          icon: Icons.autorenew_rounded,
          isLoading: state.isSubmitting,
          onPressed: state.isScanningAny ? null : onSubmit,
        ),
      ],
    );
  }
}
