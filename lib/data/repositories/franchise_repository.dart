import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/franchise_models.dart';
import 'package:gtrams_mobile/data/models/violation_models.dart';

/// Repository for Operator / TODA President franchise fleet, violations,
/// application withdrawal, and voluntary cancellation workflows.
class FranchiseRepository {
  FranchiseRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// `GET /api/v1/franchises/my-franchises`
  Future<List<FranchiseRecord>> fetchMyFranchises() async {
    try {
      final res = await _api.dio.get<dynamic>('/franchises/my-franchises');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => FranchiseRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => FranchiseRecord.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return const [];
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/franchises/:id`
  Future<FranchiseRecord> fetchFranchiseById(String franchiseId) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/franchises/$franchiseId',
      );
      return FranchiseRecord.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/violations/history/:franchiseId`
  Future<ViolationHistoryResponse> fetchViolationHistory(
    String franchiseId,
  ) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/violations/history/$franchiseId',
      );
      return ViolationHistoryResponse.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Withdraws an unpaid pending application (`PUT /api/v1/franchises/:id/cancel`).
  Future<FranchiseRecord> withdrawPendingApplication({
    required String franchiseId,
    required String cancelReason,
  }) async {
    try {
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/franchises/$franchiseId/cancel',
        data: {'cancelReason': cancelReason.trim()},
      );
      return FranchiseRecord.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Submits a voluntary franchise surrender / cancellation request
  /// (`PUT /api/v1/franchises/:id/request-cancellation`).
  ///
  /// Supports either a typed formal letter (`letterText >= 30 chars`) OR
  /// an uploaded photo/PDF letter (`cancellationLetter <= 10MB`), working on
  /// both Android and Chrome Web via `MultipartFile.fromBytes`.
  Future<FranchiseRecord> requestVoluntaryCancellation({
    required String franchiseId,
    required String reason,
    String customReason = '',
    String remarks = '',
    String? letterText,
    Uint8List? fileBytes,
    String? fileName,
    String? mimeType,
  }) async {
    try {
      final map = <String, dynamic>{
        'reason': reason.trim(),
        'customReason': customReason.trim(),
        'remarks': remarks.trim(),
      };

      if (fileBytes != null && fileBytes.isNotEmpty) {
        final resolvedName =
            (fileName == null || fileName.trim().isEmpty)
                ? 'cancellation_letter.jpg'
                : fileName.trim();
        final resolvedMime = _inferMimeType(resolvedName, mimeType);
        map['cancellationLetter'] = MultipartFile.fromBytes(
          fileBytes,
          filename: resolvedName,
          contentType: DioMediaType.parse(resolvedMime),
        );
      } else if (letterText != null && letterText.trim().isNotEmpty) {
        map['letterText'] = letterText.trim();
      }

      final formData = FormData.fromMap(map);
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/franchises/$franchiseId/request-cancellation',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final body = res.data ?? const <String, dynamic>{};
      final rawFranchise = body['franchise'] is Map
          ? Map<String, dynamic>.from(body['franchise'] as Map)
          : body;
      return FranchiseRecord.fromJson(rawFranchise);
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Real-time duplicate check (`GET /api/v1/franchises/check-unique`).
  Future<UniqueFieldCheckResult> checkUniqueField({
    required String field,
    required String value,
    String? excludeId,
  }) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/franchises/check-unique',
        queryParameters: {
          'field': field,
          'value': value.trim(),
          if (excludeId != null && excludeId.trim().isNotEmpty)
            'excludeId': excludeId.trim(),
        },
      );
      return UniqueFieldCheckResult.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Real-time TODA jurisdiction check (`GET /api/v1/franchises/check-toda-member`).
  Future<TodaJurisdictionCheckResult> checkTodaJurisdiction({
    required String todaName,
    required String barangay,
  }) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/franchises/check-toda-member',
        queryParameters: {
          'todaName': todaName.trim(),
          'barangay': barangay.trim(),
        },
      );
      return TodaJurisdictionCheckResult.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Runs 3-Tier AI OCR (`POST /api/v1/franchises/scan-document`) and returns
  /// RA 10173-sanitized extracted fields (graceful fallback if unreadable).
  Future<OcrScanResult> scanDocument({
    required ScannedDocumentAttachment file,
    required String docType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'docType': docType,
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.fileName,
          contentType: DioMediaType.parse(
            _inferMimeType(file.fileName, file.mimeType),
          ),
        ),
      });
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/franchises/scan-document',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return OcrScanResult.fromJson(
        res.data ?? const {},
        fallbackDocType: docType,
      );
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Submits a brand-new 5-Step franchise application (`POST /api/v1/franchises`).
  Future<FranchiseRecord> submitNewFranchise({
    required FranchiseWizardDraft draft,
    required Map<String, ScannedDocumentAttachment> attachments,
  }) async {
    try {
      final formData = _buildApplicationFormData(draft, attachments);
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/franchises',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return FranchiseRecord.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Resubmits a corrected rejected/pending application (`PUT /api/v1/franchises/:id`).
  Future<FranchiseRecord> updateFranchiseApplication({
    required String franchiseId,
    required FranchiseWizardDraft draft,
    required Map<String, ScannedDocumentAttachment> attachments,
  }) async {
    try {
      final formData = _buildApplicationFormData(draft, attachments);
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/franchises/$franchiseId',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return FranchiseRecord.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// Submits a franchise renewal (`PUT /api/v1/franchises/:id/renew`).
  Future<FranchiseRecord> renewFranchise({
    required String franchiseId,
    required FranchiseWizardDraft draft,
    required Map<String, ScannedDocumentAttachment> attachments,
  }) async {
    try {
      final map = <String, dynamic>{
        'ctcNo': draft.cedulaSerialNo.trim(),
        'dateIssued': draft.cedulaDate.trim(),
        'placeIssued': draft.cedulaAddress.trim(),
        'cedulaSerialNo': draft.cedulaSerialNo.trim(),
        'cedulaDate': draft.cedulaDate.trim(),
        'cedulaAddress': draft.cedulaAddress.trim(),
        'dateApplied': DateTime.now().toUtc().toIso8601String(),
        if (draft.orCrNo.trim().isNotEmpty) 'orCrNo': draft.orCrNo.trim(),
        if (draft.orCrExpiryDate.trim().isNotEmpty)
          'orCrExpiryDate': draft.orCrExpiryDate.trim(),
        if (draft.driverLicenseNo.trim().isNotEmpty)
          'driverLicenseNo': draft.driverLicenseNo.trim(),
        if (draft.driverLicenseExpiryDate.trim().isNotEmpty)
          'driverLicenseExpiryDate': draft.driverLicenseExpiryDate.trim(),
        if (draft.brgyClearanceNo.trim().isNotEmpty)
          'brgyClearanceNo': draft.brgyClearanceNo.trim(),
        if (draft.brgyClearanceDate.trim().isNotEmpty)
          'brgyClearanceDate': draft.brgyClearanceDate.trim(),
      };

      void attach(String key, String fieldName) {
        final file = attachments[key];
        if (file == null || file.bytes.isEmpty) return;
        map[fieldName] = MultipartFile.fromBytes(
          file.bytes,
          filename: file.fileName,
          contentType: DioMediaType.parse(
            _inferMimeType(file.fileName, file.mimeType),
          ),
        );
      }

      attach('cedulaDoc', 'cedulaDoc');
      attach('orCrDocument', 'orcrFile');
      attach('crDocument', 'crDocument');
      attach('orDocument', 'orDocument');
      attach('license', 'license');
      attach('licenseBack', 'licenseBack');
      attach('brgyClearance', 'brgyClearance');

      final res = await _api.dio.put<Map<String, dynamic>>(
        '/franchises/$franchiseId/renew',
        data: FormData.fromMap(map),
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final body = res.data ?? const <String, dynamic>{};
      final rawFranchise = body['franchise'] is Map
          ? Map<String, dynamic>.from(body['franchise'] as Map)
          : body;
      return FranchiseRecord.fromJson(rawFranchise);
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  FormData _buildApplicationFormData(
    FranchiseWizardDraft draft,
    Map<String, ScannedDocumentAttachment> attachments,
  ) {
    final map = <String, dynamic>{
      'fullName': draft.fullName.trim(),
      'address': draft.fullAddress,
      'zone': draft.zone.trim(),
      'todaName': draft.todaName.trim(),
      if (draft.bodyNumber.trim().isNotEmpty)
        'bodyNumber': draft.bodyNumber.trim().toUpperCase(),
      'plateNo': draft.plateNo.trim().toUpperCase(),
      'make': draft.make.trim(),
      'made': draft.made.trim(),
      'motorNo': draft.motorNo.trim().toUpperCase(),
      'chassisNo': draft.chassisNo.trim().toUpperCase(),
      if (draft.color.trim().isNotEmpty) 'color': draft.color.trim().toUpperCase(),
      if (draft.series.trim().isNotEmpty) 'series': draft.series.trim(),
      if (draft.crNo.trim().isNotEmpty) 'crNo': draft.crNo.trim(),
      if (draft.orNo.trim().isNotEmpty) 'orNo': draft.orNo.trim(),
      if (draft.orCrNo.trim().isNotEmpty) 'orCrNo': draft.orCrNo.trim(),
      if (draft.orCrExpiryDate.trim().isNotEmpty)
        'orCrExpiryDate': draft.orCrExpiryDate.trim(),
      if (draft.fileNo.trim().isNotEmpty) 'fileNo': draft.fileNo.trim(),
      'isOperatorDriver': draft.isOperatorDriver.toString(),
      'driverName': (draft.isOperatorDriver
              ? draft.fullName
              : draft.driverName)
          .trim(),
      if (draft.driverContact.trim().isNotEmpty)
        'driverContact': draft.driverContact.trim(),
      if (draft.driverLicenseNo.trim().isNotEmpty)
        'driverLicenseNo': draft.driverLicenseNo.trim().toUpperCase(),
      if (draft.driverLicenseSerialNo.trim().isNotEmpty)
        'driverLicenseSerialNo': draft.driverLicenseSerialNo.trim().toUpperCase(),
      if (draft.driverLicenseExpiryDate.trim().isNotEmpty)
        'driverLicenseExpiryDate': draft.driverLicenseExpiryDate.trim(),
      if (draft.driverDlCodes.trim().isNotEmpty)
        'driverDlCodes': draft.driverDlCodes.trim(),
      if (draft.driverConditions.trim().isNotEmpty)
        'driverConditions': draft.driverConditions.trim(),
      if (draft.driverAddress.trim().isNotEmpty)
        'driverAddress': draft.driverAddress.trim(),
      if (draft.brgyClearanceNo.trim().isNotEmpty)
        'brgyClearanceNo': draft.brgyClearanceNo.trim(),
      if (draft.brgyClearanceDate.trim().isNotEmpty)
        'brgyClearanceDate': draft.brgyClearanceDate.trim(),
      'cedulaSerialNo': draft.cedulaSerialNo.trim().toUpperCase(),
      'cedulaDate': draft.cedulaDate.trim(),
      'cedulaAddress': draft.cedulaAddress.trim(),
      if (draft.cedulaYear.trim().isNotEmpty) 'cedulaYear': draft.cedulaYear.trim(),
      'cedulaPlaceIssued': draft.cedulaAddress.trim(),
      if (draft.cedulaFullName.trim().isNotEmpty)
        'cedulaFullName': draft.cedulaFullName.trim(),
      if (draft.cedulaCitizenship.trim().isNotEmpty)
        'cedulaCitizenship': draft.cedulaCitizenship.trim(),
      if (draft.cedulaCivilStatus.trim().isNotEmpty)
        'cedulaCivilStatus': draft.cedulaCivilStatus.trim(),
      if (draft.cedulaProfession.trim().isNotEmpty)
        'cedulaProfession': draft.cedulaProfession.trim(),
      if (draft.cedulaTin.trim().isNotEmpty) 'cedulaTin': draft.cedulaTin.trim(),
      'applicationType': 'New',
      'dateApplied': DateTime.now().toUtc().toIso8601String(),
      if (draft.aiScannedDocs.isNotEmpty)
        'aiScannedData': jsonEncode(draft.aiScannedDocs),
    };

    // Preserve trusted server URLs for Fix & Reapply when user did not re-upload
    if (draft.mode == WizardFlowMode.fixReapply) {
      if (draft.existingOrCrUrl.isNotEmpty) map['orCrUrl'] = draft.existingOrCrUrl;
      if (draft.existingCrUrl.isNotEmpty) map['crUrl'] = draft.existingCrUrl;
      if (draft.existingOrUrl.isNotEmpty) map['orUrl'] = draft.existingOrUrl;
      if (draft.existingLicenseUrl.isNotEmpty) {
        map['licenseUrl'] = draft.existingLicenseUrl;
      }
      if (draft.existingLicenseBackUrl.isNotEmpty) {
        map['licenseBackUrl'] = draft.existingLicenseBackUrl;
      }
      if (draft.existingBrgyClearanceUrl.isNotEmpty) {
        map['brgyClearanceUrl'] = draft.existingBrgyClearanceUrl;
      }
      if (draft.existingCedulaUrl.isNotEmpty) {
        map['cedulaUrl'] = draft.existingCedulaUrl;
      }
    }

    // Attach newly scanned/uploaded documents (note: NO TODA Endorsement upload)
    for (final entry in attachments.entries) {
      final file = entry.value;
      if (file.bytes.isEmpty) continue;
      map[entry.key] = MultipartFile.fromBytes(
        file.bytes,
        filename: file.fileName,
        contentType: DioMediaType.parse(
          _inferMimeType(file.fileName, file.mimeType),
        ),
      );
    }

    return FormData.fromMap(map);
  }

  static String _inferMimeType(String fileName, String? provided) {
    if (provided != null && provided.contains('/')) return provided;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
