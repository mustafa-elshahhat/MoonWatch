import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/logging/app_logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/player_controller.dart';
import '../../features/room/repository/room_repository.dart';

// â”€â”€ Sync Events â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncEventPlayReceived extends SyncEvent {
  final int positionMs;
  final int serverTimestampMs;
  final int hostRttMs;

  /// Playback command sequence number. Clients reject commands with seqNo <= lastApplied.
  final int seqNo;

  const SyncEventPlayReceived({
    required this.positionMs,
    required this.serverTimestampMs,
    required this.hostRttMs,
    this.seqNo = 0,
  });

  @override
  List<Object?> get props => [positionMs, serverTimestampMs, hostRttMs, seqNo];
}

class SyncEventPauseReceived extends SyncEvent {
  final int positionMs;

  /// Server timestamp when this command was issued. Used for deferred queue ordering.
  final int serverTimestampMs;

  /// Playback command sequence number.
  final int seqNo;

  const SyncEventPauseReceived({
    required this.positionMs,
    this.serverTimestampMs = 0,
    this.seqNo = 0,
  });

  @override
  List<Object?> get props => [positionMs, serverTimestampMs, seqNo];
}

class SyncEventSeekReceived extends SyncEvent {
  final int targetPositionMs;

  /// Server timestamp when this command was issued.
  final int serverTimestampMs;

  /// Playback command sequence number.
  final int seqNo;

  /// Whether the host was playing at the moment of seek.
  /// Guest uses this to decide whether to resume after seeking.
  /// null = use current SyncBloc state as fallback (backward compat).
  final bool? isPlaying;

  const SyncEventSeekReceived({
    required this.targetPositionMs,
    this.serverTimestampMs = 0,
    this.seqNo = 0,
    this.isPlaying,
  });

  @override
  List<Object?> get props => [
        targetPositionMs,
        serverTimestampMs,
        seqNo,
        isPlaying,
      ];
}

class SyncEventStateSyncReceived extends SyncEvent {
  final int hostPositionMs;
  final bool isPlaying;
  final int serverTimestampMs;

  /// Room playback command counter at time of state_sync emission.
  final int seqNo;

  const SyncEventStateSyncReceived({
    required this.hostPositionMs,
    required this.isPlaying,
    required this.serverTimestampMs,
    this.seqNo = 0,
  });

  @override
  List<Object?> get props => [
        hostPositionMs,
        isPlaying,
        serverTimestampMs,
        seqNo,
      ];
}

/// Local player stalled (CL-27).
class SyncEventPlayerStalled extends SyncEvent {
  const SyncEventPlayerStalled();
}

/// Local player ready after stall (CL-28).
class SyncEventPlayerReady extends SyncEvent {
  const SyncEventPlayerReady();
}

/// Peer's player stalled â€” received via buffering:stall (CL-29).
class SyncEventPeerStalled extends SyncEvent {
  final int positionMs;
  final int episodeId;
  const SyncEventPeerStalled({
    required this.positionMs,
    required this.episodeId,
  });

  @override
  List<Object?> get props => [positionMs, episodeId];
}

/// Server sent buffering:resume â€” both ready (CL-30).
class SyncEventBufferingResumeReceived extends SyncEvent {
  final int resumePositionMs;
  final int episodeId;
  const SyncEventBufferingResumeReceived({
    required this.resumePositionMs,
    required this.episodeId,
  });

  @override
  List<Object?> get props => [resumePositionMs, episodeId];
}

/// Self-dispatched by SyncBloc when kMaxCorrectionSeeksPerWindow is exceeded
/// within kCorrectionSeekWindowMs. Triggers SyncStateDegraded.
class SyncEventExcessiveDrift extends SyncEvent {
  const SyncEventExcessiveDrift();
}

/// Internal event â€” self-dispatched by SyncBloc.setPlayerReady(true) to flush
/// the deferred command queue on the BLoC event loop (async-safe).
class _SyncEventFlushDeferred extends SyncEvent {
  const _SyncEventFlushDeferred();
}

// â”€â”€ Sync States â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

sealed class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncStateIdle extends SyncState {
  const SyncStateIdle();
}

class SyncStateSyncing extends SyncState {
  const SyncStateSyncing();
}

class SyncStatePaused extends SyncState {
  const SyncStatePaused();
}

class SyncStateBuffering extends SyncState {
  const SyncStateBuffering();
}

class SyncStateDegraded extends SyncState {
  final int correctionCount;
  const SyncStateDegraded(this.correctionCount);

  @override
  List<Object?> get props => [correctionCount];
}

// â”€â”€ SyncBloc â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

