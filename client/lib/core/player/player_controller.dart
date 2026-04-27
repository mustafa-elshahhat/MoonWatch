import 'dart:async';
import 'package:flutter/widgets.dart';

/// Player events emitted by the player abstraction.
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

/// Abstract player interface .
abstract class PlayerController {
  /// Stream of player events.
  Stream<PlayerEvent> get events;

  /// Stream of playback position changes.
  Stream<Duration> get positionStream;

  /// Stream of media duration changes.
  Stream<Duration> get durationStream;

  /// Current playback position.
  Duration get currentPosition;

  /// Total duration of the media.
  Duration get duration;

  /// Whether the player is currently playing.
  bool get isPlaying;

  /// Whether the player is currently buffering.
  bool get isBuffering;

  /// Whether the player has been initialized with media.
  bool get isInitialized;

  /// Platform-specific video view widget, if available.
  /// Returns null if player is not initialized.
  Widget? get nativeView;

  /// Build the video view widget with the specified [fit] mode.
  /// Purely a presentation/rendering change — does not affect playback logic.
  /// Returns null if player is not initialized.
  Widget? buildVideoView({BoxFit fit = BoxFit.contain});

  /// Initialize the player with a stream URL.
  Future<void> initialize(String streamUrl);

  /// Start or resume playback.
  Future<void> play();

  /// Pause playback.
  Future<void> pause();

  /// Seek to a specific position.
  Future<void> seekTo(Duration position);

  /// Set playback volume (0.0 = mute, 1.0 = full).
  Future<void> setVolume(double volume);

  /// Dispose of player resources.
  Future<void> dispose();
}
