import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/player/player_controller.dart' as pc;
import 'player_event.dart';
import 'player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final pc.PlayerController _playerController;
  final AppLogger _logger = AppLogger('PlayerBloc');
  StreamSubscription? _playerSubscription;
  Timer? _bufferingTimer;

  bool _isRoomMode = false;

  bool _isInitializing = false;
  String? _activeUrl;
  String? _pendingUrl;

  final Set<String> _processedContentKeys = {};

  String? _readyUrl;

  void setRoomMode(bool value) => _isRoomMode = value;

  void clearDedupState() {
    _processedContentKeys.clear();
    _readyUrl = null;
    _logger.d('[PLAYER_DEDUP_CLEARED]');
  }

  PlayerBloc({required pc.PlayerController playerController})
      : _playerController = playerController,
        super(const PlayerStateIdle()) {
    on<PlayerEventInitialize>(_onInitialize);
    on<PlayerEventPlay>(_onPlay);
    on<PlayerEventPause>(_onPause);
    on<PlayerEventSeek>(_onSeek);
    on<PlayerEventBufferingStarted>(_onBufferingStarted);
    on<PlayerEventBufferingConfirmed>(_onBufferingConfirmed);
    on<PlayerEventBufferingEnded>(_onBufferingEnded);
    on<PlayerEventErrorOccurred>(_onError);
    on<PlayerEventStreamEnded>(_onStreamEnded);
    on<PlayerEventDispose>(_onDispose);
  }

  Future<void> _onInitialize(
    PlayerEventInitialize event,
    Emitter<PlayerState> emit,
  ) async {
    final url = event.streamUrl;
    final source = event.source ?? 'unknown';

    _isRoomMode = event.isRoomMode;

    _logger.i(
      '[PLAYER_INIT_CONTEXT] isRoomMode=${event.isRoomMode}, role=${event.role}, roomCode=${event.roomCode}, contentKey=${event.contentKey}',
    );

    if (event.isRoomMode) {
      _logger.i('[ROOM_MODE_FORCED_FROM_ACTIVE_ROOM]');
    } else if (event.role != null || event.roomCode != null) {
      _logger.w(
        '[SOLO_MODE_BLOCKED_ACTIVE_ROOM] Event has room context but isRoomMode was false. Forcing true.',
      );
      _isRoomMode = true;
    }

    _logger.i(
      '[PLAYER_INIT_SOURCE] source=$source, url=${AppLogger.sanitizeUrl(url)}',
    );

    if (_processedContentKeys.contains(url)) {
      _logger.i(
        '[PLAYER_INIT_DUPLICATE_GLOBAL_IGNORED] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    if (_readyUrl == url && _isReadyState) {
      _logger.i(
        '[PLAYER_INIT_SKIPPED_ALREADY_READY] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    if (_isInitializing) {
      if (_activeUrl == url) {
        _logger.i(
          '[PLAYER_INIT_BLOCKED_REENTRANT] same url, url=${AppLogger.sanitizeUrl(url)}',
        );
        return;
      }

      _pendingUrl = url;
      _logger.i(
        '[PLAYER_INIT_QUEUED_PENDING_URL] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    _isInitializing = true;
    _activeUrl = url;
    _pendingUrl = null;

    _processedContentKeys.add(url);

    await _doInitialize(url, emit);

    while (_pendingUrl != null) {
      final nextUrl = _pendingUrl!;
      _pendingUrl = null;
      _activeUrl = nextUrl;
      if (_processedContentKeys.contains(nextUrl)) {
        _logger.i(
          '[PLAYER_INIT_DUPLICATE_GLOBAL_IGNORED] pending url=${AppLogger.sanitizeUrl(nextUrl)}',
        );
        continue;
      }
      _processedContentKeys.add(nextUrl);
      _logger.i(
        '[PLAYER_INIT_STARTED] pending url=${AppLogger.sanitizeUrl(nextUrl)}',
      );
      await _doInitialize(nextUrl, emit);
    }

    _isInitializing = false;
    _activeUrl = null;
  }

  bool get _isReadyState =>
      state is PlayerStateReady ||
      state is PlayerStatePlaying ||
      state is PlayerStatePaused;

  Future<void> _doInitialize(String url, Emitter<PlayerState> emit) async {
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    _logger.i('[PLAYER_INIT_EXECUTED] url=${AppLogger.sanitizeUrl(url)}');
    emit(const PlayerStateLoading());
    final initStartMs = DateTime.now().millisecondsSinceEpoch;
    try {
      await _playerController.initialize(url);
      final initElapsedMs = DateTime.now().millisecondsSinceEpoch - initStartMs;
      _logger.i(
        'player.init: controller initialized [elapsed=${initElapsedMs}ms]',
      );
      _listenToPlayer();
      emit(const PlayerStateReady());
      _readyUrl = url;
      _logger.i(
        'player.init: PlayerStateReady emitted [total_elapsed=${DateTime.now().millisecondsSinceEpoch - initStartMs}ms]',
      );

      if (!_isRoomMode) {
        _logger.i('player.init: auto-playing (solo mode)');
        await _playerController.play();
        emit(PlayerStatePlaying(_playerController.currentPosition));
        _logger.i('player.init: playing started');
      } else {
        _logger.i('player.init: room mode — waiting for protocol play command');
      }
      _logger.i('[PLAYER_INIT_COMPLETED] url=${AppLogger.sanitizeUrl(url)}');
    } catch (e, st) {
      _logger.e(
        '[PLAYER_INIT_FAILED] url=${AppLogger.sanitizeUrl(url)} — $e\n$st',
      );

      _processedContentKeys.remove(url);
      _readyUrl = null;

      var msg = e.toString();

      const prefix = 'Exception: ';
      if (msg.startsWith(prefix)) {
        msg = msg.substring(prefix.length);
      }

      msg = _humanizeError(msg);

      emit(PlayerStateError(msg));
    }
  }

  void _listenToPlayer() {
    _playerSubscription?.cancel();
    _playerSubscription = _playerController.events.listen((event) {
      switch (event.type) {
        case pc.PlayerEventType.playing:
          add(const PlayerEventPlay());
          break;
        case pc.PlayerEventType.paused:
          add(const PlayerEventPause());
          break;
        case pc.PlayerEventType.buffering:
          add(const PlayerEventBufferingStarted());
          break;
        case pc.PlayerEventType.bufferingEnd:
          add(const PlayerEventBufferingEnded());
          break;
        case pc.PlayerEventType.error:
          add(PlayerEventErrorOccurred(event.errorMessage ?? 'Unknown error'));
          break;
        case pc.PlayerEventType.ended:
          add(const PlayerEventStreamEnded());
          break;
        default:
          break;
      }
    });
  }

  Future<void> _onPlay(PlayerEventPlay event, Emitter<PlayerState> emit) async {
    if (state is! PlayerStatePlaying) {
      await _playerController.play();
    }
    emit(PlayerStatePlaying(_playerController.currentPosition));
  }

  Future<void> _onPause(
    PlayerEventPause event,
    Emitter<PlayerState> emit,
  ) async {
    if (state is! PlayerStatePaused) {
      await _playerController.pause();
    }
    emit(PlayerStatePaused(_playerController.currentPosition));
  }

  Future<void> _onSeek(PlayerEventSeek event, Emitter<PlayerState> emit) async {
    await _playerController.seekTo(event.target);
    if (_playerController.isPlaying) {
      emit(PlayerStatePlaying(event.target));
    } else {
      emit(PlayerStatePaused(event.target));
    }
  }

  void _onBufferingStarted(
    PlayerEventBufferingStarted event,
    Emitter<PlayerState> emit,
  ) {
    final pos = _playerController.currentPosition;
    final dur = _playerController.duration;
    final isPlaying = _playerController.isPlaying;

    _logger.i(
      'player.buffering: raw event — '
      'pos=$pos, dur=$dur, isPlaying=$isPlaying, state=${state.runtimeType}',
    );

    if (pos < Duration.zero) {
      _logger.w('player.buffering: ignored — negative position ($pos)');
      return;
    }

    if (dur > Duration.zero && pos > dur + const Duration(seconds: 10)) {
      _logger.w(
        'player.buffering: ignored — position exceeds duration '
        '(pos=$pos, dur=$dur)',
      );
      return;
    }

    if (state is PlayerStatePaused ||
        state is PlayerStateIdle ||
        state is PlayerStateLoading) {
      _logger.d('player.buffering: ignored (state=${state.runtimeType})');
      return;
    }

    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(const Duration(milliseconds: 400), () {
      if (!isClosed) add(const PlayerEventBufferingConfirmed());
    });
  }

  void _onBufferingConfirmed(
    PlayerEventBufferingConfirmed event,
    Emitter<PlayerState> emit,
  ) {
    _logger.i('player.buffering: confirmed');
    emit(PlayerStateBuffering(_playerController.currentPosition));
  }

  void _onBufferingEnded(
    PlayerEventBufferingEnded event,
    Emitter<PlayerState> emit,
  ) {
    _logger.i(
      'player.buffering: ended at ${_playerController.currentPosition}',
    );
    _bufferingTimer?.cancel();
    if (_playerController.isPlaying) {
      emit(PlayerStatePlaying(_playerController.currentPosition));
    } else {
      emit(PlayerStatePaused(_playerController.currentPosition));
    }
  }

  void _onError(PlayerEventErrorOccurred event, Emitter<PlayerState> emit) {
    final msg = _humanizeError(event.message);
    emit(PlayerStateError(msg, recoverable: event.recoverable));
  }

  void _onStreamEnded(PlayerEventStreamEnded event, Emitter<PlayerState> emit) {
    emit(const PlayerStateEnded());
  }

  Future<void> _onDispose(
    PlayerEventDispose event,
    Emitter<PlayerState> emit,
  ) async {
    await _disposePlayerResources();
    emit(const PlayerStateIdle());
  }

  @override
  Future<void> close() async {
    await _disposePlayerResources();
    return super.close();
  }

  Future<void> _disposePlayerResources() async {
    _bufferingTimer?.cancel();
    _bufferingTimer = null;
    await _playerSubscription?.cancel();
    _playerSubscription = null;

    try {
      await _playerController.dispose();
    } catch (e, st) {
      _logger.e('player.dispose failed', error: e, stackTrace: st);
    }

    _isInitializing = false;
    _activeUrl = null;
    _pendingUrl = null;
    _processedContentKeys.clear();
    _readyUrl = null;
  }

  static String _humanizeError(String raw) {
    if (RegExp(
      r'HTTP error 403|403 Forbidden',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'Stream access denied (403). '
          'Your provider may be blocking concurrent connections. Ensure your IPTV account allows multiple simultaneous devices.';
    }
    if (RegExp(
      r'HTTP error 404|404 Not Found',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return 'Stream not found (404). '
          'The content may have been removed or the URL is invalid.';
    }
    if (RegExp(r'HTTP error 5\d{2}', caseSensitive: false).hasMatch(raw)) {
      return 'Stream server error. Please try again later.';
    }
    if (raw.contains('no playable media detected')) {
      return 'No playable media detected. '
          'The stream may be offline or in an unsupported format.';
    }
    if (RegExp(r'Failed to open segment', caseSensitive: false).hasMatch(raw)) {
      return 'Stream segments unavailable. '
          'The content may require re-selection.';
    }
    return raw;
  }
}
