import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../core/logging/app_logger.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/player_controller.dart';
import '../../features/room/repository/room_repository.dart';

sealed class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncEventPlayReceived extends SyncEvent {
  final int positionMs;
  final int serverTimestampMs;
  final int hostRttMs;

  final int seqNo;
  final double playbackRate;

  const SyncEventPlayReceived({
    required this.positionMs,
    required this.serverTimestampMs,
    required this.hostRttMs,
    this.seqNo = 0,
    this.playbackRate = 1.0,
  });

  @override
  List<Object?> get props =>
      [positionMs, serverTimestampMs, hostRttMs, seqNo, playbackRate];
}

class SyncEventPauseReceived extends SyncEvent {
  final int positionMs;

  final int serverTimestampMs;

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

  final int serverTimestampMs;

  final int seqNo;

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

  final int seqNo;
  final double playbackRate;

  const SyncEventStateSyncReceived({
    required this.hostPositionMs,
    required this.isPlaying,
    required this.serverTimestampMs,
    this.seqNo = 0,
    this.playbackRate = 1.0,
  });

  @override
  List<Object?> get props => [
        hostPositionMs,
        isPlaying,
        serverTimestampMs,
        seqNo,
        playbackRate,
      ];
}

class SyncEventSpeedReceived extends SyncEvent {
  final double speed;
  final int serverTimestampMs;

  const SyncEventSpeedReceived({
    required this.speed,
    required this.serverTimestampMs,
  });

  @override
  List<Object?> get props => [speed, serverTimestampMs];
}

class SyncEventPlayerStalled extends SyncEvent {
  const SyncEventPlayerStalled();
}

class SyncEventPlayerReady extends SyncEvent {
  const SyncEventPlayerReady();
}

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

class SyncEventBufferingResumeReceived extends SyncEvent {
  final int resumePositionMs;
  final int episodeId;
  final bool isPlaying;

  const SyncEventBufferingResumeReceived({
    required this.resumePositionMs,
    required this.episodeId,
    required this.isPlaying,
  });

  @override
  List<Object?> get props => [resumePositionMs, episodeId, isPlaying];
}

class SyncEventExcessiveDrift extends SyncEvent {
  const SyncEventExcessiveDrift();
}

