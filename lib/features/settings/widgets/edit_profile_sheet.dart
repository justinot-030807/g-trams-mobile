import 'package:flutter/material.dart';
import 'package:gtrams_mobile/core/l10n/app_strings.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/core/services/document_capture_service.dart';
import 'package:gtrams_mobile/core/theme/civic_colors.dart';
import 'package:gtrams_mobile/core/theme/civic_theme.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/shared/widgets/civic_widgets.dart';

typedef UpdateProfileCallback = Future<MobileUser> Function({
  required String name,
  required String address,
  required String emergencyContact,
  ScannedDocumentAttachment? profilePic,
});

/// Bottom sheet for updating basic operator / TODA president profile & avatar photo
/// (`PUT /api/v1/auth/profile`).
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.user,
    required this.captureService,
    required this.strings,
    required this.onSave,
  });

  final MobileUser user;
  final DocumentCaptureService captureService;
  final AppStrings strings;
  final UpdateProfileCallback onSave;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _emergencyCtrl;

  ScannedDocumentAttachment? _selectedPhoto;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _addressCtrl = TextEditingController(
      text: widget.user.address.isNotEmpty
          ? widget.user.address
          : 'Municipality of Gasan, Marinduque',
    );
    _emergencyCtrl = TextEditingController(text: widget.user.emergencyContact);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(
    Future<ScannedDocumentAttachment?> Function() picker,
  ) async {
    try {
      final picked = await picker();
      if (picked != null && mounted) {
        setState(() {
          _selectedPhoto = picked;
          _error = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final updated = await widget.onSave(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        emergencyContact: _emergencyCtrl.text.trim(),
        profilePic: _selectedPhoto,
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = widget.strings.pick(
          'Unable to update profile right now. Please try again.',
          'Hindi ma-update ang profile ngayon. Pakisubukan muli.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.civic;
    final strings = widget.strings;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
        child: SingleChildScrollView(
          key: const Key('edit_profile_scroll'),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),
                Text(
                  strings.editProfileTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  strings.pick(
                    'Keep your operator name, residential address, emergency contact, and ID photo current.',
                    'Panatilihing tama ang iyong pangalan, tirahan, emergency contact, at larawan sa Digital ID.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),

                // Avatar Preview + Picker
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: CivicColors.gasanMaroon,
                      backgroundImage: _selectedPhoto != null
                          ? MemoryImage(_selectedPhoto!.bytes)
                          : (widget.user.profilePic.isNotEmpty
                              ? NetworkImage(widget.user.profilePic)
                                  as ImageProvider
                              : null),
                      child: (_selectedPhoto == null &&
                              widget.user.profilePic.isEmpty)
                          ? Text(
                              widget.user.name.isNotEmpty
                                  ? widget.user.name[0].toUpperCase()
                                  : 'O',
                              style: const TextStyle(
                                color: CivicColors.purePaper,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            onPressed: _isSaving
                                ? null
                                : () => _pickAvatar(
                                      widget.captureService.pickFromGallery,
                                    ),
                            icon: const Icon(
                              Icons.photo_library_outlined,
                              size: 16,
                            ),
                            label: Text(
                              strings.pick('Choose Photo', 'Pumili ng Larawan'),
                            ),
                          ),
                          if (widget.captureService.supportsDirectCamera)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () => _pickAvatar(
                                        widget.captureService.captureFromCamera,
                                      ),
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 16,
                              ),
                              label: Text(strings.pick('Camera', 'Kamera')),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_error != null) ...[
                  CivicBanner(tone: CivicStatusTone.danger, message: _error!),
                  const SizedBox(height: 12),
                ],

                CivicFieldLabel(text: strings.fullNameLabel, isRequired: true),
                TextFormField(
                  key: const Key('profile_name_field'),
                  controller: _nameCtrl,
                  enabled: !_isSaving,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: strings.fullNameHint),
                  validator: (val) => (val == null || val.trim().length < 2)
                      ? strings.pick(
                          'Enter your full legal name.',
                          'Ilagay ang iyong buong pangalan.',
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick('Residential Address', 'Tirahan'),
                  isRequired: true,
                ),
                TextFormField(
                  key: const Key('profile_address_field'),
                  controller: _addressCtrl,
                  enabled: !_isSaving,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: strings.pick(
                      'Brgy. Barangay, Gasan, Marinduque',
                      'Brgy. Barangay, Gasan, Marinduque',
                    ),
                  ),
                  validator: (val) => (val == null || val.trim().length < 3)
                      ? strings.pick(
                          'Enter your address.',
                          'Ilagay ang iyong tirahan.',
                        )
                      : null,
                ),
                const SizedBox(height: 12),

                CivicFieldLabel(
                  text: strings.pick(
                    'Emergency Contact (Displayed on Digital ID)',
                    'Emergency Contact (Makikita sa Digital ID)',
                  ),
                ),
                TextFormField(
                  key: const Key('profile_emergency_field'),
                  controller: _emergencyCtrl,
                  enabled: !_isSaving,
                  decoration: InputDecoration(
                    hintText: strings.pick(
                      'e.g. Maria Dela Cruz — 09171234567',
                      'hal. Maria Dela Cruz — 09171234567',
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Read-only TODA affiliation summary
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.canvas,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCREDITED AFFILIATION',
                        style: CivicTheme.monoStyle(
                          fontSize: 9.5,
                          color: palette.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.user.todaAssociation}${widget.user.bodyNumber.isNotEmpty ? ' • BODY #${widget.user.bodyNumber}' : ''}',
                        style: CivicTheme.monoStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.pick(
                          'TODA transfers and official roster body numbers are governed by OVM — LLSA I and your TODA President.',
                          'Ang paglipat ng TODA at Body Number ay pinamamahalaan ng OVM — LLSA I at ng iyong TODA President.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                CivicPrimaryButton(
                  key: const Key('profile_save_button'),
                  label: strings.saveChanges,
                  icon: Icons.save_outlined,
                  isLoading: _isSaving,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
