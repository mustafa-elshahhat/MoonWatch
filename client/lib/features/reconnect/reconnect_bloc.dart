import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/signalr_client.dart';
import '../../core/protocol/room_events.dart';
import '../room/bloc/room_event.dart';
import '../room/repository/room_repository.dart';

// —— ReconnectEvent ———————————————————————————————————————————————————————————

sealed class ReconnectEvent extends Equatable {
  const ReconnectEvent();

  @override
  List<Object?> get props => [];
}

/// SignalR connection dropped.
class ReconnectEventDisconnected extends ReconnectEvent {
  const ReconnectEventDisconnected();
}

/// SignalR reconnect succeeded — attempt app-layer rejoin.
class ReconnectEventAttemptRejoin extends ReconnectEvent {
  const ReconnectEventAttemptRejoin();
}

/// Network lost entirely (connectivity_plus).
class ReconnectEventNetworkLost extends ReconnectEvent {
  const ReconnectEventNetworkLost();
}

/// Network restored.
class ReconnectEventNetworkRestored extends ReconnectEvent {
  const ReconnectEventNetworkRestored();
}

/// App-layer rejoin succeeded (room:joined received).
class ReconnectEventSucceeded extends ReconnectEvent {
  const ReconnectEventSucceeded();
}

/// App-layer rejoin failed (room:error received).
class ReconnectEventFailed extends ReconnectEvent {
  final String reason;
  const ReconnectEventFailed(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// Reset to idle (e.g., after user leaves room).
class ReconnectEventReset extends ReconnectEvent {
  const ReconnectEventReset();
}

// —— ReconnectState ———————————————————————————————————————————————————————————

sealed class ReconnectState extends Equatable {
  const ReconnectState();

  @override
  List<Object?> get props => [];
}

/// Normal state — SignalR connected.
class ReconnectStateIdle extends ReconnectState {
  const ReconnectStateIdle();
}

/// SignalR automatic retry in progress.
class ReconnectStateAttempting extends ReconnectState {
  final int attemptNumber;
  const ReconnectStateAttempting({this.attemptNumber = 1});

  @override
  List<Object?> get props => [attemptNumber];
}

/// Network is offline.
class ReconnectStateOffline extends ReconnectState {
  const ReconnectStateOffline();
}

/// Reconnect and rejoin succeeded.
class ReconnectStateSuccess extends ReconnectState {
  const ReconnectStateSuccess();
}

/// Reconnect failed permanently.
class ReconnectStateFailed extends ReconnectState {
  final String reason;
  const ReconnectStateFailed(this.reason);

  @override
  List<Object?> get props => [reason];
}

// —— ReconnectBloc ————————————————————————————————————————————————————————————

/// Manages automatic reconnection for guests after connection loss.
///
/// State machine:
///   Connected(Idle) → Reconnecting(Attempting) → Re-joining → Connected(Success) | Failed
///
/// CL-34: State machine
/// CL-35: Wire SignalR onReconnecting/onReconnected/onClose
/// CL-36: On reconnected → rejoinRoom
/// CL-37: On room:joined after reconnect → success
/// CL-38: On room:error after rejoin → failed
/// CL-39: On all retries exhausted → persistent disconnect
class ReconnectBloc extends Bloc<ReconnectEvent, ReconnectState> {
  final SignalRClient _signalRClient;
  final RoomRepository _roomRepository;
  final AppLogger _logger = AppLogger('ReconnectBloc');

  StreamSubscription<SignalRConnectionState>? _connectionSubscription;
  StreamSubscription<RoomEvent>? _roomEventSubscription;

  /// Stored room code and role for rejoin after reconnect.
  String? _storedRoomCode;
  String? _storedRole;

  /// Guard to prevent duplicate JoinRoom calls.
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

  /// Call after joining a room to store credentials for potential rejoin.
  void storeRoomCredentials(String roomCode, String role) {
    _storedRoomCode = roomCode;
    _storedRole = role;
  }

  /// Fatal error codes that indicate the room is gone (no retry possible).
  static const _fatalErrorCodes = {
    'room_not_found',
    'room_closed',
    'room_full',
    'role_invalid',
  };

  /// CL-35: Start listening to SignalR connection state changes.
  /// CL-37/CL-38: Also listen to RoomRepository events for room:joined
  /// and room:error responses after a rejoin attempt.
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

      if (event is RoomEventRoomJoined) {
        // CL-37: room:joined after reconnect → success
        add(const ReconnectEventSucceeded());
      } else if (event is RoomEventError &&
          _fatalErrorCodes.contains(event.code)) {
        // CL-38: room:error with fatal code after rejoin → failed
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

  /// CL-36: On SignalR reconnected → call RoomRepository.joinRoom to rejoin.
  Future<void> _onAttemptRejoin(
    ReconnectEventAttemptRejoin event,
    Emitter<ReconnectState> emit,
  ) async {
    if (_storedRoomCode == null || _storedRole == null) {
      _logger.w('No stored room credentials for rejoin');
      emit(const ReconnectStateFailed('no_credentials'));
      return;
    }

    // Guard: only one rejoin in-flight at a time
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
        // Bail out if the bloc was closed during a previous delay or invoke.
        if (isClosed) return;
        try {
          await _signalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: [_storedRoomCode!, _storedRole!],
          );
          success = true;
          // Success/failure is determined by the room:joined or room:error events
          // dispatched through RoomBloc → which calls ReconnectEventSucceeded
          // or ReconnectEventFailed.
        } catch (e) {
          attempt++;
          if (attempt >= maxRetries) {
            throw Exception('Max retries reached: $e');
          }
          final delayMs = 1000 * (1 << (attempt - 1)); // 1s, 2s, 4s
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

  /// CL-37: On room:joined after reconnect → success.
  void _onSucceeded(
    ReconnectEventSucceeded event,
    Emitter<ReconnectState> emit,
  ) {
    _logger.i('[reconnect.success] Reconnect succeeded');
    emit(const ReconnectStateSuccess());
    emit(const ReconnectStateIdle());
  }

  /// CL-38/CL-39: On room:error or max retries → failed.
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
