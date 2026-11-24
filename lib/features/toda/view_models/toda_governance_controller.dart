import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/data/models/application_wizard_models.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';
import 'package:gtrams_mobile/data/models/toda_models.dart';
import 'package:gtrams_mobile/data/repositories/toda_repository.dart';
import 'package:gtrams_mobile/features/auth/view_models/auth_controller.dart';

final Provider<TodaRepository> todaRepositoryProvider =
    Provider<TodaRepository>((ref) {
  return TodaRepository(apiClient: ref.watch(apiClientProvider));
});

enum TodaHubSection { directory, rosterScan, removals, qrVerifier }

class TodaGovernanceState {
  const TodaGovernanceState({
    this.section = TodaHubSection.directory,
    this.directory = const TodaMembersDirectory(todaName: ''),
    this.submissions = const [],
    this.removalRequests = const [],
    this.searchQuery = '',
    this.isLoading = true,
    this.isRefreshing = false,
    this.errorMessage,
    // AI OCR Roster Scan / Editor state
    this.selectedRosterFile,
    this.isScanningRoster = false,
    this.isUploadingRoster = false,
    this.rosterMembers = const [],
    this.rosterOcrNotes = '',
    this.rosterFeedbackMessage,
    this.rosterFeedbackIsError = false,
    // QR Verifier state
    this.isVerifyingQr = false,
    this.verificationResult,
    this.verificationError,
    this.lastVerifiedInput = '',
  });

  final TodaHubSection section;
  final TodaMembersDirectory directory;
  final List<TodaSubmissionRecord> submissions;
  final List<TodaRemovalRequestRecord> removalRequests;
  final String searchQuery;
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;

  final ScannedDocumentAttachment? selectedRosterFile;
  final bool isScanningRoster;
  final bool isUploadingRoster;
  final List<ExtractedRosterMember> rosterMembers;
  final String rosterOcrNotes;
  final String? rosterFeedbackMessage;
  final bool rosterFeedbackIsError;

  final bool isVerifyingQr;
  final OperatorVerificationResult? verificationResult;
  final String? verificationError;
  final String lastVerifiedInput;

  List<TodaMemberProfile> get filteredMembers {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return directory.members;
    return directory.members.where((m) {
      return m.name.toLowerCase().contains(q) ||
          m.bodyNumber.toLowerCase().contains(q) ||
          m.primaryPlateNo.toLowerCase().contains(q) ||
          m.contact.toLowerCase().contains(q) ||
          m.units.any((u) => u.plateNo.toLowerCase().contains(q));
    }).toList();
  }

  int get pendingRemovalsCount =>
      removalRequests.where((r) => r.status == 'Pending').length;

  TodaGovernanceState copyWith({
    TodaHubSection? section,
    TodaMembersDirectory? directory,
    List<TodaSubmissionRecord>? submissions,
    List<TodaRemovalRequestRecord>? removalRequests,
    String? searchQuery,
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    bool clearError = false,
    ScannedDocumentAttachment? selectedRosterFile,
    bool clearRosterFile = false,
    bool? isScanningRoster,
    bool? isUploadingRoster,
    List<ExtractedRosterMember>? rosterMembers,
    String? rosterOcrNotes,
    String? rosterFeedbackMessage,
    bool clearRosterFeedback = false,
    bool? rosterFeedbackIsError,
    bool? isVerifyingQr,
    OperatorVerificationResult? verificationResult,
    bool clearVerificationResult = false,
    String? verificationError,
    bool clearVerificationError = false,
    String? lastVerifiedInput,
  }) {
    return TodaGovernanceState(
      section: section ?? this.section,
      directory: directory ?? this.directory,
      submissions: submissions ?? this.submissions,
      removalRequests: removalRequests ?? this.removalRequests,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedRosterFile: clearRosterFile
          ? null
          : (selectedRosterFile ?? this.selectedRosterFile),
      isScanningRoster: isScanningRoster ?? this.isScanningRoster,
      isUploadingRoster: isUploadingRoster ?? this.isUploadingRoster,
      rosterMembers: rosterMembers ?? this.rosterMembers,
      rosterOcrNotes: rosterOcrNotes ?? this.rosterOcrNotes,
      rosterFeedbackMessage: clearRosterFeedback
          ? null
          : (rosterFeedbackMessage ?? this.rosterFeedbackMessage),
      rosterFeedbackIsError:
          rosterFeedbackIsError ?? this.rosterFeedbackIsError,
      isVerifyingQr: isVerifyingQr ?? this.isVerifyingQr,
      verificationResult: clearVerificationResult
          ? null
          : (verificationResult ?? this.verificationResult),
      verificationError: clearVerificationError
          ? null
          : (verificationError ?? this.verificationError),
      lastVerifiedInput: lastVerifiedInput ?? this.lastVerifiedInput,
    );
  }
}

