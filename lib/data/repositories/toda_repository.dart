import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';

/// Repository for TODA President Governance Hub & Public QR Verification.
class TodaRepository {
  TodaRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// `GET /api/v1/toda/my-members`
  Future<TodaMembersDirectory> fetchMyMembers() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/toda/my-members');
      return TodaMembersDirectory.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/toda/next-body-number`
  Future<String> fetchNextBodyNumber({String? todaAssociation}) async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/toda/next-body-number',
        queryParameters: {
          if (todaAssociation != null && todaAssociation.trim().isNotEmpty)
            'todaAssociation': todaAssociation.trim(),
        },
      );
      return (res.data?['nextBodyNumber'] ?? '').toString().trim();
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `POST /api/v1/toda/members/individual`
  Future<String> addIndividualMember({
    required String operatorName,
    String bodyNumber = '',
    String plateNo = '',
    String contact = '',
    String remarks = '',
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/toda/members/individual',
        data: {
          'operatorName': operatorName.trim(),
          if (bodyNumber.trim().isNotEmpty)
            'bodyNumber': bodyNumber.trim().toUpperCase(),
          if (plateNo.trim().isNotEmpty)
            'plateNo': plateNo.trim().toUpperCase(),
          if (contact.trim().isNotEmpty) 'contact': contact.trim(),
          if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        },
      );
      return (res.data?['message'] ?? 'Member added successfully.').toString();
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `POST /api/v1/toda/scan-roster` (JPG/PNG/WEBP/PDF/XLSX/CSV <= 15MB)
  Future<RosterScanResult> scanRosterDocument({
    required ScannedDocumentAttachment file,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.fileName,
          contentType: DioMediaType.parse(
            _inferRosterMime(file.fileName, file.mimeType),
          ),
        ),
      });
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/toda/scan-roster',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return RosterScanResult.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `POST /api/v1/toda/upload` — submits verified roster file + JSON `extractedMembers` to OVM / LLSA I.
  Future<TodaSubmissionRecord> uploadRosterSubmission({
    required ScannedDocumentAttachment file,
    required List<ExtractedRosterMember> extractedMembers,
    String ocrNotes = '',
  }) async {
    try {
      final cleaned = extractedMembers
          .where((m) => m.operatorName.trim().isNotEmpty)
          .map((m) => m.toJson())
          .toList();

      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          file.bytes,
          filename: file.fileName,
          contentType: DioMediaType.parse(
            _inferRosterMime(file.fileName, file.mimeType),
          ),
        ),
        'extractedMembers': jsonEncode(cleaned),
        if (ocrNotes.trim().isNotEmpty) 'ocrNotes': ocrNotes.trim(),
      });

      final res = await _api.dio.post<Map<String, dynamic>>(
        '/toda/upload',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final body = res.data ?? const <String, dynamic>{};
      final rawSub = body['submission'] is Map
          ? Map<String, dynamic>.from(body['submission'] as Map)
          : body;
      return TodaSubmissionRecord.fromJson(rawSub);
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/toda/my-submissions`
  Future<List<TodaSubmissionRecord>> fetchMySubmissions() async {
    try {
      final res = await _api.dio.get<dynamic>('/toda/my-submissions');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (e) =>
                  TodaSubmissionRecord.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      }
      return const [];
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/toda/removal-requests`
  Future<List<TodaRemovalRequestRecord>> fetchRemovalRequests() async {
    try {
      final res = await _api.dio.get<dynamic>('/toda/removal-requests');
      final data = res.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (e) => TodaRemovalRequestRecord.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();
      }
      return const [];
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `POST /api/v1/toda/removal-requests`
  Future<TodaRemovalRequestRecord> submitRemovalRequest({
    required String memberId,
    required String reason,
    required String details,
    String? targetRosterId,
  }) async {
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/toda/removal-requests',
        data: {
          'memberId': memberId.trim(),
          'reason': reason.trim(),
          'details': details.trim(),
          if (targetRosterId != null && targetRosterId.trim().isNotEmpty)
            'targetRosterId': targetRosterId.trim(),
        },
      );
      final body = res.data ?? const <String, dynamic>{};
      final rawReq = body['request'] is Map
          ? Map<String, dynamic>.from(body['request'] as Map)
          : body;
      return TodaRemovalRequestRecord.fromJson(rawReq);
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  /// `GET /api/v1/auth/verify/:id` — public operator/MTOP/plate QR verification endpoint.
  Future<OperatorVerificationResult> verifyOperatorQr(String rawInput) async {
    final id = OperatorVerificationResult.extractVerificationId(rawInput);
    if (id.isEmpty) {
      throw const ApiException(
        message: 'Enter a valid QR verification link, Operator ID, MTOP#, or Plate No.',
      );
    }
    try {
      final encoded = Uri.encodeComponent(id);
      final res = await _api.dio.get<Map<String, dynamic>>(
        '/auth/verify/$encoded',
      );
      return OperatorVerificationResult.fromJson(res.data ?? const {});
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }

  static String _inferRosterMime(String fileName, String? provided) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.csv')) return 'text/csv';
    if (provided != null && provided.contains('/')) return provided;
    return 'image/jpeg';
  }
}
