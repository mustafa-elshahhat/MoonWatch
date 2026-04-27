class AppConstants {
  AppConstants._();

  static const String kServerBaseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
  );
  static const String kSignalRHubPath = '/hubs/room';

  static const int kDriftThresholdMs = 400;
  static const int kStateSyncIntervalMs = 5000;
  static const int kDefaultRttMs = 100;
  static const int kMaxCorrectionSeeksPerWindow = 3;
  static const int kCorrectionSeekWindowMs = 10000;

  static const int kGuestGracePeriodMs = 30000;
  static const int kRoomCodeLength = 6;

  static const int kBufferingStallTimeoutMs = 60000;

  static const List<int> kReconnectDelaysMs = [0, 2000, 5000, 10000, 20000];

  static const int kPingIntervalMs = 15000;

  static const double kRttSmoothingAlpha = 0.3;

  static bool get hasServerBaseUrl => kServerBaseUrl.isNotEmpty;

  static void requireServerBaseUrl() {
    if (!hasServerBaseUrl) {
      throw StateError(
        'SERVER_BASE_URL is not configured. '
        'Supply --dart-define=SERVER_BASE_URL=<url> at build time.',
      );
    }
  }
}