class TodaGovernanceController extends StateNotifier<TodaGovernanceState> {
  TodaGovernanceController({
    required TodaRepository repository,
    required MobileUser? user,
  })  : _repo = repository,
        _user = user,
        super(
          TodaGovernanceState(
            directory: TodaMembersDirectory(
              todaName: user?.todaAssociation ?? '',
            ),
            isLoading: user?.isTodaPresident == true,
          ),
        ) {
    if (_user?.isTodaPresident == true) {
      loadHubData();
    }
  }

  final TodaRepository _repo;
  final MobileUser? _user;

  void setSection(TodaHubSection section) {
    if (state.section == section) return;
    state = state.copyWith(section: section);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> loadHubData({bool isPullToRefresh = false}) async {
    if (_user == null || !_user.isTodaPresident) {
      state = state.copyWith(isLoading: false, isRefreshing: false);
      return;
    }

    state = state.copyWith(
      isLoading: !isPullToRefresh && state.directory.members.isEmpty,
      isRefreshing: isPullToRefresh,
      clearError: true,
    );

    try {
      final results = await Future.wait([
        _repo.fetchMyMembers(),
        _repo.fetchMySubmissions().then<List<TodaSubmissionRecord>>(
              (v) => v,
              onError: (_) => state.submissions,
            ),
        _repo.fetchRemovalRequests().then<List<TodaRemovalRequestRecord>>(
              (v) => v,
              onError: (_) => state.removalRequests,
            ),
      ]);

      if (!mounted) return;
      state = state.copyWith(
        directory: results[0] as TodaMembersDirectory,
        submissions: results[1] as List<TodaSubmissionRecord>,
        removalRequests: results[2] as List<TodaRemovalRequestRecord>,
        isLoading: false,
        isRefreshing: false,
        clearError: true,
      );
    } catch (err) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: ApiClient.mapDioError(err).message,
      );
    }
  }

  Future<String> fetchNextBodyNumber() {
    return _repo.fetchNextBodyNumber(
      todaAssociation: state.directory.todaName.isNotEmpty
          ? state.directory.todaName
          : _user?.todaAssociation,
    );
  }

  Future<String> addIndividualMember({
    required String operatorName,
    String bodyNumber = '',
    String plateNo = '',
    String contact = '',
    String remarks = '',
  }) async {
    final msg = await _repo.addIndividualMember(
      operatorName: operatorName,
      bodyNumber: bodyNumber,
      plateNo: plateNo,
      contact: contact,
      remarks: remarks,
    );
    await loadHubData(isPullToRefresh: true);
    return msg;
  }

  /// Attaches a roster file and runs AI OCR extraction (`POST /toda/scan-roster`).
  Future<void> scanRosterFile(ScannedDocumentAttachment file) async {
    state = state.copyWith(
      selectedRosterFile: file,
      isScanningRoster: true,
      clearRosterFeedback: true,
      rosterFeedbackIsError: false,
    );

    try {
      final res = await _repo.scanRosterDocument(file: file);
      if (!mounted) return;

      if (res.success && res.extractedMembers.isNotEmpty) {
        state = state.copyWith(
          isScanningRoster: false,
          rosterMembers: res.extractedMembers,
          rosterOcrNotes: res.ocrNotes,
          rosterFeedbackMessage:
              'AI OCR extracted ${res.extractedCount} member(s). Review or edit rows below before submitting to OVM — LLSA I.',
          rosterFeedbackIsError: false,
        );
      } else {
        state = state.copyWith(
          isScanningRoster: false,
          rosterMembers: const [],
          rosterOcrNotes: res.ocrNotes,
          rosterFeedbackMessage: res.message.isNotEmpty
              ? res.message
              : 'No members auto-detected. You can add member rows manually below before uploading.',
          rosterFeedbackIsError: true,
        );
      }
    } catch (err) {
      if (!mounted) return;
      state = state.copyWith(
        isScanningRoster: false,
        rosterFeedbackMessage: ApiClient.mapDioError(err).message,
        rosterFeedbackIsError: true,
      );
    }
  }

  void addRosterRow({
    required String operatorName,
    String bodyNumber = '',
    String plateNo = '',
  }) {
    final cleanName = operatorName.trim();
    if (cleanName.isEmpty) return;
    final next = [
      ...state.rosterMembers,
      ExtractedRosterMember(
        operatorName: cleanName,
        bodyNumber: bodyNumber.trim().toUpperCase(),
        plateNo: plateNo.trim().toUpperCase(),
        confidence: 1.0,
      ),
    ];
    state = state.copyWith(rosterMembers: next, clearRosterFeedback: true);
  }

  void updateRosterRow(int index, ExtractedRosterMember updated) {
    if (index < 0 || index >= state.rosterMembers.length) return;
    final next = List<ExtractedRosterMember>.from(state.rosterMembers);
    next[index] = updated;
    state = state.copyWith(rosterMembers: next);
  }

  void removeRosterRow(int index) {
    if (index < 0 || index >= state.rosterMembers.length) return;
    final next = List<ExtractedRosterMember>.from(state.rosterMembers)
      ..removeAt(index);
    state = state.copyWith(rosterMembers: next);
  }

  void clearRosterDraft() {
    state = state.copyWith(
      clearRosterFile: true,
      rosterMembers: const [],
      rosterOcrNotes: '',
      clearRosterFeedback: true,
      rosterFeedbackIsError: false,
    );
  }

  /// Submits the scanned/edited roster to OVM — LLSA I (`POST /toda/upload`).
  Future<TodaSubmissionRecord?> submitRosterToOvm() async {
    final file = state.selectedRosterFile;
    if (file == null) {
      state = state.copyWith(
        rosterFeedbackMessage: 'Please scan or select a TODA roster document first.',
        rosterFeedbackIsError: true,
      );
      return null;
    }

    final validMembers = state.rosterMembers
        .where((m) => m.operatorName.trim().isNotEmpty)
        .toList();
    if (validMembers.isEmpty) {
      state = state.copyWith(
        rosterFeedbackMessage:
            'Add at least 1 valid member row before submitting to OVM — LLSA I.',
        rosterFeedbackIsError: true,
      );
      return null;
    }

    state = state.copyWith(
      isUploadingRoster: true,
      clearRosterFeedback: true,
      rosterFeedbackIsError: false,
    );

    try {
      final sub = await _repo.uploadRosterSubmission(
        file: file,
        extractedMembers: validMembers,
        ocrNotes: state.rosterOcrNotes,
      );
      await loadHubData(isPullToRefresh: true);
      if (!mounted) return sub;
      state = state.copyWith(
        isUploadingRoster: false,
        clearRosterFile: true,
        rosterMembers: const [],
        rosterOcrNotes: '',
        rosterFeedbackMessage:
            'Roster submitted to Office of the Municipal Vice Mayor (OVM) — LLSA I (${sub.extractedCount} members).',
        rosterFeedbackIsError: false,
      );
      return sub;
    } catch (err) {
      if (!mounted) return null;
      state = state.copyWith(
        isUploadingRoster: false,
        rosterFeedbackMessage: ApiClient.mapDioError(err).message,
        rosterFeedbackIsError: true,
      );
      return null;
    }
  }

  Future<void> submitRemovalRequest({
    required String memberId,
    required String reason,
    required String details,
    String? targetRosterId,
  }) async {
    await _repo.submitRemovalRequest(
      memberId: memberId,
      reason: reason,
      details: details,
      targetRosterId: targetRosterId,
    );
    await loadHubData(isPullToRefresh: true);
  }

  /// Verifies an operator QR payload (`https://g-trams-official.vercel.app/verify/:id`),
  /// MTOP number, or Plate number via `GET /api/v1/auth/verify/:id`.
  Future<void> verifyQrPayload(String rawPayload) async {
    final cleaned = rawPayload.trim();
    if (cleaned.isEmpty) {
      state = state.copyWith(
        verificationError:
            'Scan a Digital Operator ID QR or enter a Plate / MTOP / Verify URL.',
        clearVerificationResult: true,
      );
      return;
    }

    state = state.copyWith(
      isVerifyingQr: true,
      lastVerifiedInput: cleaned,
      clearVerificationError: true,
    );

    try {
      final res = await _repo.verifyOperatorQr(cleaned);
      if (!mounted) return;
      state = state.copyWith(
        isVerifyingQr: false,
        verificationResult: res,
        clearVerificationError: true,
      );
    } catch (err) {
      if (!mounted) return;
      state = state.copyWith(
        isVerifyingQr: false,
        clearVerificationResult: true,
        verificationError: ApiClient.mapDioError(err).message,
      );
    }
  }

  void clearVerification() {
    state = state.copyWith(
      clearVerificationResult: true,
      clearVerificationError: true,
      lastVerifiedInput: '',
    );
  }
}

final StateNotifierProvider<TodaGovernanceController, TodaGovernanceState>
    todaGovernanceControllerProvider =
    StateNotifierProvider<TodaGovernanceController, TodaGovernanceState>((ref) {
  final user = ref.watch(authControllerProvider.select((s) => s.user));
  return TodaGovernanceController(
    repository: ref.watch(todaRepositoryProvider),
    user: user,
  );
});
