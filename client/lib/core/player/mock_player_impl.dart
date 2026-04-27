import 'dart:async';
import 'package:flutter/widgets.dart';
import 'player_controller.dart';

/// Test mock for the player controller.
/// Exposes seekHistory, simulateBufferingStall(), and other helpers for testing.
class MockPlayerImpl implements PlayerController {
  final _eventController = StreamController<PlayerEvent>.broadcast();
  final _positionStreamController = StreamController<Duration>.broadcast();
  final _durationStreamController = StreamController<Duration>.broadcast();

  Duration _position = Duration.zero;
  Duration _duration = const Duration(hours: 2);
  bool _isPlaying = false;
  bool _isBuffering = false;

  /// History of all seek operations for test assertions.
  final List<Duration> seekHistory = [];

  /// History of all play/pause operations.
  final List<String> actionHistory = [];

  @override
  Stream<PlayerEvent> get events => _eventController.stream;

  @override
  Duration get currentPosition => _position;

  @override
  Duration get duration => _duration;

  @override
  Stream<Duration> get positionStream => _positionStreamController.stream;

  @override
  Stream<Duration> get durationStream => _durationStreamController.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isBuffering => _isBuffering;

  @override
  bool get isInitialized => true;

  @override
  Widget? get nativeView => null;

  @override
  Widget? buildVideoView({BoxFit fit = BoxFit.contain}) => null;

  @override
  Future<void> initialize(String streamUrl) async {
    actionHistory.add('initialize:$streamUrl');
    _eventController.add(const PlayerEvent(PlayerEventType.initialized));
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    actionHistory.add('play');
    _eventController.add(
      PlayerEvent(PlayerEventType.playing, position: _position),
    );
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    actionHistory.add('pause');
    _eventController.add(
      PlayerEvent(PlayerEventType.paused, position: _position),
    );
  }

  @override
  Future<void> seekTo(Duration position) async {
    _position = position;
    seekHistory.add(position);
    actionHistory.add('seekTo:${position.inMilliseconds}');
    _eventController.add(
      PlayerEvent(PlayerEventType.seekCompleted, position: position),
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    actionHistory.add('setVolume:$volume');
  }

  /// Set position directly without triggering a seek event.
  void setPosition(Duration position) {
    _position = position;
    _positionStreamController.add(position);
  }

  /// Set total duration.
  void setDuration(Duration d) {
    _duration = d;
    _durationStreamController.add(d);
  }

  /// Simulate a buffering stall.
  void simulateBufferingStall() {
    _isBuffering = true;
    _eventController.add(
      PlayerEvent(PlayerEventType.buffering, position: _position),
    );
  }

  /// Simulate buffering end.
  void simulateBufferingEnd() {
    _isBuffering = false;
    _eventController.add(
      PlayerEvent(PlayerEventType.bufferingEnd, position: _position),
    );
  }

  /// Simulate a player error.
  void simulateError(String message) {
    _eventController.add(
      PlayerEvent(PlayerEventType.error, errorMessage: message),
    );
  }

  @override
  Future<void> dispose() async {
    await _eventController.close();
    await _positionStreamController.close();
    await _durationStreamController.close();
  }
}
