import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/signalr_client.dart';
import '../../../core/protocol/room_events.dart';
import '../domain/room_error_code.dart';
import '../repository/room_repository.dart';
import 'room_event.dart';
import 'room_state.dart';

class RoomBloc extends Bloc<RoomEvent, RoomState> {
  final RoomRepository _roomRepository;
  final SignalRClient _signalRClient;
  final AppLogger _logger = AppLogger('RoomBloc');

  StreamSubscription? _repoSubscription;
  Completer<void>? _joinCompleter;
  Timer? _timeoutTimer;

  RoomBloc({
    required RoomRepository roomRepository,
    required SignalRClient signalRClient,
  })  : _roomRepository = roomRepository,
        _signalRClient = signalRClient,
        super(const RoomStateInitial()) {
    on<RoomEventCreateRoom>(_onCreateRoom);
    on<RoomEventJoinRoom>(_onJoinRoom);
    on<RoomEventRoomJoined>(_onRoomJoined);
    on<RoomEventSetContent>(_onSetContent);
    on<RoomEventContentSet>(_onContentSet);
    on<RoomEventGuestJoined>(_onGuestJoined);
    on<RoomEventGuestLeft>(_onGuestLeft);
    on<RoomEventGuestReconnected>(_onGuestReconnected);
    on<RoomEventLocalReady>(_onLocalReady);
    on<RoomEventPlayerReady>(_onPlayerReady);
    on<RoomEventRoomClosed>(_onRoomClosed);
    on<RoomEventLeaveRoom>(_onLeaveRoom);
    on<RoomEventError>(_onError);
  }

  static bool _matchesActiveContent(RoomStateActive state, String contentKey) =>
      state.contentKey == contentKey;

