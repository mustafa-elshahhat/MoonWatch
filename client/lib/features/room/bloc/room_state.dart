import 'package:equatable/equatable.dart';
import '../../../core/protocol/payloads.dart';

enum PeerStatus { connected, buffering, away }

enum RoomErrorCode {
  roomNotFound,
  roomFull,
  roomClosed,
  roleInvalid,
  roleUnauthorized,
  alreadyJoined,
  streamUrlInvalid,
  internalError,
}

extension RoomErrorCodeX on RoomErrorCode {
  static RoomErrorCode fromString(String code) {
    return switch (code) {
      'room_not_found' => RoomErrorCode.roomNotFound,
      'room_full' => RoomErrorCode.roomFull,
      'room_closed' => RoomErrorCode.roomClosed,
      'role_invalid' => RoomErrorCode.roleInvalid,
      'role_unauthorized' => RoomErrorCode.roleUnauthorized,
      'already_joined' => RoomErrorCode.alreadyJoined,
      'stream_url_invalid' => RoomErrorCode.streamUrlInvalid,
      _ => RoomErrorCode.internalError,
    };
  }

  String toSnakeCase() {
    return switch (this) {
      RoomErrorCode.roomNotFound => 'room_not_found',
      RoomErrorCode.roomFull => 'room_full',
      RoomErrorCode.roomClosed => 'room_closed',
      RoomErrorCode.roleInvalid => 'role_invalid',
      RoomErrorCode.roleUnauthorized => 'role_unauthorized',
      RoomErrorCode.alreadyJoined => 'already_joined',
      RoomErrorCode.streamUrlInvalid => 'stream_url_invalid',
      RoomErrorCode.internalError => 'internal_error',
    };
  }
}

sealed class RoomState extends Equatable {
  const RoomState();

  @override
  List<Object?> get props => [];
}

class RoomStateInitial extends RoomState {
  const RoomStateInitial();
}

class RoomStateConnecting extends RoomState {
  const RoomStateConnecting();
}

class RoomStateCreating extends RoomState {
  const RoomStateCreating();
}

class RoomStateWaiting extends RoomState {
  final String roomCode;
  final String role;

  const RoomStateWaiting({required this.roomCode, required this.role});

  @override
  List<Object?> get props => [roomCode, role];
}

class RoomStateJoined extends RoomState {
  final String roomCode;
  final String role;
  final bool contentSet;

  const RoomStateJoined({
    required this.roomCode,
    required this.role,
    this.contentSet = false,
  });

  @override
  List<Object?> get props => [roomCode, role, contentSet];
}

class RoomStateActive extends RoomState {
  final String roomCode;
  final String role;
  final IptvContentDescriptor contentDescriptor;
  final PeerStatus peerStatus;
  final bool localReady;
  final bool peerReady;

  bool get bothReady => localReady && peerReady;
  String get contentKey => contentDescriptor.contentKey;

  const RoomStateActive({
    required this.roomCode,
    required this.role,
    required this.contentDescriptor,
    this.peerStatus = PeerStatus.connected,
    this.localReady = false,
    this.peerReady = false,
  });

  RoomStateActive copyWith({
    IptvContentDescriptor? contentDescriptor,
    PeerStatus? peerStatus,
    bool? localReady,
    bool? peerReady,
  }) =>
      RoomStateActive(
        roomCode: roomCode,
        role: role,
        contentDescriptor: contentDescriptor ?? this.contentDescriptor,
        peerStatus: peerStatus ?? this.peerStatus,
        localReady: localReady ?? this.localReady,
        peerReady: peerReady ?? this.peerReady,
      );

  @override
  List<Object?> get props => [
        roomCode,
        role,
        contentDescriptor,
        peerStatus,
        localReady,
        peerReady,
      ];
}

class RoomStateClosed extends RoomState {
  final String reason;
  const RoomStateClosed(this.reason);

  @override
  List<Object?> get props => [reason];
}

class RoomStateError extends RoomState {
  final RoomErrorCode code;
  final String message;
  const RoomStateError({required this.code, required this.message});

  @override
  List<Object?> get props => [code, message];
}
