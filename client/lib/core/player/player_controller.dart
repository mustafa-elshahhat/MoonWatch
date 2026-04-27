import 'dart:async';
import 'package:flutter/widgets.dart';


enum PlayerEventType {
  initialized,
  playing,
  paused,
  buffering,
  bufferingEnd,
  seekCompleted,
  ended,
  error,
}

class PlayerEvent {
  final PlayerEventType type;
  final Duration? position;
  final String? errorMessage;

  const PlayerEvent(this.type, {this.position, this.errorMessage});
}


abstract class PlayerController {
  
  Stream<PlayerEvent> get events;

  
  Stream<Duration> get positionStream;

  
  Stream<Duration> get durationStream;

  
  Duration get currentPosition;

  
  Duration get duration;

  
  bool get isPlaying;

  
  bool get isBuffering;

  
  bool get isInitialized;

  
  
  Widget? get nativeView;

  
  
  
  Widget? buildVideoView({BoxFit fit = BoxFit.contain});

  
  Future<void> initialize(String streamUrl);

  
  Future<void> play();

  
  Future<void> pause();

  
  Future<void> seekTo(Duration position);

  
  Future<void> setVolume(double volume);

  
  Future<void> dispose();
}
