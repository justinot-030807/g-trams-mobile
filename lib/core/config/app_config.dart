/// Runtime configuration for G-TRAMS Mobile.
///
/// Override at build or run time with:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000`
class AppConfig {
  AppConfig._();

  static const String productionApiUrl = 'https://g-trams-web2.onrender.com';
  static const String webPortalUrl = 'https://g-trams-official.vercel.app';
  static const String apiPrefix = '/api/v1';

  static const String _rawApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: productionApiUrl,
  );

  static const String defaultGoogleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '371606618285-og7vq7cn9gb0kpacq171fhf1jclvlhgq.apps.googleusercontent.com',
  );

  /// Normalizes the configured origin and rejects legacy workers.dev proxies.
  static String get apiOrigin {
    final cleaned = _rawApiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (cleaned.isEmpty || cleaned.contains('workers.dev')) {
      return productionApiUrl;
    }
    return cleaned;
  }

  static String get apiBaseUrl => '$apiOrigin$apiPrefix';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 45);
}
