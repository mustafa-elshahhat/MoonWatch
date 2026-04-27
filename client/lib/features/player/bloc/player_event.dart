import 'package:equatable/equatable.dart';

sealed class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

class PlayerEventInitialize extends PlayerEvent {
  final String streamUrl;

  final String? source;

  final bool isRoomMode;
  final String? roomCode;
  final String? role;
  final String? contentKey;

  const PlayerEventInitialize(
    this.streamUrl, {
    this.source,
    this.isRoomMode = false,
    this.roomCode,
    this.role,
    this.contentKey,
  });

  @override
  List<Object?> get props => [
        streamUrl,
        source,
        isRoomMode,
        roomCode,
        role,
        contentKey,
      ];
}

class PlayerEventPlay extends PlayerEvent {
  const PlayerEventPlay();
}

class PlayerEventPause extends PlayerEvent {
  const PlayerEventPause();
}

class PlayerEventSeek extends PlayerEvent {
  final Duration target;
  const PlayerEventSeek(this.target);

  @override
  List<Object?> get props => [target];
}

class PlayerEventBufferingStarted extends PlayerEvent {
  const PlayerEventBufferingStarted();
}

class PlayerEventBufferingConfirmed extends PlayerEvent {
  const PlayerEventBufferingConfirmed();
}

class PlayerEventBufferingEnded extends PlayerEvent {
  const PlayerEventBufferingEnded();
}

class PlayerEventErrorOccurred extends PlayerEvent {
  final String message;
  final bool recoverable;
  const PlayerEventErrorOccurred(this.message, {this.recoverable = false});

  @override
  List<Object?> get props => [message, recoverable];
}

class PlayerEventStreamEnded extends PlayerEvent {
  const PlayerEventStreamEnded();
}

class PlayerEventDispose extends PlayerEvent {
  const PlayerEventDispose();
}
