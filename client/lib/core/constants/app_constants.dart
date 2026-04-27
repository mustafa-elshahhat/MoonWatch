/// Shared constants for sync, room, buffering, reconnect, and latency configuration.
///
/// Runtime values are injected at build time via --dart-define:
///   SERVER_BASE_URL, IPTV_BASE_URL, IPTV_USERNAME, IPTV_PASSWORD
class AppConstants {
  AppConstants._();

  // Server connection — supply SERVER_BASE_URL via --dart-define at build time.
  static const String kServerBaseUrl =
      String.fromEnvironment('SERVER_BASE_URL');
  static const String kSignalRHubPath = '/hubs/room';

  // Sync engine thresholds
  static const int kDriftThresholdMs = 400;
  static const int kStateSyncIntervalMs = 5000;
  static const int kDefaultRttMs = 100;
  static const int kMaxCorrectionSeeksPerWindow = 3;
  static const int kCorrectionSeekWindowMs = 10000;

  // Room settings
  static const int kGuestGracePeriodMs = 30000;
  static const int kRoomCodeLength = 6;

  // Buffering
  static const int kBufferingStallTimeoutMs = 60000;

  // Reconnect policy delays in ms
  static const List<int> kReconnectDelaysMs = [0, 2000, 5000, 10000, 20000];

  // Latency estimator
  static const int kPingIntervalMs = 15000;

  /// EMA smoothing factor for RTT (α). Range 0.0–1.0.
  /// Lower = smoother but slower to react; higher = more reactive but noisier.
  static const double kRttSmoothingAlpha = 0.3;
}
