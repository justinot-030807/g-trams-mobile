import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:gtrams_mobile/core/services/bounded_file_read.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';

/// Native Android ML Kit Document Scanner wrapper (auto-crop & glare enhancement).
Future<ScannedDocumentAttachment?> scanWithPlatformMlKit({
  required int maxBytes,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return null;
  }

  final scanner = DocumentScanner(
    options: DocumentScannerOptions(
      documentFormats: const {DocumentFormat.jpeg},
      pageLimit: 1,
      mode: ScannerMode.filter,
      isGalleryImport: true,
    ),
  );

  try {
    final result = await scanner.scanDocument();
    final images = result.images;
    if (images == null || images.isEmpty) return null;

    final filePath = images.first;
    final file = File(filePath);
    if (!await file.exists()) return null;

    final bytes = await readBoundedFile(
      size: await file.length(),
      stream: file.openRead(),
      maxBytes: maxBytes,
    );

    final fileName = filePath.split(Platform.pathSeparator).last;
    return ScannedDocumentAttachment(
      bytes: bytes,
      fileName: fileName.isNotEmpty ? fileName : 'scanned_document.jpg',
      mimeType: 'image/jpeg',
      sourceLabel: 'Smart Scanner',
    );
  } finally {
    await scanner.close();
  }
}
