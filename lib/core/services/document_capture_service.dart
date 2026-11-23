import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/services/mlkit_scanner_stub.dart'
    if (dart.library.io) 'package:gtrams_mobile/core/services/mlkit_scanner_io.dart'
    as mlkit_impl;
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:image_picker/image_picker.dart';

/// Unified, web-safe document capture service:
/// - Android: Google ML Kit Smart Camera Document Scanner + Camera + Gallery + PDF/Image File Picker
/// - Chrome Web / Other: Photo Gallery + JPG/PNG/WEBP/PDF File Picker
class DocumentCaptureService {
  DocumentCaptureService({ImagePicker? imagePicker})
      : _imagePicker = imagePicker ?? ImagePicker();

  static const int maxFileSizeBytes = 15 * 1024 * 1024; // 15MB backend limit

  final ImagePicker _imagePicker;

  bool get supportsSmartCameraScanner =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get supportsDirectCamera =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Launches Google ML Kit Smart Document Scanner on Android (`null` if cancelled/unsupported).
  Future<ScannedDocumentAttachment?> scanWithSmartCamera() async {
    if (!supportsSmartCameraScanner) return null;
    final scanned = await mlkit_impl.scanWithPlatformMlKit();
    if (scanned != null && scanned.sizeBytes > maxFileSizeBytes) {
      throw const FormatException(
        'Scanned image exceeds the 15 MB limit. Please retry with lower resolution.',
      );
    }
    return scanned;
  }

  /// Captures a photo directly from the device camera (`ImagePicker`).
  Future<ScannedDocumentAttachment?> captureFromCamera() async {
    if (!supportsDirectCamera) return null;
    final xfile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException(
        'Captured photo exceeds the 15 MB limit. Please choose a smaller photo.',
      );
    }
    return ScannedDocumentAttachment(
      bytes: bytes,
      fileName: xfile.name.isNotEmpty ? xfile.name : 'camera_capture.jpg',
      mimeType: _inferMime(xfile.name, fallback: 'image/jpeg'),
      sourceLabel: 'Camera',
    );
  }

  /// Picks a photo from the device gallery (`ImagePicker`).
  Future<ScannedDocumentAttachment?> pickFromGallery() async {
    final xfile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (xfile == null) return null;
    final bytes = await xfile.readAsBytes();
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException(
        'Selected image exceeds the 15 MB limit. Please choose a smaller image.',
      );
    }
    return ScannedDocumentAttachment(
      bytes: bytes,
      fileName: xfile.name.isNotEmpty ? xfile.name : 'gallery_photo.jpg',
      mimeType: _inferMime(xfile.name, fallback: 'image/jpeg'),
      sourceLabel: 'Gallery',
    );
  }

  /// Picks a JPG, PNG, WEBP, or PDF file via `file_picker` (works on Android & Chrome Web).
  Future<ScannedDocumentAttachment?> pickDocumentFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'Could not read the selected file. Please pick another image or PDF.',
      );
    }
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException(
        'File exceeds the 15 MB limit. Please select a smaller document.',
      );
    }
    return ScannedDocumentAttachment(
      bytes: bytes,
      fileName: file.name.isNotEmpty ? file.name : 'document.jpg',
      mimeType: _inferMime(file.name, ext: file.extension),
      sourceLabel: 'File',
    );
  }

  /// Picks a TODA roster file (`JPG`, `PNG`, `WEBP`, `PDF`, `XLSX`, or `CSV`, `<=15MB`).
  Future<ScannedDocumentAttachment?> pickRosterFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'xlsx', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException(
        'Could not read the selected roster file. Please choose another file.',
      );
    }
    if (bytes.length > maxFileSizeBytes) {
      throw const FormatException(
        'Roster file exceeds the 15 MB limit. Please select a smaller file.',
      );
    }
    return ScannedDocumentAttachment(
      bytes: bytes,
      fileName: file.name.isNotEmpty ? file.name : 'toda_roster.jpg',
      mimeType: _inferMime(file.name, ext: file.extension),
      sourceLabel: 'Roster File',
    );
  }

  static String _inferMime(String name, {String? ext, String fallback = 'image/jpeg'}) {
    final e = (ext ?? '').toLowerCase();
    final lower = name.toLowerCase();
    if (e == 'pdf' || lower.endsWith('.pdf')) return 'application/pdf';
    if (e == 'xlsx' || lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (e == 'csv' || lower.endsWith('.csv')) return 'text/csv';
    if (e == 'png' || lower.endsWith('.png')) return 'image/png';
    if (e == 'webp' || lower.endsWith('.webp')) return 'image/webp';
    if (e == 'jpg' || e == 'jpeg' || lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return fallback;
  }
}

final Provider<DocumentCaptureService> documentCaptureServiceProvider =
    Provider<DocumentCaptureService>((ref) => DocumentCaptureService());
