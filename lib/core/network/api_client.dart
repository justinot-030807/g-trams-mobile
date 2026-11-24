import 'dart:async';
import 'package:dio/dio.dart';
import 'package:gtrams_mobile/core/config/app_config.dart';
import 'package:gtrams_mobile/core/network/server_time_sync.dart';
import 'package:gtrams_mobile/core/storage/secure_session_storage.dart';

/// Structured exception mapped from G-TRAMS backend HTTP error responses.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.advisory,
    this.accountDeactivated = false,
    this.deactivationContact,
    this.deactivationReason,
    this.appealStatus,
    this.hasLocalPassword,
    this.authProvider,
    this.retryAfterSeconds,
    this.isMaintenance = false,
    this.isDeliveryError = false,
    this.rawData,
  });

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? advisory;
  final bool accountDeactivated;
  final String? deactivationContact;
  final String? deactivationReason;
  final String? appealStatus;
  final bool? hasLocalPassword;
  final String? authProvider;
  final int? retryAfterSeconds;
  final bool isMaintenance;
  final bool isDeliveryError;
  final Map<String, dynamic>? rawData;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Centralized Dio HTTP client with Bearer token injection, `X-Server-Time` sync,
/// and Render cold-start retries strictly restricted to idempotent methods.
class ApiClient {
  ApiClient({
    required SecureSessionStorage sessionStorage,
    Dio? dio,
    void Function()? onUnauthorized,
  })  : _sessionStorage = sessionStorage,
        _onUnauthorized = onUnauthorized,
        dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ) {
    _configureInterceptors();
  }

  final SecureSessionStorage _sessionStorage;
  final void Function()? _onUnauthorized;
  final Dio dio;

  static const Set<String> _safeRetryMethods = {'GET', 'HEAD', 'OPTIONS'};
  static const _requestGeneration = 'sessionGeneration';

  bool _isCurrent(RequestOptions options) =>
      options.extra[_requestGeneration] == _sessionStorage.generation;

  static DioException _sessionChanged(RequestOptions options) => DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
        error: const ApiException(message: 'The session changed. Please try again.'),
      );

  void _configureInterceptors() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!options.extra.containsKey(_requestGeneration)) {
            options.extra[_requestGeneration] = _sessionStorage.generation;
            final token = await _sessionStorage.readToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          if (!_isCurrent(options)) return handler.reject(_sessionChanged(options));

          final offlineExpiresAt = _sessionStorage.offlineExpiresAt;
          if (offlineExpiresAt != null && options.headers['Authorization'] != null) {
            final expired = !DateTime.now().toUtc().isBefore(offlineExpiresAt);
            if (expired) _onUnauthorized?.call();
            if (expired || !_safeRetryMethods.contains(options.method.toUpperCase())) {
              return handler.reject(DioException(
                requestOptions: options,
                error: const ApiException(
                  message: 'Reconnect and refresh the Garage before making changes.',
                ),
              ));
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (!_isCurrent(response.requestOptions)) {
            return handler.reject(_sessionChanged(response.requestOptions));
          }
          final serverTime = response.headers.value('x-server-time');
          ServerTimeSync.recordFromHeader(serverTime);
          handler.next(response);
        },
        onError: (err, handler) async {
          if (!_isCurrent(err.requestOptions)) {
            return handler.next(_sessionChanged(err.requestOptions));
          }
          final serverTime = err.response?.headers.value('x-server-time');
          ServerTimeSync.recordFromHeader(serverTime);

          final method = err.requestOptions.method.toUpperCase();
          final canRetry = _safeRetryMethods.contains(method);
          final attempt = (err.requestOptions.extra['_retryAttempt'] as int?) ?? 0;
          final status = err.response?.statusCode;
          final isTransientStatus =
              status == 429 || status == 502 || status == 503 || status == 504;
          final isTransientNetwork =
              err.type == DioExceptionType.connectionTimeout ||
                  err.type == DioExceptionType.receiveTimeout ||
                  err.type == DioExceptionType.connectionError;

          if (canRetry && attempt < 2 && (isTransientStatus || isTransientNetwork)) {
            await Future<void>.delayed(Duration(milliseconds: 750 * (attempt + 1)));
            final retryOptions = err.requestOptions;
            if (!_isCurrent(retryOptions)) {
              return handler.next(_sessionChanged(retryOptions));
            }
            retryOptions.extra['_retryAttempt'] = attempt + 1;
            try {
              final response = await dio.fetch<dynamic>(retryOptions);
              if (!_isCurrent(retryOptions)) {
                return handler.next(_sessionChanged(retryOptions));
              }
              return handler.resolve(response);
            } catch (retryErr) {
              if (retryErr is DioException) {
                return handler.next(retryErr);
              }
            }
          }

          if (status == 401 &&
              err.requestOptions.headers['Authorization'] != null) {
            _onUnauthorized?.call();
          }

          handler.next(err);
        },
      ),
    );
  }

  static ApiException mapDioError(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      if (error.error case final ApiException cause) return cause;
      final response = error.response;
      final status = response?.statusCode;
      final dynamic rawBody = response?.data;
      final map = rawBody is Map<String, dynamic> ? rawBody : <String, dynamic>{};

      var msg = (map['message'] ?? map['error'] ?? '').toString().trim();
      final errors = map['errors'];
      if (errors is List && errors.isNotEmpty) {
        final joined = errors
            .whereType<Map>()
            .map((e) => (e['message'] ?? '').toString().trim())
            .where((s) => s.isNotEmpty)
            .join('. ');
        if (joined.isNotEmpty) msg = joined;
      }

      if (msg.isEmpty) {
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          msg =
              'Connection timed out while waking up the Gasan Municipal Server. Please try again.';
        } else if (error.type == DioExceptionType.connectionError) {
          msg =
              'Cannot connect to the G-TRAMS server. Please check your internet connection.';
        } else {
          msg = 'Something went wrong. Please try again.';
        }
      }

      final advisoryRaw = map['advisory'];
      final advisory = advisoryRaw is Map
          ? Map<String, dynamic>.from(advisoryRaw)
          : null;

      final retryRaw = map['retryAfterSeconds'];
      final retrySeconds = retryRaw is num
          ? retryRaw.toInt()
          : int.tryParse(retryRaw?.toString() ?? '');

      return ApiException(
        message: msg,
        statusCode: status,
        advisory: advisory,
        accountDeactivated: map['accountDeactivated'] == true,
        deactivationContact: map['contact']?.toString(),
        deactivationReason: map['reason']?.toString(),
        appealStatus: map['appealStatus']?.toString(),
        hasLocalPassword: map['hasLocalPassword'] is bool
            ? map['hasLocalPassword'] as bool
            : null,
        authProvider: map['authProvider']?.toString(),
        retryAfterSeconds: retrySeconds,
        isMaintenance: status == 503 &&
            msg.toLowerCase().contains('maintenance'),
        isDeliveryError: status == 503 &&
            !msg.toLowerCase().contains('maintenance'),
        rawData: map.isEmpty ? null : map,
      );
    }

    return ApiException(message: error.toString());
  }
}
