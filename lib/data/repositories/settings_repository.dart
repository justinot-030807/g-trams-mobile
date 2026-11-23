import 'package:gtrams_mobile/core/network/api_client.dart';
import 'package:gtrams_mobile/data/models/auth_models.dart';

class SettingsRepository {
  SettingsRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  Future<PortalSettings> fetchSettings() async {
    try {
      return await fetchSettingsOrThrow();
    } catch (_) {
      return const PortalSettings();
    }
  }

  Future<PortalSettings> fetchSettingsOrThrow() async {
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/settings');
      if (res.data != null) {
        return PortalSettings.fromJson(res.data!);
      }
      return const PortalSettings();
    } catch (err) {
      throw ApiClient.mapDioError(err);
    }
  }
}
