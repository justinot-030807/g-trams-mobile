/// Maintains server-authoritative clock synchronization using the `X-Server-Time`
/// header returned by the G-TRAMS Express backend (`Asia/Manila`, UTC+8).
class ServerTimeSync {
  ServerTimeSync._();

  static Duration _serverOffset = Duration.zero;
  static bool _isSynced = false;

  static bool get isSynced => _isSynced;

  static void recordFromHeader(String? isoServerTime) {
    if (isoServerTime == null || isoServerTime.trim().isEmpty) return;
    final parsed = DateTime.tryParse(isoServerTime.trim());
    if (parsed == null) return;
    _serverOffset = parsed.toUtc().difference(DateTime.now().toUtc());
    _isSynced = true;
  }

  static DateTime nowUtc() => DateTime.now().toUtc().add(_serverOffset);

  /// Current authoritative timestamp in `Asia/Manila` (UTC+8).
  static DateTime nowManila() => nowUtc().add(const Duration(hours: 8));
}
