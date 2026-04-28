import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/signalr_client.dart';
import '../../core/protocol/room_events.dart';
import '../room/bloc/room_event.dart';
import '../room/repository/room_repository.dart';
import '../room/domain/room_repository_event.dart';

sealed class ReconnectEvent extends Equatable {
  const ReconnectEvent();

  @override
  List<Object?> get props => [];
}

class ReconnectEventDisconnected extends ReconnectEvent {
  const ReconnectEventDisconnected();
}

class ReconnectEventAttemptRejoin extends ReconnectEvent {
  const ReconnectEventAttemptRejoin();
}

class ReconnectEventNetworkLost extends ReconnectEvent {
  const ReconnectEventNetworkLost();
}

class ReconnectEventNetworkRestored extends ReconnectEvent {
  const ReconnectEventNetworkRestored();
}

class ReconnectEventSucceeded extends ReconnectEvent {
  const ReconnectEventSucceeded();
}

class ReconnectEventFailed extends ReconnectEvent {
  final String reason;
  const ReconnectEventFailed(this.reason);

  @override
  List<Object?> get props => [reason];
}

class ReconnectEventReset extends ReconnectEvent {
  const ReconnectEventReset();
}

sealed class ReconnectState extends Equatable {
  const ReconnectState();

  @override
  List<Object?> get props => [];
}

class ReconnectStateIdle extends ReconnectState {
  const ReconnectStateIdle();
}

class ReconnectStateAttempting extends ReconnectState {
  final int attemptNumber;
  const ReconnectStateAttempting({this.attemptNumber = 1});

  @override
  List<Object?> get props => [attemptNumber];
}

class ReconnectStateOffline extends ReconnectState {
  const ReconnectStateOffline();
}

class ReconnectStateSuccess extends ReconnectState {
  const ReconnectStateSuccess();
}

class ReconnectStateFailed extends ReconnectState {
  final String reason;
  const ReconnectStateFailed(this.reason);

  @override
  List<Object?> get props => [reason];
}

class ReconnectBloc extends Bloc<ReconnectEvent, ReconnectState> {
  final SignalRClient _signalRClient;
  final RoomRepository _roomRepository;
  final AppLogger _logger = AppLogger('ReconnectBloc');

  StreamSubscription<SignalRConnectionState>? _connectionSubscription;
  StreamSubscription<RoomRepositoryEvent>? _roomEventSubscription;

  String? _storedRoomCode;
  String? _storedRole;

  bool _rejoinInFlight = false;

  ReconnectBloc({
    required SignalRClient signalRClient,
    required RoomRepository roomRepository,
  })  : _signalRClient = signalRClient,
        _roomRepository = roomRepository,
        super(const ReconnectStateIdle()) {
    on<ReconnectEventDisconnected>(_onDisconnected);
    on<ReconnectEventAttemptRejoin>(_onAttemptRejoin);
    on<ReconnectEventNetworkLost>(_onNetworkLost);
    on<ReconnectEventNetworkRestored>(_onNetworkRestored);
    on<ReconnectEventSucceeded>(_onSucceeded);
    on<ReconnectEventFailed>(_onFailed);
    on<ReconnectEventReset>(_onReset);
  }

  void storeRoomCredentials(String roomCode, String role) {
    _storedRoomCode = roomCode;
    _storedRole = role;
  }

  static const _fatalErrorCodes = {
    'room_not_found',
    'room_closed',
    'room_full',
    'role_invalid',
  };

