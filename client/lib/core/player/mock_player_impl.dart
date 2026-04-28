import 'dart:async';
import 'package:flutter/widgets.dart';
import 'player_controller.dart';

class MockPlayerImpl implements PlayerController {
  final _eventController = StreamController<PlayerEvent>.broadcast();
  final _positionStreamController = StreamController<Duration>.broadcast();
  final _durationStreamController = StreamController<Duration>.broadcast();
  final _speedStreamController = StreamController<double>.broadcast();
  final _volumeStreamController = StreamController<double>.broadcast();

  Duration _position = Duration.zero;
  Duration _duration = const Duration(hours: 2);
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _lastNonZeroVolume = 1.0;

  final List<Duration> seekHistory = [];

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
  double get playbackSpeed => _playbackSpeed;

  @override
  Stream<double> get playbackSpeedStream => _speedStreamController.stream;

  @override
  double get volume => _volume;

  @override
  double get lastNonZeroVolume => _lastNonZeroVolume;

  @override
  Stream<double> get volumeStream => _volumeStreamController.stream;

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
    final clamped = volume.clamp(0.0, 1.0);
    if (clamped > 0) {
      _lastNonZeroVolume = clamped;
    } else if (_volume > 0) {
      _lastNonZeroVolume = _volume;
    }
    _volume = clamped;
    actionHistory.add('setVolume:$clamped');
    _volumeStreamController.add(clamped);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    actionHistory.add('setPlaybackSpeed:$speed');
    _speedStreamController.add(speed);
  }

  void setPosition(Duration position) {
    _position = position;
    _positionStreamController.add(position);
  }

  void setDuration(Duration d) {
    _duration = d;
    _durationStreamController.add(d);
  }

  void simulateBufferingStall() {
    _isBuffering = true;
    _eventController.add(
      PlayerEvent(PlayerEventType.buffering, position: _position),
    );
  }

  void simulateBufferingEnd() {
    _isBuffering = false;
    _eventController.add(
      PlayerEvent(PlayerEventType.bufferingEnd, position: _position),
    );
  }

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
    await _speedStreamController.close();
    await _volumeStreamController.close();
  }
}
