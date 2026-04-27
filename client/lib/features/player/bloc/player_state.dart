import 'package:equatable/equatable.dart';

/// PlayerBloc states per STATE_MANAGEMENT.md.
sealed class PlayerState extends Equatable {
  const PlayerState();

  @override
  List<Object?> get props => [];
}

class PlayerStateIdle extends PlayerState {
  const PlayerStateIdle();
}

class PlayerStateLoading extends PlayerState {
  const PlayerStateLoading();
}

class PlayerStateReady extends PlayerState {
  const PlayerStateReady();
}

class PlayerStatePlaying extends PlayerState {
  final Duration position;
  const PlayerStatePlaying(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerStatePaused extends PlayerState {
  final Duration position;
  const PlayerStatePaused(this.position);

  @override
  List<Object?> get props => [position];
}

class PlayerStateBuffering extends PlayerState {
  final Duration lastKnownPosition;
  const PlayerStateBuffering(this.lastKnownPosition);

  @override
  List<Object?> get props => [lastKnownPosition];
}

class PlayerStateError extends PlayerState {
  final String message;
  final bool recoverable;
  const PlayerStateError(this.message, {this.recoverable = false});

  @override
  List<Object?> get props => [message, recoverable];
}

class PlayerStateEnded extends PlayerState {
  const PlayerStateEnded();
}
