import '../../../core/protocol/payloads.dart';

sealed class RoomRepositoryEvent {
  const RoomRepositoryEvent();
}

class RepoEventRoomJoined extends RoomRepositoryEvent {
  final String roomCode;
  final String role;
  final bool guestPresent;
  final IptvContentDescriptor? contentDescriptor;
  final double playbackRate;

  const RepoEventRoomJoined({
    required this.roomCode,
    required this.role,
    required this.guestPresent,
    this.contentDescriptor,
    this.playbackRate = 1.0,
  });
}

class RepoEventGuestJoined extends RoomRepositoryEvent {
  const RepoEventGuestJoined();
}

class RepoEventGuestLeft extends RoomRepositoryEvent {
  const RepoEventGuestLeft();
}

class RepoEventGuestReconnected extends RoomRepositoryEvent {
  const RepoEventGuestReconnected();
}

class RepoEventContentSet extends RoomRepositoryEvent {
  final IptvContentDescriptor descriptor;
  const RepoEventContentSet(this.descriptor);
}

class RepoEventPlayerReady extends RoomRepositoryEvent {
  final PlayerReadyPayload payload;
  const RepoEventPlayerReady(this.payload);
}

class RepoEventRoomClosed extends RoomRepositoryEvent {
  final String reason;
  const RepoEventRoomClosed(this.reason);
}

class RepoEventError extends RoomRepositoryEvent {
  final String code;
  final String message;
  const RepoEventError({required this.code, required this.message});
}

class RepoEventLocalReady extends RoomRepositoryEvent {
  final String contentKey;
  const RepoEventLocalReady(this.contentKey);
}
