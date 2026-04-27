import 'dart:async';
import '../../core/logging/app_logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/signalr_client.dart';
import '../../core/protocol/room_events.dart';
import '../../core/protocol/payloads.dart';

/// Sends Ping periodically (every 15s while active), tracks last RTT.
/// On start(), fires an immediate ping burst (3 pings over ~2s) to seed
/// the RTT estimate quickly instead of waiting 15 seconds.
/// Also estimates clock offset between client and server for accurate
/// time-compensation in the sync engine.
class LatencyEstimator {
  final SignalRClient _signalRClient;
  final AppLogger _logger = AppLogger('LatencyEstimator');
  Timer? _pingTimer;
  bool _running = false;

  /// Timers for the initial ping burst (rapid pings at 1s intervals).
  final List<Timer> _burstTimers = [];

  int _currentRttMs = AppConstants.kDefaultRttMs;
  int get currentRttMs => _currentRttMs;

  /// Estimated clock offset: server_clock - client_clock (milliseconds).
  /// Positive means server clock is ahead of client.
  /// Computed as: serverTimestampMs - (clientTimestampMs + rawRttMs / 2).
  int _clockOffsetMs = 0;
  int get clockOffsetMs => _clockOffsetMs;

  /// Whether the first ping response has been received.
  /// The first measurement seeds the smoother directly without blending.
  bool _hasFirstMeasurement = false;

  /// Optional callback invoked whenever RTT is updated.
  void Function(int rttMs)? onRttUpdated;

  /// Optional callback invoked whenever clock offset is updated.
  void Function(int offsetMs)? onClockOffsetUpdated;

  LatencyEstimator({required SignalRClient signalRClient})
    : _signalRClient = signalRClient;

  void start() {
    // Idempotency guard: if already running, ignore the second call.
    // A leaked periodic timer would double the ping rate and double-count RTT.
    if (_running) {
      _logger.d('[LATENCY_ESTIMATOR_ALREADY_RUNNING] start() ignored');
      return;
    }
    _running = true;
    _signalRClient.on(RoomEvents.pong, _onPong);

    // Send first ping immediately to get RTT seeded as fast as possible.
    _sendPing();

    // Send 2 additional burst pings at 1-second intervals for quick convergence.
    for (int i = 1; i <= 2; i++) {
      _burstTimers.add(Timer(Duration(seconds: i), _sendPing));
    }

    // Start the regular periodic timer (15s interval) after the burst completes.
    _pingTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.kPingIntervalMs),
      (_) => _sendPing(),
    );
  }

  void stop() {
    _running = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    for (final t in _burstTimers) {
      t.cancel();
    }
    _burstTimers.clear();
    _signalRClient.off(RoomEvents.pong);
    _hasFirstMeasurement = false;
    _currentRttMs = AppConstants.kDefaultRttMs;
    _clockOffsetMs = 0;
  }

  void _sendPing() {
    if (!_running) return; // already stopped
    final clientTimestampMs = DateTime.now().millisecondsSinceEpoch;
    try {
      _signalRClient.invoke(
        RoomEvents.hubPing,
        args: [clientTimestampMs, _currentRttMs],
      );
    } catch (_) {
      // Connection may have closed between the timer firing and the invoke;
      // stop the timer to avoid repeated errors.
      stop();
    }
  }

  void _onPong(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final json = args[0] as Map<String, dynamic>;
    final payload = PongPayload.fromJson(json);
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawRttMs = (now - payload.clientTimestampMs).clamp(0, 2000);

    // Clock offset estimation: server_clock - client_clock.
    // Uses the standard NTP-style formula: offset = serverTs - (clientTs + rtt/2).
    // Positive means server clock is ahead of client.
    final rawOffsetMs =
        payload.serverTimestampMs - (payload.clientTimestampMs + rawRttMs ~/ 2);

    if (!_hasFirstMeasurement) {
      // Seed with the first real measurement instead of the default.
      _currentRttMs = rawRttMs;
      _clockOffsetMs = rawOffsetMs;
      _hasFirstMeasurement = true;
    } else {
      // Exponential moving average (α = 0.3) to smooth out transient spikes.
      _currentRttMs =
          (AppConstants.kRttSmoothingAlpha * rawRttMs +
                  (1.0 - AppConstants.kRttSmoothingAlpha) * _currentRttMs)
              .round();
      _clockOffsetMs =
          (AppConstants.kRttSmoothingAlpha * rawOffsetMs +
                  (1.0 - AppConstants.kRttSmoothingAlpha) * _clockOffsetMs)
              .round();
    }

    _logger.d(
      'RTT updated: raw=${rawRttMs}ms smoothed=${_currentRttMs}ms '
      'clockOffset: raw=${rawOffsetMs}ms smoothed=${_clockOffsetMs}ms',
    );
    onRttUpdated?.call(_currentRttMs);
    onClockOffsetUpdated?.call(_clockOffsetMs);
  }

  void dispose() {
    stop();
  }
}
