import 'dart:async';
import '../../core/logging/app_logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/signalr_client.dart';
import '../../core/protocol/room_events.dart';
import '../../core/protocol/payloads.dart';






class LatencyEstimator {
  final SignalRClient _signalRClient;
  final AppLogger _logger = AppLogger('LatencyEstimator');
  Timer? _pingTimer;
  bool _running = false;

  
  final List<Timer> _burstTimers = [];

  int _currentRttMs = AppConstants.kDefaultRttMs;
  int get currentRttMs => _currentRttMs;

  
  
  
  int _clockOffsetMs = 0;
  int get clockOffsetMs => _clockOffsetMs;

  
  
  bool _hasFirstMeasurement = false;

  
  void Function(int rttMs)? onRttUpdated;

  
  void Function(int offsetMs)? onClockOffsetUpdated;

  LatencyEstimator({required SignalRClient signalRClient})
      : _signalRClient = signalRClient;

  void start() {
    
    
    if (_running) {
      _logger.d('[LATENCY_ESTIMATOR_ALREADY_RUNNING] start() ignored');
      return;
    }
    _running = true;
    _signalRClient.on(RoomEvents.pong, _onPong);

    
    _sendPing();

    
    for (int i = 1; i <= 2; i++) {
      _burstTimers.add(Timer(Duration(seconds: i), _sendPing));
    }

    
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
    if (!_running) return; 
    final clientTimestampMs = DateTime.now().millisecondsSinceEpoch;
    try {
      _signalRClient.invoke(
        RoomEvents.hubPing,
        args: [clientTimestampMs, _currentRttMs],
      );
    } catch (_) {
      
      
      stop();
    }
  }

  void _onPong(List<Object?>? args) {
    if (args == null || args.isEmpty) return;
    final json = args[0] as Map<String, dynamic>;
    final payload = PongPayload.fromJson(json);
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawRttMs = (now - payload.clientTimestampMs).clamp(0, 2000);

    
    
    
    final rawOffsetMs =
        payload.serverTimestampMs - (payload.clientTimestampMs + rawRttMs ~/ 2);

    if (!_hasFirstMeasurement) {
      
      _currentRttMs = rawRttMs;
      _clockOffsetMs = rawOffsetMs;
      _hasFirstMeasurement = true;
    } else {
      
      _currentRttMs = (AppConstants.kRttSmoothingAlpha * rawRttMs +
              (1.0 - AppConstants.kRttSmoothingAlpha) * _currentRttMs)
          .round();
      _clockOffsetMs = (AppConstants.kRttSmoothingAlpha * rawOffsetMs +
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
