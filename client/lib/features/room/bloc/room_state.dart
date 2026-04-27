import 'package:equatable/equatable.dart';
import '../../../core/protocol/payloads.dart';
import '../domain/room_error_code.dart';

enum PeerStatus { connected, buffering, away }

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