  void _completePendingRoomOperation() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (_joinCompleter != null && !_joinCompleter!.isCompleted) {
      _joinCompleter!.complete();
    }
    _joinCompleter = null;
  }

  void startListening() {
    _repoSubscription?.cancel();
    _repoSubscription = _roomRepository.events.listen((event) {
      if (!isClosed) add(event);
    });
  }

  Future<void> _onCreateRoom(
    RoomEventCreateRoom event,
    Emitter<RoomState> emit,
  ) async {
    if (isClosed) return;
    emit(const RoomStateConnecting());

    try {
      await _signalRClient.ensureConnected();
      if (isClosed) return;

      emit(const RoomStateCreating());
      _roomRepository.registerHandlers();
      startListening();

      final completer = Completer<void>();
      _joinCompleter = completer;

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Room creation timed out.'),
          );
        }
      });

      await _signalRClient.invoke(RoomEvents.hubCreateRoom);
      await completer.future;
      _completePendingRoomOperation();
    } catch (e) {
      if (isClosed) return;
      _completePendingRoomOperation();
      _roomRepository.unregisterHandlers();
      _repoSubscription?.cancel();
      _repoSubscription = null;
      if (e is TimeoutException) {
        emit(
          const RoomStateError(
            code: RoomErrorCode.internalError,
            message: 'Room creation timed out.',
          ),
        );
      } else {
        emit(
          RoomStateError(
            code: RoomErrorCode.internalError,
            message: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> _onJoinRoom(
    RoomEventJoinRoom event,
    Emitter<RoomState> emit,
  ) async {
    if (isClosed) return;
    emit(const RoomStateConnecting());

    try {
      await _signalRClient.ensureConnected();
      if (isClosed) return;

      emit(const RoomStateCreating());
      _roomRepository.registerHandlers();
      startListening();

      final completer = Completer<void>();
      _joinCompleter = completer;

      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Room join timed out.'),
          );
        }
      });

      await _signalRClient.invoke(
        RoomEvents.hubJoinRoom,
        args: [event.roomCode, 'guest'],
      );
      await completer.future;
      _completePendingRoomOperation();
    } catch (e) {
      if (isClosed) return;
      _completePendingRoomOperation();
      _roomRepository.unregisterHandlers();
      _repoSubscription?.cancel();
      _repoSubscription = null;
      if (e is TimeoutException) {
        emit(
          const RoomStateError(
            code: RoomErrorCode.internalError,
            message: 'Room join timed out.',
          ),
        );
      } else {
        emit(
          RoomStateError(
            code: RoomErrorCode.internalError,
            message: e.toString(),
          ),
        );
      }
    }
  }

  void _onRoomJoined(RoomEventRoomJoined event, Emitter<RoomState> emit) {
    if (isClosed) return;
    _completePendingRoomOperation();

    if (event.guestPresent && event.contentDescriptor != null) {
      emit(
        RoomStateActive(
          roomCode: event.roomCode,
          role: event.role,
          contentDescriptor: event.contentDescriptor!,
        ),
      );
    } else if (event.guestPresent) {
      emit(RoomStateJoined(roomCode: event.roomCode, role: event.role));
    } else {
      emit(RoomStateWaiting(roomCode: event.roomCode, role: event.role));
    }
  }

  Future<void> _onSetContent(
    RoomEventSetContent event,
    Emitter<RoomState> emit,
  ) async {
    if (isClosed) return;
    try {
      await _signalRClient.invoke(
        RoomEvents.hubSetContent,
        args: [event.descriptor.toJson()],
      );
      final current = state;
      if (current is RoomStateJoined) {
        emit(
          RoomStateActive(
            roomCode: current.roomCode,
            role: current.role,
            contentDescriptor: event.descriptor,
          ),
        );
      } else if (current is RoomStateWaiting) {
        emit(
          RoomStateActive(
            roomCode: current.roomCode,
            role: current.role,
            contentDescriptor: event.descriptor,
          ),
        );
      } else if (current is RoomStateActive) {
        emit(
          RoomStateActive(
            roomCode: current.roomCode,
            role: current.role,
            contentDescriptor: event.descriptor,
            peerStatus: current.peerStatus,
            localReady: false,
            peerReady: false,
          ),
        );
      }
    } catch (e) {
      if (isClosed) return;
      emit(
        const RoomStateError(
          code: RoomErrorCode.internalError,
          message: 'Failed to set content.',
        ),
      );
    }
  }

  void _onContentSet(RoomEventContentSet event, Emitter<RoomState> emit) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateJoined) {
      emit(
        RoomStateActive(
          roomCode: current.roomCode,
          role: current.role,
          contentDescriptor: event.descriptor,
        ),
      );
    } else if (current is RoomStateWaiting) {
      emit(
        RoomStateActive(
          roomCode: current.roomCode,
          role: current.role,
          contentDescriptor: event.descriptor,
        ),
      );
    } else if (current is RoomStateActive) {
      emit(
        RoomStateActive(
          roomCode: current.roomCode,
          role: current.role,
          contentDescriptor: event.descriptor,
          peerStatus: current.peerStatus,
          localReady: false,
          peerReady: false,
        ),
      );
    }
  }

  void _onGuestJoined(RoomEventGuestJoined event, Emitter<RoomState> emit) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateWaiting) {
      emit(RoomStateJoined(roomCode: current.roomCode, role: current.role));
    }
  }

  void _onGuestLeft(RoomEventGuestLeft event, Emitter<RoomState> emit) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateActive) {
      emit(current.copyWith(peerStatus: PeerStatus.away, peerReady: false));
    } else if (current is RoomStateJoined) {
      emit(RoomStateWaiting(roomCode: current.roomCode, role: current.role));
    }
  }

  void _onGuestReconnected(
    RoomEventGuestReconnected event,
    Emitter<RoomState> emit,
  ) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateActive) {
      emit(current.copyWith(peerStatus: PeerStatus.connected));
    }
  }

  void _onLocalReady(RoomEventLocalReady event, Emitter<RoomState> emit) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateActive &&
        _matchesActiveContent(current, event.contentKey)) {
      emit(current.copyWith(localReady: true));
    }
  }

  void _onPlayerReady(RoomEventPlayerReady event, Emitter<RoomState> emit) {
    if (isClosed) return;
    final current = state;
    if (current is RoomStateActive &&
        _matchesActiveContent(current, event.payload.contentKey)) {
      final isLocal = current.role == event.payload.readyRole;
      final newLocalReady = isLocal ? true : current.localReady;
      final newPeerReady = !isLocal ? true : current.peerReady;
      emit(
        current.copyWith(
          localReady: event.payload.bothReady ? true : newLocalReady,
          peerReady: event.payload.bothReady ? true : newPeerReady,
        ),
      );
    }
  }

  void _onRoomClosed(RoomEventRoomClosed event, Emitter<RoomState> emit) {
    if (isClosed) return;
    _completePendingRoomOperation();
    emit(RoomStateClosed(event.reason));
  }

  Future<void> _onLeaveRoom(
    RoomEventLeaveRoom event,
    Emitter<RoomState> emit,
  ) async {
    if (isClosed) return;
    try {
      await _signalRClient.invoke(RoomEvents.hubLeaveRoom);
      _roomRepository.unregisterHandlers();
      await _signalRClient.disconnect();
    } catch (e) {
      _logger.e('Error leaving room: ');
    }
    _repoSubscription?.cancel();
    _repoSubscription = null;
    _timeoutTimer?.cancel();
    if (!isClosed) emit(const RoomStateClosed('user_left'));
  }

  void _onError(RoomEventError event, Emitter<RoomState> emit) {
    if (isClosed) return;
    _completePendingRoomOperation();
    const fatalCodes = {'room_closed', 'role_invalid', 'timeout'};
    if (fatalCodes.contains(event.code)) {
      emit(RoomStateClosed(event.code));
    } else {
      emit(
        RoomStateError(
          code: RoomErrorCodeX.fromString(event.code),
          message: event.message,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _timeoutTimer?.cancel();
    _repoSubscription?.cancel();
    return super.close();
  }
}
