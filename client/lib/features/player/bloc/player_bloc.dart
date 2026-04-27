import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/player/player_controller.dart' as pc;
import 'player_event.dart';
import 'player_state.dart';

/// PlayerBloc per STATE_MANAGEMENT.md.
///
/// SINGLE source of truth for player initialization.
/// All initialization MUST go through PlayerEventInitialize.
/// No other component may call PlayerController.initialize() directly.
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final pc.PlayerController _playerController;
  final AppLogger _logger = AppLogger('PlayerBloc');
  StreamSubscription? _playerSubscription;
  Timer? _bufferingTimer;

  /// When true, _onInitialize does NOT auto-play.
  /// In room mode, playback is initiated by the host via the room protocol.
  /// Set via [setRoomMode] before dispatching PlayerEventInitialize.
  bool _isRoomMode = false;

  // ── Single-flight initialize guard ────────────────────────────────────
  bool _isInitializing = false;
  String? _activeUrl;
  String? _pendingUrl;

  // ── Global dedup: processed content keys (TASK 2) ─────────────────────
  /// Tracks all URLs that have been successfully initialized or are currently
  /// being initialized. Prevents re-initialization of the same content even
  /// when multiple event sources dispatch PlayerEventInitialize.
  final Set<String> _processedContentKeys = {};

  /// The URL of the currently ready player. Used to skip re-initialization
  /// when the player is already in a ready/playing/paused state for this URL.
  String? _readyUrl;

  /// Configure room mode before initializing the player.
  void setRoomMode(bool value) => _isRoomMode = value;

  /// Clear dedup state — called when user requests explicit retry.
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

    // ── TASK 1 & 3: Force room mode from event context ──
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

    // ── TASK 2: Global dedup — reject if this URL was already processed ──
    if (_processedContentKeys.contains(url)) {
      _logger.i(
        '[PLAYER_INIT_DUPLICATE_GLOBAL_IGNORED] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    // ── TASK 5: Skip if already ready with same URL ─────────────────────
    if (_readyUrl == url && _isReadyState) {
      _logger.i(
        '[PLAYER_INIT_SKIPPED_ALREADY_READY] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    // ── TASK 4: Block re-entrant initialization ─────────────────────────
    if (_isInitializing) {
      if (_activeUrl == url) {
        _logger.i(
          '[PLAYER_INIT_BLOCKED_REENTRANT] same url, url=${AppLogger.sanitizeUrl(url)}',
        );
        return;
      }
      // Different URL — queue it and run after the current init completes.
      _pendingUrl = url;
      _logger.i(
        '[PLAYER_INIT_QUEUED_PENDING_URL] url=${AppLogger.sanitizeUrl(url)}',
      );
      return;
    }

    _isInitializing = true;
    _activeUrl = url;
    _pendingUrl = null;

    // Mark as in-progress immediately to block duplicates.
    _processedContentKeys.add(url);

    await _doInitialize(url, emit);

    // After completion, check if a pending URL was queued.
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

  /// Whether the current state is "ready" (player can be used).
  bool get _isReadyState =>
      state is PlayerStateReady ||
      state is PlayerStatePlaying ||
      state is PlayerStatePaused;

  Future<void> _doInitialize(String url, Emitter<PlayerState> emit) async {
    // Cancel any pending buffering timer from a previous media load to prevent
    // stale buffering confirmations showing up for the new content.
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

      // Auto-play only in solo mode.
      // In room mode, the host sends Play via the room protocol,
      // which comes back as playback:play and SyncBloc handles it.
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
      // Remove from processed set so retry is possible.
      _processedContentKeys.remove(url);
      _readyUrl = null;

      var msg = e.toString();
      // Strip Dart's "Exception: " prefix for user-facing display.
      const prefix = 'Exception: ';
      if (msg.startsWith(prefix)) {
        msg = msg.substring(prefix.length);
      }
      // Translate known technical errors into user-friendly messages.
      msg = _humanizeError(msg);
      // Emit error only — do NOT reset room state or call LeaveRoom.
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

    // Guard: impossible negative position — HLS timestamp artifact.
    if (pos < Duration.zero) {
      _logger.w('player.buffering: ignored — negative position ($pos)');
      return;
    }

    // Guard: position exceeds duration by more than 10 s — HLS segment timestamp
    // offset artifact (e.g. live-origin VOD where timestamps don't start at 0).
    if (dur > Duration.zero && pos > dur + const Duration(seconds: 10)) {
      _logger.w(
        'player.buffering: ignored — position exceeds duration '
        '(pos=$pos, dur=$dur)',
      );
      return;
    }

    // Never show buffering overlay while paused or during initial load.
    if (state is PlayerStatePaused ||
        state is PlayerStateIdle ||
        state is PlayerStateLoading) {
      _logger.d('player.buffering: ignored (state=${state.runtimeType})');
      return;
    }

    // Debounce: wait 400 ms before confirming — filters transient HLS segment
    // switches that self-resolve without user-visible stall.
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
    // Guard: if already idle, a previous dispose already ran (e.g. double-dispatch
    // from _confirmLeave race). Avoid re-disposing the singleton PlayerController.
    if (state is PlayerStateIdle) return;
    _bufferingTimer?.cancel();
    await _playerSubscription?.cancel();
    await _playerController.dispose();
    // Reset all single-flight and dedup state so next session starts clean.
    _isInitializing = false;
    _activeUrl = null;
    _pendingUrl = null;
    _processedContentKeys.clear();
    _readyUrl = null;
    emit(const PlayerStateIdle());
  }

  @override
  Future<void> close() {
    _bufferingTimer?.cancel();
    _playerSubscription?.cancel();
    return super.close();
  }

  /// Translate technical player/network errors into user-facing messages.
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
