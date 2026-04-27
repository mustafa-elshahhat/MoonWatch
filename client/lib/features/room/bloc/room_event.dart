import 'package:equatable/equatable.dart';
import '../../../core/protocol/payloads.dart';


sealed class RoomEvent extends Equatable {
  const RoomEvent();

  @override
  List<Object?> get props => [];
}

class RoomEventCreateRoom extends RoomEvent {
  final String? correlationId;
  const RoomEventCreateRoom({this.correlationId});

  @override
  List<Object?> get props => [correlationId];
}

class RoomEventJoinRoom extends RoomEvent {
  final String roomCode;
  final String? correlationId;
  const RoomEventJoinRoom(this.roomCode, {this.correlationId});

  @override
  List<Object?> get props => [roomCode, correlationId];
}

class RoomEventRoomJoined extends RoomEvent {
  final String roomCode;
  final String role;
  final bool guestPresent;
  final IptvContentDescriptor? contentDescriptor;

  const RoomEventRoomJoined({
    required this.roomCode,
    required this.role,
    required this.guestPresent,
    this.contentDescriptor,
  });

  @override
  List<Object?> get props => [roomCode, role, guestPresent, contentDescriptor];
}

class RoomEventSetContent extends RoomEvent {
  final IptvContentDescriptor descriptor;
  const RoomEventSetContent(this.descriptor);

  @override
  List<Object?> get props => [descriptor];
}

class RoomEventContentSet extends RoomEvent {
  final IptvContentDescriptor descriptor;
  const RoomEventContentSet(this.descriptor);

  @override
  List<Object?> get props => [descriptor];
}

class RoomEventGuestJoined extends RoomEvent {
  const RoomEventGuestJoined();
}

class RoomEventGuestLeft extends RoomEvent {
  const RoomEventGuestLeft();
}

class RoomEventGuestReconnected extends RoomEvent {
  const RoomEventGuestReconnected();
}

class RoomEventLocalReady extends RoomEvent {
  final String contentKey;

  const RoomEventLocalReady(this.contentKey);

  @override
  List<Object?> get props => [contentKey];
}

class RoomEventPlayerReady extends RoomEvent {
  final PlayerReadyPayload payload;
  const RoomEventPlayerReady(this.payload);

  @override
  List<Object?> get props => [payload];
}

class RoomEventRoomClosed extends RoomEvent {
  final String reason;
  const RoomEventRoomClosed(this.reason);

  @override
  List<Object?> get props => [reason];
}

class RoomEventLeaveRoom extends RoomEvent {
  const RoomEventLeaveRoom();
}

class RoomEventError extends RoomEvent {
  final String code;
  final String message;
  const RoomEventError({required this.code, required this.message});

  @override
  List<Object?> get props => [code, message];
}