  void startListening() {
    _connectionSubscription?.cancel();
    _connectionSubscription = _signalRClient.connectionState.listen((state) {
      switch (state) {
        case SignalRConnectionState.reconnecting:
          add(const ReconnectEventDisconnected());
          break;
        case SignalRConnectionState.connected:
          if (this.state is ReconnectStateAttempting ||
              this.state is ReconnectStateOffline) {
            add(const ReconnectEventAttemptRejoin());
          }
          break;
        case SignalRConnectionState.disconnected:
          if (this.state is ReconnectStateAttempting) {
            add(const ReconnectEventFailed('max_retries'));
          }
          break;
        default:
          break;
      }
    });

    _roomEventSubscription?.cancel();
    _roomEventSubscription = _roomRepository.events.listen((event) {
      if (state is! ReconnectStateAttempting) return;

      if (event is RepoEventRoomJoined) {
        add(const ReconnectEventSucceeded());
      } else if (event is RepoEventError &&
          _fatalErrorCodes.contains(event.code)) {
        add(ReconnectEventFailed(event.code));
      }
    });
  }

  void _onDisconnected(
    ReconnectEventDisconnected event,
    Emitter<ReconnectState> emit,
  ) {
    if (state is ReconnectStateIdle || state is ReconnectStateSuccess) {
      _logger.i(
        '[reconnect.attempt] Connection dropped, entering reconnect mode',
      );
      emit(const ReconnectStateAttempting(attemptNumber: 1));
    }
  }

  Future<void> _onAttemptRejoin(
    ReconnectEventAttemptRejoin event,
    Emitter<ReconnectState> emit,
  ) async {
    if (_storedRoomCode == null || _storedRole == null) {
      _logger.w('No stored room credentials for rejoin');
      emit(const ReconnectStateFailed('no_credentials'));
      return;
    }

    if (_rejoinInFlight) return;
    _rejoinInFlight = true;

    try {
      _logger.i(
        '[reconnect.attempt] Attempting app-layer rejoin to room $_storedRoomCode as $_storedRole',
      );

      int attempt = 0;
      const maxRetries = 3;
      bool success = false;

      while (attempt < maxRetries && !success) {
        if (isClosed) return;
        try {
          await _signalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: [_storedRoomCode!, _storedRole!],
          );
          success = true;
        } catch (e) {
          attempt++;
          if (attempt >= maxRetries) {
            throw Exception('Max retries reached: $e');
          }
          final delayMs = 1000 * (1 << (attempt - 1));
          _logger.w(
            '[reconnect.attempt] Rejoin invocation failed. Retrying in ${delayMs / 1000}s (Attempt $attempt of $maxRetries) — $e',
          );
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    } catch (e) {
      if (isClosed) return;
      _logger.e('Rejoin invocation failed: $e');
      emit(const ReconnectStateFailed('rejoin_error'));
    } finally {
      _rejoinInFlight = false;
    }
  }

  void _onNetworkLost(
    ReconnectEventNetworkLost event,
    Emitter<ReconnectState> emit,
  ) {
    _logger.i('Network lost');
    emit(const ReconnectStateOffline());
  }

  void _onNetworkRestored(
    ReconnectEventNetworkRestored event,
    Emitter<ReconnectState> emit,
  ) {
    if (state is ReconnectStateOffline) {
      _logger.i('Network restored, will attempt reconnect');
      emit(const ReconnectStateAttempting(attemptNumber: 1));
    }
  }

  void _onSucceeded(
    ReconnectEventSucceeded event,
    Emitter<ReconnectState> emit,
  ) {
    _logger.i('[reconnect.success] Reconnect succeeded');
    emit(const ReconnectStateSuccess());
    emit(const ReconnectStateIdle());
  }

  void _onFailed(ReconnectEventFailed event, Emitter<ReconnectState> emit) {
    _logger.w('[reconnect.failed] Reconnect failed: ${event.reason}');
    emit(ReconnectStateFailed(event.reason));
  }

  void _onReset(ReconnectEventReset event, Emitter<ReconnectState> emit) {
    _storedRoomCode = null;
    _storedRole = null;
    _rejoinInFlight = false;
    emit(const ReconnectStateIdle());
  }

  @override
  Future<void> close() {
    _connectionSubscription?.cancel();
    _roomEventSubscription?.cancel();
    return super.close();
  }
}