class _SyncEventFlushDeferred extends SyncEvent {
  const _SyncEventFlushDeferred();
}

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

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final PlayerController _playerController;
  final RoomRepository _roomRepository;
  final AppLogger _logger = AppLogger('SyncBloc');

  String _role = 'guest';

  int _guestRttMs = AppConstants.kDefaultRttMs;
  final List<int> _correctionTimestamps = [];

  int _clockOffsetMs = 0;

  bool _localStallSent = false;

  bool _playerReady = false;
  String? _playerContentKey;
  String? _lastNotifiedReadyContentKey;
  double _playbackRate = 1.0;

  final List<SyncEvent> _deferredQueue = [];

  int _lastAppliedSeqNo = 0;

  int _lastAuthoritativeCommandAtMs = 0;

  static const int _kPostCommandCooldownMs = 3000;

  int _bufferingEpisodeId = 0;
  int? _currentEpisodeId;
  int? _lastStallPositionMs;
  int _lastBufferingResumeAtMs = 0;
  int _lastSeekTargetMs = 0;
  int _lastSeekAppliedAtMs = 0;
  static const int _kPostSeekCooldownMs = 3000;
  static const int _kPostResumeCooldownMs = 3000;
  static const int _kPositionToleranceMs = 2000;

  int _consecutiveDriftHits = 0;

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
    on<SyncEventSpeedReceived>(_onSpeedReceived);
    on<SyncEventExcessiveDrift>(_onExcessiveDrift);
    on<_SyncEventFlushDeferred>(_onFlushDeferred);

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
          isPlaying: payload.isPlaying,
        ),
      );
    };

    _roomRepository.onPlaybackPlay = (payload) {
      add(
        SyncEventPlayReceived(
          positionMs: payload.positionMs,
          serverTimestampMs: payload.serverTimestampMs,
          hostRttMs: payload.hostRttMs,
          seqNo: payload.seqNo,
          playbackRate: payload.playbackRate,
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
          playbackRate: payload.playbackRate,
        ),
      );
    };
    _roomRepository.onPlaybackSpeed = (payload) {
      add(
        SyncEventSpeedReceived(
          speed: payload.speed,
          serverTimestampMs: payload.serverTimestampMs,
        ),
      );
    };
  }

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

  void updateClockOffset(int offsetMs) {
    _clockOffsetMs = offsetMs;
  }

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

      _consecutiveDriftHits = 0;

      if (_deferredQueue.isNotEmpty) {
        _logger.d(
          'SyncBloc: player not ready — clearing ${_deferredQueue.length} deferred commands',
        );
        _deferredQueue.clear();
      }
    }
  }

  Future<void> _onPlayReceived(
    SyncEventPlayReceived event,
    Emitter<SyncState> emit,
  ) async {
    final receivedAtMs = DateTime.now().millisecondsSinceEpoch;

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
    if (_role == 'host') {
      return;
    }

    if (state is SyncStateBuffering) {
      _logger.d('SyncBloc: ignoring state_sync during buffering');
      return;
    }

    if (!_playerReady) {
      _logger.i(
        'SyncBloc: deferring playback:state_sync '
        '[seqNo=${event.seqNo}, hostPositionMs=${event.hostPositionMs}, '
        'isPlaying=${event.isPlaying}]',
      );

      _deferredQueue.removeWhere((e) => e is SyncEventStateSyncReceived);
      _deferredQueue.add(event);
      return;
    }

    if (event.seqNo > 0 && event.seqNo < _lastAppliedSeqNo) {
      _logger.d(
        'SyncBloc: ignoring stale state_sync '
        '[seqNo=${event.seqNo} < lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    final msSinceLastCommand = now - _lastAuthoritativeCommandAtMs;
    if (_lastAuthoritativeCommandAtMs > 0 &&
        msSinceLastCommand < _kPostCommandCooldownMs) {
      _logger.d(
        'SyncBloc: skipping state_sync drift check — '
        'post-command cooldown [${msSinceLastCommand}ms / ${_kPostCommandCooldownMs}ms]',
      );
      return;
    }

    final adjustedNow = now + _clockOffsetMs;
    final rawAgeMs = adjustedNow - event.serverTimestampMs;
    final ageMs = rawAgeMs.clamp(0, 30000);
    final adjustedHostPositionMs =
        event.hostPositionMs + (ageMs * event.playbackRate).toInt();

    final currentGuestPositionMs =
        _playerController.currentPosition.inMilliseconds;
    final driftMs = adjustedHostPositionMs - currentGuestPositionMs;

    _logger.d(
      'SyncBloc: state_sync drift check — '
      'hostPositionMs=${event.hostPositionMs}, rawAgeMs=${rawAgeMs}ms, '
      'clampedAgeMs=${ageMs}ms, '
      'adjustedHostPositionMs=$adjustedHostPositionMs, '
      'guestPositionMs=$currentGuestPositionMs, driftMs=$driftMs, playbackRate=${event.playbackRate}',
    );

    if (event.playbackRate != _playbackRate) {
      _logger.i(
          'SyncBloc: applying playback:speed from state_sync — speed=${event.playbackRate}');
      _playbackRate = event.playbackRate;
      await _playerController.setPlaybackSpeed(_playbackRate);
    }

    if (driftMs.abs() > AppConstants.kDriftThresholdMs) {
      _consecutiveDriftHits++;
      _logger.d(
        'SyncBloc: drift exceeds threshold '
        '[consecutiveHits=$_consecutiveDriftHits / $_kRequiredDriftHits]',
      );

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
      _consecutiveDriftHits = 0;
    }
  }

  Future<void> _onFlushDeferred(
    _SyncEventFlushDeferred event,
    Emitter<SyncState> emit,
  ) async {
    await _flushDeferredQueue(emit);
  }

  bool _isInBufferingCooldown() {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_lastSeekAppliedAtMs > 0 &&
        now - _lastSeekAppliedAtMs < _kPostSeekCooldownMs) {
      final posMs = _playerController.currentPosition.inMilliseconds;
      if ((posMs - _lastSeekTargetMs).abs() < _kPositionToleranceMs) {
        return true;
      }
    }

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
    if (_isInBufferingCooldown()) {
      _logger.d('[BUFFERING_STALL_IGNORED_COOLDOWN]');
      return;
    }

    if (!_localStallSent) {
      _localStallSent = true;
      final positionMs = _playerController.currentPosition.inMilliseconds;

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
        _logger.d(
          '[BUFFERING_RESOLVED_EXTERNALLY] Skipping ready notification',
        );
        return;
      }

      try {
        await _roomRepository.notifyBufferingReady(_currentEpisodeId!);
        _logger.i('[BUFFERING_READY_SENT] episode=$_currentEpisodeId');
      } catch (e) {
        _logger.w('SyncBloc: failed to send buffering ready notification: $e');
      }
    }

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
    if (_isInBufferingCooldown()) {
      _logger.d('[PEER_STALL_IGNORED_COOLDOWN] pos=${event.positionMs}');
      return;
    }

    if (state is SyncStateBuffering) {
      _logger.d(
        '[PEER_STALL_IGNORED_ALREADY_BUFFERING] pos=${event.positionMs}',
      );
      return;
    }

    _currentEpisodeId = event.episodeId;
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

    if (_lastBufferingResumeAtMs > 0 &&
        now - _lastBufferingResumeAtMs < _kPostResumeCooldownMs) {
      _logger.d(
        '[BUFFERING_RESUME_IGNORED_DUPLICATE] pos=${event.resumePositionMs}',
      );
      return;
    }

    if (_currentEpisodeId == null) {
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

    _lastAuthoritativeCommandAtMs = now;

    if (event.isPlaying) {
      await _playerController.play();
      if (isClosed) return;
      emit(const SyncStateSyncing());
    } else {
      await _playerController.pause();
      if (isClosed) return;
      emit(const SyncStatePaused());
    }
    _logger.i(
        '[BUFFERING_RESUME_APPLIED] pos=${event.resumePositionMs}ms isPlaying=${event.isPlaying}');
  }

  Future<void> _onSpeedReceived(
    SyncEventSpeedReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (_role == 'host') return;

    _logger
        .i('SyncBloc: applying playback:speed received — speed=${event.speed}');
    _playbackRate = event.speed;
    await _playerController.setPlaybackSpeed(_playbackRate);
  }

  void _onExcessiveDrift(
    SyncEventExcessiveDrift event,
    Emitter<SyncState> emit,
  ) {
    emit(SyncStateDegraded(_correctionTimestamps.length));
  }

  Future<void> _applyPlay(
    SyncEventPlayReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    final now = DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
    final elapsedMs = (now - event.serverTimestampMs).clamp(0, 30000);

    _playbackRate = event.playbackRate;
    await _playerController.setPlaybackSpeed(_playbackRate);

    final adjustedPositionMs = event.positionMs +
        (elapsedMs * _playbackRate).toInt() +
        (event.hostRttMs ~/ 2);

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

  Future<void> _applyPause(
    SyncEventPauseReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    _logger.i(
      'SyncBloc: applying playback:pause — '
      'positionMs=${event.positionMs}, seqNo=${event.seqNo}',
    );

    await _playerController.pause();
    await _playerController.seekTo(Duration(milliseconds: event.positionMs));
    if (isClosed) return;
    emit(const SyncStatePaused());
  }

  Future<void> _applySeek(
    SyncEventSeekReceived event,
    Emitter<SyncState> emit,
  ) async {
    if (event.seqNo > 0) _lastAppliedSeqNo = event.seqNo;

    final shouldPlay = event.isPlaying ?? (state is SyncStateSyncing);

    _logger.i(
      'SyncBloc: applying playback:seek — '
      'targetPositionMs=${event.targetPositionMs}, '
      'shouldPlay=$shouldPlay, seqNo=${event.seqNo}',
    );

    _lastSeekTargetMs = event.targetPositionMs;
    _lastSeekAppliedAtMs = DateTime.now().millisecondsSinceEpoch;

    _localStallSent = false;
    _currentEpisodeId = null;
    _lastStallPositionMs = null;

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

  Future<void> _flushDeferredQueue(Emitter<SyncState> emit) async {
    if (_deferredQueue.isEmpty) return;

    _logger.i(
      'SyncBloc: flushing deferred queue [size=${_deferredQueue.length}]',
    );
    for (final e in _deferredQueue) {
      _logger.d(
        'SyncBloc: deferred_item — ${e.runtimeType} '
        '[seqNo=${_seqNoOf(e)}, ts=${_serverTsOf(e)}]',
      );
    }

    int bestSeqNo = -1;
    int targetPositionMs = 0;
    bool shouldPlay = false;
    int serverTimestampMs = 0;
    int bestHostRttMs = 0;
    double bestPlaybackRate = _playbackRate;
    bool hasIntent = false;

    for (final event in _deferredQueue) {
      final seqNo = _seqNoOf(event);
      final ts = _serverTsOf(event);

      final existingScore = bestSeqNo * 2 + (_isStateSyncEvent(event) ? 0 : 1);
      final candidateScore = seqNo * 2 + (_isStateSyncEvent(event) ? 1 : 0);

      final isNewer =
          seqNo > 0 ? candidateScore > existingScore : ts > serverTimestampMs;

      if (!isNewer && hasIntent) continue;

      if (event is SyncEventPlayReceived) {
        bestSeqNo = seqNo > 0 ? seqNo : bestSeqNo;
        serverTimestampMs = ts;
        targetPositionMs = event.positionMs;
        bestHostRttMs = event.hostRttMs;
        bestPlaybackRate = event.playbackRate;
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
        bestPlaybackRate = event.playbackRate;
        shouldPlay = event.isPlaying;
        hasIntent = true;
      }
    }

    _deferredQueue.clear();

    if (!hasIntent) {
      _logger.d('SyncBloc: deferred queue had no actionable events');
      return;
    }

    if (bestSeqNo > 0 && bestSeqNo <= _lastAppliedSeqNo) {
      _logger.d(
        'SyncBloc: deferred queue result already applied '
        '[seqNo=$bestSeqNo <= lastApplied=$_lastAppliedSeqNo]',
      );
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
    final elapsedMs = (shouldPlay && serverTimestampMs > 0)
        ? (now - serverTimestampMs).clamp(0, 30000)
        : 0;
    _playbackRate = bestPlaybackRate;
    await _playerController.setPlaybackSpeed(_playbackRate);

    final adjustedPositionMs = targetPositionMs +
        (elapsedMs * _playbackRate).toInt() +
        (bestHostRttMs ~/ 2);

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
    _roomRepository.clearCallbacks();
    return super.close();
  }
}