/// SyncBloc per SYNC_ENGINE.md and BUFFERING_COORDINATION.md.
/// Receives playback events from RoomRepository, implements drift detection
/// and correction seek. Handles buffering coordination (CL-27 through CL-30).
///
/// Deferred command queue (RC-FIX):
/// All incoming playback commands (play/pause/seek/state_sync) are queued while
/// the local player is initializing. On playerReady, the queue is reconciled into
/// a "latest-intent" snapshot: the most-recent authoritative position and play/pause
/// state are applied in one atomic step with time compensation.
///
/// Sequence number tracking (RC-FIX):
/// Each command carries a monotonically increasing seqNo from the server.
/// Commands with seqNo <= _lastAppliedSeqNo are rejected to prevent stale
/// replays from overwriting a newer authoritative state.
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final PlayerController _playerController;
  final RoomRepository _roomRepository;
  final AppLogger _logger = AppLogger('SyncBloc');

  /// Role of the local participant ("host" or "guest").
  String _role = 'guest';

  int _guestRttMs = AppConstants.kDefaultRttMs;
  final List<int> _correctionTimestamps = [];

  /// Estimated clock offset (server_clock - client_clock) in milliseconds.
  /// Positive means server clock is ahead of client. Applied to convert
  /// client timestamps to server time reference for accurate elapsed-time
  /// calculations. Updated by LatencyEstimator ping/pong measurements.
  int _clockOffsetMs = 0;

  bool _localStallSent = false;
  bool _wasPlayingBeforeBuffering = false;

  /// Whether the player surface is attached and ready to accept commands.
  bool _playerReady = false;
  String? _playerContentKey;
  String? _lastNotifiedReadyContentKey;

  /// Deferred command queue. All play/pause/seek/state_sync events received
  /// while _playerReady == false are stored here. Flushed on setPlayerReady(true).
  final List<SyncEvent> _deferredQueue = [];

  /// Last applied sequence number. Commands with seqNo <= this value are rejected.
  /// seqNo == 0 means the server hasn't started numbering yet (old server or first boot).
  int _lastAppliedSeqNo = 0;

  /// Timestamp (epoch ms) of the last authoritative command applied (play/seek/flush).
  /// Drift checks are suppressed for [_kPostCommandCooldownMs] after this to let
  /// the player settle into the new position before measuring drift.
  int _lastAuthoritativeCommandAtMs = 0;

  /// Cooldown period after an authoritative command during which drift checks are skipped.
  /// Covers seek buffering, HLS segment fetching, and player stabilization time.
  static const int _kPostCommandCooldownMs = 3000;

  // ── Buffering episode tracking (prevents infinite stall/ready loop) ──
  int _bufferingEpisodeId = 0;
  int? _currentEpisodeId;
  int? _lastStallPositionMs;
  int _lastBufferingResumeAtMs = 0;
  int _lastSeekTargetMs = 0;
  int _lastSeekAppliedAtMs = 0;
  static const int _kPostSeekCooldownMs = 3000;
  static const int _kPostResumeCooldownMs = 3000;
  static const int _kPositionToleranceMs = 2000;

  /// Number of consecutive state_sync cycles where drift exceeded the threshold.
  /// A correction seek is only triggered after [_kRequiredDriftHits] consecutive hits
  /// to avoid unnecessary seeks from momentary jitter or measurement noise.
  int _consecutiveDriftHits = 0;

  /// How many consecutive drift-exceeding state_syncs are required before triggering
  /// a correction seek. Acts as hysteresis to prevent oscillation.
  static const int _kRequiredDriftHits = 2;

  SyncBloc({
    required PlayerController playerController,
    required RoomRepository roomRepository,
  })  : _playerController = playerController,
        _roomRepository = roomRepository,
        super(const SyncStateIdle()) {
    on<SyncEventPlayReceived>(_onPlayReceived);
    on<SyncEventPauseReceived>(_onPauseReceived);
    on<SyncEventSeekReceived>(_onSeekReceived);
    on<SyncEventStateSyncReceived>(_onStateSyncReceived);
    on<SyncEventPlayerStalled>(_onPlayerStalled);
    on<SyncEventPlayerReady>(_onPlayerReady);
    on<SyncEventPeerStalled>(_onPeerStalled);
    on<SyncEventBufferingResumeReceived>(_onBufferingResumeReceived);
    on<SyncEventExcessiveDrift>(_onExcessiveDrift);
    on<_SyncEventFlushDeferred>(_onFlushDeferred);

    // Wire RoomRepository buffering callbacks → dispatch events into this Bloc.
    _roomRepository.onBufferingStall = (payload) {
      add(
        SyncEventPeerStalled(
          positionMs: payload.positionMs,
          episodeId: payload.episodeId,
        ),
      );
    };
    _roomRepository.onBufferingResume = (payload) {
      add(
        SyncEventBufferingResumeReceived(
          resumePositionMs: payload.resumePositionMs,
          episodeId: payload.episodeId,
        ),
      );
    };

    // Wire playback sync callbacks â†’ dispatch sync events into this Bloc.
    _roomRepository.onPlaybackPlay = (payload) {
      add(
        SyncEventPlayReceived(
          positionMs: payload.positionMs,
          serverTimestampMs: payload.serverTimestampMs,
          hostRttMs: payload.hostRttMs,
          seqNo: payload.seqNo,
        ),
      );
    };
    _roomRepository.onPlaybackPause = (payload) {
      add(
        SyncEventPauseReceived(
          positionMs: payload.positionMs,
          serverTimestampMs: payload.serverTimestampMs,
          seqNo: payload.seqNo,
        ),
      );
    };
    _roomRepository.onPlaybackSeek = (payload) {
      add(
        SyncEventSeekReceived(
          targetPositionMs: payload.targetPositionMs,
          serverTimestampMs: payload.serverTimestampMs,
          seqNo: payload.seqNo,
          isPlaying: payload.isPlaying,
        ),
      );
    };
    _roomRepository.onPlaybackStateSync = (payload) {
      add(
        SyncEventStateSyncReceived(
          hostPositionMs: payload.hostPositionMs,
          isPlaying: payload.isPlaying,
          serverTimestampMs: payload.serverTimestampMs,
          seqNo: payload.seqNo,
        ),
      );
    };
  }

  /// Set the local participant's role. Must be called after room join.
  void setRole(String role) {
    if (_role == role) {
      _logger.d('[SYNC_ROLE_DUPLICATE_IGNORED] role=$role');
      return;
    }
    _role = role;
    _logger.d('[SYNC_ROLE_SET] role=$_role');
  }

  void updateGuestRtt(int rttMs) {
    _guestRttMs = rttMs;
  }

  /// Update estimated clock offset between client and server.
  /// Called from LatencyEstimator whenever a new pong measurement arrives.
  void updateClockOffset(int offsetMs) {
    _clockOffsetMs = offsetMs;
  }

  /// Mark the player as ready/not-ready for sync commands.
  /// Called from WatchScreen's BlocListener on PlayerStateReady (true) and
  /// PlayerStateIdle/PlayerStateError (false).
  ///
  /// On ready: flushes the deferred command queue with latest-intent reconciliation.
  /// On not-ready: clears the queue (stale commands for the old player instance).
  void setPlayerReady(bool ready, {String? contentKey}) {
    final nextContentKey = contentKey ?? (ready ? _playerContentKey : null);
    final contentChanged = nextContentKey != _playerContentKey;

    if (!contentChanged && _playerReady == ready) return;

    _playerContentKey = nextContentKey;
    _playerReady = ready;
    _logger.i(
      'SyncBloc: playerReady=$ready contentKey=${_playerContentKey ?? "unknown"}',
    );
    if (ready) {
      final readyContentKey = _playerContentKey;
      if (readyContentKey != null &&
          readyContentKey != _lastNotifiedReadyContentKey) {
        _lastNotifiedReadyContentKey = readyContentKey;
        _roomRepository.notifyPlayerReady(readyContentKey);
      }
      // Flush is async; schedule on the event loop to avoid calling async code
      // directly in this sync method. The BLoC event queue processes it next.
      if (_deferredQueue.isNotEmpty) {
        _logger.i(
          'SyncBloc: scheduling deferred queue flush [queue_size=${_deferredQueue.length}]',
        );
        add(const _SyncEventFlushDeferred());
      }
    } else {
      if (contentChanged) {
        _lastNotifiedReadyContentKey = null;
      }
      // Reset hysteresis counter so drift hits from the previous content do not
      // bleed into the new content's correction window.
      _consecutiveDriftHits = 0;
      // Player was reset — discard all deferred commands for the previous player.
      if (_deferredQueue.isNotEmpty) {
        _logger.d(
          'SyncBloc: player not ready — clearing ${_deferredQueue.length} deferred commands',
        );
        _deferredQueue.clear();
      }
    }
  }

  // â”€â”€ Event handlers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _onPlayReceived(
    SyncEventPlayReceived event,
    Emitter<SyncState> emit,
  ) async {
    final receivedAtMs = DateTime.now().millisecondsSinceEpoch;

    // INV-12: Host receives its own broadcast back — treat as no-op.
    if (_role == 'host') {
      _logger.d(
        'SyncBloc: host ignoring own playback:play broadcast [seqNo=${event.seqNo}]',
      );
      return;
    }

    _logger.i(
      'SyncBloc: playback:play received at $receivedAtMs '
      '[seqNo=${event.seqNo}, positionMs=${event.positionMs}, '
      'serverTs=${event.serverTimestampMs}, playerReady=$_playerReady]',
    );

    // Stale command guard: reject if we've already applied a newer command.
    if (event.seqNo > 0 && event.seqNo <= _lastAppliedSeqNo) {
      _logger.w(
        'SyncBloc: ignoring stale playback:play '
        '[seqNo=${event.seqNo} <= lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    if (!_playerReady) {
      _logger.i(
        'SyncBloc: deferring playback:play '
        '[seqNo=${event.seqNo}, positionMs=${event.positionMs}, '
        'serverTs=${event.serverTimestampMs}]',
      );
      _deferredQueue.add(event);
      return;
    }

    await _applyPlay(event, emit);
  }

  Future<void> _onPauseReceived(
    SyncEventPauseReceived event,
    Emitter<SyncState> emit,
  ) async {
    // INV-12: Host receives its own broadcast back â€” treat as no-op.
    if (_role == 'host') {
      _logger.d(
        'SyncBloc: host ignoring own playback:pause broadcast [seqNo=${event.seqNo}]',
      );
      return;
    }

    if (event.seqNo > 0 && event.seqNo <= _lastAppliedSeqNo) {
      _logger.w(
        'SyncBloc: ignoring stale playback:pause '
        '[seqNo=${event.seqNo} <= lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    if (!_playerReady) {
      _logger.i(
        'SyncBloc: deferring playback:pause '
        '[seqNo=${event.seqNo}, positionMs=${event.positionMs}]',
      );
      _deferredQueue.add(event);
      return;
    }

    await _applyPause(event, emit);
  }

  Future<void> _onSeekReceived(
    SyncEventSeekReceived event,
    Emitter<SyncState> emit,
  ) async {
    // INV-12: Host receives its own broadcast back â€” treat as no-op.
    if (_role == 'host') {
      _logger.d(
        'SyncBloc: host ignoring own playback:seek broadcast [seqNo=${event.seqNo}]',
      );
      return;
    }

    if (event.seqNo > 0 && event.seqNo <= _lastAppliedSeqNo) {
      _logger.w(
        'SyncBloc: ignoring stale playback:seek '
        '[seqNo=${event.seqNo} <= lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    if (!_playerReady) {
      _logger.i(
        'SyncBloc: deferring playback:seek '
        '[seqNo=${event.seqNo}, targetPositionMs=${event.targetPositionMs}]',
      );
      _deferredQueue.add(event);
      return;
    }

    await _applySeek(event, emit);
  }

  Future<void> _onStateSyncReceived(
    SyncEventStateSyncReceived event,
    Emitter<SyncState> emit,
  ) async {
    // Per SYNC_ENGINE.md: drift correction applies only to guest.
    if (_role == 'host') {
      return;
    }

    if (!_playerReady) {
      _logger.i(
        'SyncBloc: deferring playback:state_sync '
        '[seqNo=${event.seqNo}, hostPositionMs=${event.hostPositionMs}, '
        'isPlaying=${event.isPlaying}]',
      );
      // Only keep the latest state_sync in the queue (older ones are superseded).
      _deferredQueue.removeWhere((e) => e is SyncEventStateSyncReceived);
      _deferredQueue.add(event);
      return;
    }

    // If the state_sync references an older room playback command than we've already
    // applied, ignore it â€” a more recent play/pause/seek was applied.
    if (event.seqNo > 0 && event.seqNo < _lastAppliedSeqNo) {
      _logger.d(
        'SyncBloc: ignoring stale state_sync '
        '[seqNo=${event.seqNo} < lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    // Post-command cooldown: skip drift enforcement while the player is still settling
    // after a recent authoritative command (play/seek/deferred flush/correction seek).
    final msSinceLastCommand = now - _lastAuthoritativeCommandAtMs;
    if (_lastAuthoritativeCommandAtMs > 0 &&
        msSinceLastCommand < _kPostCommandCooldownMs) {
      _logger.d(
        'SyncBloc: skipping state_sync drift check — '
        'post-command cooldown [${msSinceLastCommand}ms / ${_kPostCommandCooldownMs}ms]',
      );
      return;
    }

    // ageMs = transit time from server to client (clock-offset-adjusted).
    // Clock offset converts client time to server time reference, eliminating
    // systematic skew from the elapsed-time estimate.
    final adjustedNow = now + _clockOffsetMs;
    final rawAgeMs = adjustedNow - event.serverTimestampMs;
    final ageMs = rawAgeMs.clamp(0, 30000);
    final adjustedHostPositionMs = event.hostPositionMs + ageMs;

    final currentGuestPositionMs =
        _playerController.currentPosition.inMilliseconds;
    final driftMs = adjustedHostPositionMs - currentGuestPositionMs;

    _logger.d(
      'SyncBloc: state_sync drift check — '
      'hostPositionMs=${event.hostPositionMs}, rawAgeMs=${rawAgeMs}ms, '
      'clampedAgeMs=${ageMs}ms, '
      'adjustedHostPositionMs=$adjustedHostPositionMs, '
      'guestPositionMs=$currentGuestPositionMs, driftMs=$driftMs',
    );

    if (driftMs.abs() > AppConstants.kDriftThresholdMs) {
      _consecutiveDriftHits++;
      _logger.d(
        'SyncBloc: drift exceeds threshold '
        '[consecutiveHits=$_consecutiveDriftHits / $_kRequiredDriftHits]',
      );

      // Hysteresis: require multiple consecutive breaches before correcting.
      // This prevents single-cycle jitter from triggering unnecessary seeks.
      if (_consecutiveDriftHits < _kRequiredDriftHits) {
        return;
      }

      if (_shouldThrottleCorrection()) {
        _logger.w(
          'SyncBloc: excessive drift detected, correction throttled '
          '[drift_ms=$driftMs]',
        );
        add(const SyncEventExcessiveDrift());
        return;
      }

      _correctionTimestamps.add(now);
      _consecutiveDriftHits = 0;

      _logger.i(
        'SyncBloc: correction seek — '
        'drift_ms=$driftMs, '
        'adjusted_host_position_ms=$adjustedHostPositionMs, '
        'guest_position_ms=$currentGuestPositionMs, '
        'correction_triggered=true',
      );

      await _playerController.pause();
      await _playerController.seekTo(
        Duration(milliseconds: adjustedHostPositionMs),
      );

      // Mark as authoritative to prevent immediate re-correction on next state_sync.
      _lastAuthoritativeCommandAtMs = DateTime.now().millisecondsSinceEpoch;

      if (event.isPlaying) {
        await _playerController.play();
        if (isClosed) return;
        emit(const SyncStateSyncing());
      } else {
        if (isClosed) return;
        emit(const SyncStatePaused());
      }
    } else {
      // Drift within acceptable range — reset consecutive counter.
      _consecutiveDriftHits = 0;
    }
  }

  /// Internal: flush the deferred command queue using latest-intent reconciliation.
  /// Dispatched by setPlayerReady(true) via _SyncEventFlushDeferred.
  Future<void> _onFlushDeferred(
    _SyncEventFlushDeferred event,
    Emitter<SyncState> emit,
  ) async {
    await _flushDeferredQueue(emit);
  }

  /// Whether we are in a post-seek or post-resume cooldown for buffering.
  bool _isInBufferingCooldown() {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Post-seek cooldown
    if (_lastSeekAppliedAtMs > 0 &&
        now - _lastSeekAppliedAtMs < _kPostSeekCooldownMs) {
      final posMs = _playerController.currentPosition.inMilliseconds;
      if ((posMs - _lastSeekTargetMs).abs() < _kPositionToleranceMs) {
        return true;
      }
    }
    // Post-resume cooldown
    if (_lastBufferingResumeAtMs > 0 &&
        now - _lastBufferingResumeAtMs < _kPostResumeCooldownMs) {
      return true;
    }
    return false;
  }

  Future<void> _onPlayerStalled(
    SyncEventPlayerStalled event,
    Emitter<SyncState> emit,
  ) async {
    // Suppress stalls during post-seek / post-resume cooldown.
    if (_isInBufferingCooldown()) {
      _logger.d('[BUFFERING_STALL_IGNORED_COOLDOWN]');
      return;
    }

    if (!_localStallSent) {
      _localStallSent = true;
      _wasPlayingBeforeBuffering = _playerController.isPlaying;
      final positionMs = _playerController.currentPosition.inMilliseconds;

      // Deduplicate: same position ± tolerance as last stall → skip.
      if (_lastStallPositionMs != null &&
          (positionMs - _lastStallPositionMs!).abs() < _kPositionToleranceMs &&
          _currentEpisodeId != null) {
        _logger.d('[BUFFERING_STALL_IGNORED_DUPLICATE] pos=$positionMs');
        return;
      }

      _bufferingEpisodeId++;
      _currentEpisodeId = _bufferingEpisodeId;
      _lastStallPositionMs = positionMs;

      _logger.i(
        '[BUFFERING_EPISODE_START] id=$_currentEpisodeId pos=$positionMs',
      );
      try {
        await _roomRepository.notifyBufferingStall(
          positionMs,
          _currentEpisodeId!,
        );
        _logger.i(
          '[BUFFERING_STALL_SENT] pos=$positionMs episode=$_currentEpisodeId',
        );
      } catch (e) {
        _logger.w('SyncBloc: failed to send buffering stall notification: $e');
      }
    } else {
      _logger.d('[BUFFERING_STALL_IGNORED_ALREADY_SENT]');
    }
    if (isClosed) return;
    emit(const SyncStateBuffering());
  }

  Future<void> _onPlayerReady(
    SyncEventPlayerReady event,
    Emitter<SyncState> emit,
  ) async {
    if (_localStallSent) {
      _localStallSent = false;

      if (_currentEpisodeId == null) {
        // Harmless race: The server already resumed playback, clearing _currentEpisodeId,
        // before our local player finished buffering. We don't need to send a ready notification.
        _logger
            .d('[BUFFERING_RESOLVED_EXTERNALLY] Skipping ready notification');
        return;
      }

      try {
        await _roomRepository.notifyBufferingReady(_currentEpisodeId!);
        _logger.i('[BUFFERING_READY_SENT] episode=$_currentEpisodeId');
      } catch (e) {
        _logger.w('SyncBloc: failed to send buffering ready notification: $e');
      }
    }

    // If we're in SyncStateBuffering because of PEER stall (not local),
    // stay in buffering — the server will send buffering:resume.
    if (state is SyncStateBuffering) {
      return;
    }

    if (isClosed) return;
    if (_playerController.isPlaying) {
      emit(const SyncStateSyncing());
    } else {
      emit(const SyncStatePaused());
    }
  }

  Future<void> _onPeerStalled(
    SyncEventPeerStalled event,
    Emitter<SyncState> emit,
  ) async {
    // Ignore peer stall during cooldown (we just resumed, peer may echo stale stall).
    if (_isInBufferingCooldown()) {
      _logger.d('[PEER_STALL_IGNORED_COOLDOWN] pos=${event.positionMs}');
      return;
    }
    // Ignore if already buffering.
    if (state is SyncStateBuffering) {
      _logger.d(
        '[PEER_STALL_IGNORED_ALREADY_BUFFERING] pos=${event.positionMs}',
      );
      return;
    }

    _currentEpisodeId = event.episodeId;
    _wasPlayingBeforeBuffering = _playerController.isPlaying;
    await _playerController.pause();
    if (isClosed) return;
    _logger.i(
      'SyncBloc: peer stalled at ${event.positionMs}ms — pausing local player',
    );
    emit(const SyncStateBuffering());
  }

  Future<void> _onBufferingResumeReceived(
    SyncEventBufferingResumeReceived event,
    Emitter<SyncState> emit,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Deduplicate: ignore resume if we just applied one.
    if (_lastBufferingResumeAtMs > 0 &&
        now - _lastBufferingResumeAtMs < _kPostResumeCooldownMs) {
      _logger.d(
        '[BUFFERING_RESUME_IGNORED_DUPLICATE] pos=${event.resumePositionMs}',
      );
      return;
    }

    if (_currentEpisodeId == null) {
      // Harmless race: We received a resume from the server, but our local state wasn't
      // tracking a buffering episode. This can happen if the stall was very brief or we
      // joined mid-buffering.
      _logger.d('[BUFFERING_RESUME_WITHOUT_STALL] Ignoring resume');
      return;
    }

    if (event.episodeId != _currentEpisodeId) {
      _logger.e(
        '[BUFFERING_RESUME_MISMATCH] expected $_currentEpisodeId got ${event.episodeId}',
      );
      return;
    }

    _lastBufferingResumeAtMs = now;
    _currentEpisodeId = null;
    _lastStallPositionMs = null;

    await _playerController.seekTo(
      Duration(milliseconds: event.resumePositionMs),
    );

    // Mark as authoritative to suppress immediate drift corrections.
    _lastAuthoritativeCommandAtMs = now;

    if (_wasPlayingBeforeBuffering) {
      await _playerController.play();
      if (isClosed) return;
      emit(const SyncStateSyncing());
    } else {
      if (isClosed) return;
      emit(const SyncStatePaused());
    }
    _wasPlayingBeforeBuffering = false;
    _logger.i('[BUFFERING_RESUME_APPLIED] pos=${event.resumePositionMs}ms');
  }

  void _onExcessiveDrift(
    SyncEventExcessiveDrift event,
    Emitter<SyncState> emit,
  ) {
    emit(SyncStateDegraded(_correctionTimestamps.length));
  }

  // â”€â”€ Private helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  /// Apply a play command with time-compensated position.
  ///
  /// Time compensation ensures that even if the command is applied seconds after
  /// it was sent (e.g. player was still initializing), the guest seeks to the
  /// position the host is actually at NOW, not where it was when play was broadcast.
  Future<void> _applyPlay(
    SyncEventPlayReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    // Compute how long ago this command was issued (clock-offset-adjusted).
    final now = DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
    final elapsedMs = (now - event.serverTimestampMs).clamp(0, 30000);

    // Time-compensated target: host's position + time elapsed since broadcast
    // + host's one-way delay (hostRttMs/2).
    // Note: guestRttMs/2 is NOT added because elapsedMs (which uses clock
    // offset correction) already captures the server-to-guest transit time.
    final adjustedPositionMs =
        event.positionMs + elapsedMs + (event.hostRttMs ~/ 2);

    _logger.i(
      'SyncBloc: applying playback:play — '
      'positionMs=${event.positionMs}, elapsedMs=${elapsedMs}ms, '
      'hostRttMs=${event.hostRttMs}, guestRttMs=$_guestRttMs, '
      'clockOffsetMs=$_clockOffsetMs, '
      'adjustedPositionMs=$adjustedPositionMs, seqNo=${event.seqNo}',
    );

    await _playerController.seekTo(Duration(milliseconds: adjustedPositionMs));
    await _playerController.play();
    if (isClosed) return;
    _lastAuthoritativeCommandAtMs = DateTime.now().millisecondsSinceEpoch;
    _logger.i(
      'SyncBloc: play applied at $_lastAuthoritativeCommandAtMs '
      '[seek+play completed, adjustedPositionMs=$adjustedPositionMs]',
    );
    emit(const SyncStateSyncing());
  }

  /// Apply a pause command: pause player and seek to host's authoritative position.
  Future<void> _applyPause(
    SyncEventPauseReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    _logger.i(
      'SyncBloc: applying playback:pause â€” '
      'positionMs=${event.positionMs}, seqNo=${event.seqNo}',
    );

    await _playerController.pause();
    await _playerController.seekTo(Duration(milliseconds: event.positionMs));
    if (isClosed) return;
    emit(const SyncStatePaused());
  }

  /// Apply a seek command: seek to target, then explicitly play or pause.
  ///
  /// The `isPlaying` field from the payload determines post-seek state.
  /// Fallback: use current SyncBloc state (Syncing = playing, Paused = paused).
  ///
  /// Explicit pauseâ†’seekâ†’play/pause ensures deterministic state regardless of
  /// media_kit's auto-resume behavior, which varies across platforms.
  Future<void> _applySeek(
    SyncEventSeekReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    // Determine post-seek play state from payload, falling back to current SyncBloc state.
    final shouldPlay = event.isPlaying ?? (state is SyncStateSyncing);

    _logger.i(
      'SyncBloc: applying playback:seek — '
      'targetPositionMs=${event.targetPositionMs}, '
      'shouldPlay=$shouldPlay, seqNo=${event.seqNo}',
    );

    // Record seek target for post-seek buffering cooldown.
    _lastSeekTargetMs = event.targetPositionMs;
    _lastSeekAppliedAtMs = DateTime.now().millisecondsSinceEpoch;
    // Reset buffering episode state so post-seek buffering is suppressed.
    _localStallSent = false;
    _currentEpisodeId = null;
    _lastStallPositionMs = null;

    // Pause first to ensure deterministic state before seek completes.
    await _playerController.pause();
    await _playerController.seekTo(
      Duration(milliseconds: event.targetPositionMs),
    );

    _lastAuthoritativeCommandAtMs = DateTime.now().millisecondsSinceEpoch;

    if (shouldPlay) {
      await _playerController.play();
      if (isClosed) return;
      emit(const SyncStateSyncing());
      _logger.i(
        'SyncBloc: seek_complete — resumed playing at ${event.targetPositionMs}ms',
      );
    } else {
      if (isClosed) return;
      emit(const SyncStatePaused());
      _logger.i(
        'SyncBloc: seek_complete — staying paused at ${event.targetPositionMs}ms',
      );
    }
  }

  /// Flush the deferred command queue using latest-intent reconciliation.
  ///
  /// Scans all queued events and extracts the authoritative "latest state":
  /// - Latest position (from the highest-seqNo play/pause/seek, or latest state_sync)
  /// - Latest shouldPlay flag
  /// Then seeks to the time-compensated position and plays or pauses.
  Future<void> _flushDeferredQueue(Emitter<SyncState> emit) async {
    if (_deferredQueue.isEmpty) return;

    _logger.i(
      'SyncBloc: flushing deferred queue [size=${_deferredQueue.length}]',
    );
    for (final e in _deferredQueue) {
      _logger.d(
        'SyncBloc: deferred_item â€” ${e.runtimeType} '
        '[seqNo=${_seqNoOf(e)}, ts=${_serverTsOf(e)}]',
      );
    }

    int bestSeqNo = -1;
    int targetPositionMs = 0;
    bool shouldPlay = false;
    int serverTimestampMs = 0;
    int bestHostRttMs = 0;
    bool hasIntent = false;

    for (final event in _deferredQueue) {
      final seqNo = _seqNoOf(event);
      final ts = _serverTsOf(event);

      // Ordering: prefer higher seqNo; for equal seqNo prefer state_sync (it has
      // current position from the timer, not the stale position from the original command).
      final existingScore = bestSeqNo * 2 + (_isStateSyncEvent(event) ? 0 : 1);
      final candidateScore = seqNo * 2 + (_isStateSyncEvent(event) ? 1 : 0);

      // Fallback to timestamp ordering when seqNo == 0 (old server).
      final isNewer =
          seqNo > 0 ? candidateScore > existingScore : ts > serverTimestampMs;

      if (!isNewer && hasIntent) continue;

      if (event is SyncEventPlayReceived) {
        bestSeqNo = seqNo > 0 ? seqNo : bestSeqNo;
        serverTimestampMs = ts;
        targetPositionMs = event.positionMs;
        bestHostRttMs = event.hostRttMs;
        shouldPlay = true;
        hasIntent = true;
      } else if (event is SyncEventPauseReceived) {
        bestSeqNo = seqNo > 0 ? seqNo : bestSeqNo;
        serverTimestampMs = ts;
        targetPositionMs = event.positionMs;
        shouldPlay = false;
        hasIntent = true;
      } else if (event is SyncEventSeekReceived) {
        bestSeqNo = seqNo > 0 ? seqNo : bestSeqNo;
        serverTimestampMs = ts;
        targetPositionMs = event.targetPositionMs;
        if (event.isPlaying != null) shouldPlay = event.isPlaying!;
        hasIntent = true;
      } else if (event is SyncEventStateSyncReceived) {
        bestSeqNo = seqNo > 0 ? seqNo : bestSeqNo;
        serverTimestampMs = ts;
        targetPositionMs = event.hostPositionMs;
        shouldPlay = event.isPlaying;
        hasIntent = true;
      }
    }

    _deferredQueue.clear();

    if (!hasIntent) {
      _logger.d('SyncBloc: deferred queue had no actionable events');
      return;
    }

    // Skip if we already applied a newer command.
    if (bestSeqNo > 0 && bestSeqNo <= _lastAppliedSeqNo) {
      _logger.d(
        'SyncBloc: deferred queue result already applied '
        '[seqNo=$bestSeqNo <= lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    // Time-compensate if the authoritative state was "playing" at serverTimestampMs.
    final now = DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
    final elapsedMs = (shouldPlay && serverTimestampMs > 0)
        ? (now - serverTimestampMs).clamp(0, 30000)
        : 0;
    final adjustedPositionMs =
        targetPositionMs + elapsedMs + (bestHostRttMs ~/ 2);

    _logger.i(
      'SyncBloc: deferred_flush_applying — '
      'targetPositionMs=$targetPositionMs, elapsedMs=${elapsedMs}ms, '
      'hostRttMs=$bestHostRttMs, guestRttMs=$_guestRttMs, '
      'clockOffsetMs=$_clockOffsetMs, '
      'adjustedPositionMs=$adjustedPositionMs, shouldPlay=$shouldPlay, '
      'seqNo=$bestSeqNo',
    );

    if (bestSeqNo > 0) _lastAppliedSeqNo = bestSeqNo;

    await _playerController.pause();
    await _playerController.seekTo(Duration(milliseconds: adjustedPositionMs));
    _lastAuthoritativeCommandAtMs = DateTime.now().millisecondsSinceEpoch;

    if (shouldPlay) {
      await _playerController.play();
      if (isClosed) return;
      emit(const SyncStateSyncing());
      _logger.i(
        'SyncBloc: deferred_flush_result=playing at ${adjustedPositionMs}ms',
      );
    } else {
      if (isClosed) return;
      emit(const SyncStatePaused());
      _logger.i(
        'SyncBloc: deferred_flush_result=paused at ${adjustedPositionMs}ms',
      );
    }
  }

  static int _seqNoOf(SyncEvent event) => switch (event) {
        SyncEventPlayReceived(seqNo: final s) => s,
        SyncEventPauseReceived(seqNo: final s) => s,
        SyncEventSeekReceived(seqNo: final s) => s,
        SyncEventStateSyncReceived(seqNo: final s) => s,
        _ => 0,
      };

  static int _serverTsOf(SyncEvent event) => switch (event) {
        SyncEventPlayReceived(serverTimestampMs: final t) => t,
        SyncEventPauseReceived(serverTimestampMs: final t) => t,
        SyncEventSeekReceived(serverTimestampMs: final t) => t,
        SyncEventStateSyncReceived(serverTimestampMs: final t) => t,
        _ => 0,
      };

  static bool _isStateSyncEvent(SyncEvent event) =>
      event is SyncEventStateSyncReceived;

  bool _shouldThrottleCorrection() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _correctionTimestamps.removeWhere(
      (ts) => now - ts > AppConstants.kCorrectionSeekWindowMs,
    );
    return _correctionTimestamps.length >=
        AppConstants.kMaxCorrectionSeeksPerWindow;
  }

  @override
  Future<void> close() {
    _roomRepository.onBufferingStall = null;
    _roomRepository.onBufferingResume = null;
    _roomRepository.onPlaybackPlay = null;
    _roomRepository.onPlaybackPause = null;
    _roomRepository.onPlaybackSeek = null;
    _roomRepository.onPlaybackStateSync = null;
    return super.close();
  }
}
