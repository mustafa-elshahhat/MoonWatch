import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../logging/app_logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'player_controller.dart';

/// media_kit-based implementation of PlayerController.
/// Supports Windows, Android, Linux, macOS via libmpv backend.
class MediaKitPlayerImpl implements PlayerController {
  Player? _player;
  VideoController? _videoController;

  /// Cached Video widget — media_kit requires a stable widget reference
  /// so the native video surface (texture/surface) stays attached.
  Widget? _cachedVideoWidget;
  StreamController<PlayerEvent> _eventController =
      StreamController<PlayerEvent>.broadcast();

  /// Persistent position/duration streams that survive player re-initialization.
  /// The singleton PlayerController lives for the app's lifetime, so these
  /// controllers are never closed — they relay events from whichever underlying
  /// Player is currently active.
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();

  final AppLogger _logger = AppLogger('MediaKitPlayer');

  // Track subscriptions for cleanup.
  final List<StreamSubscription> _subscriptions = [];
  bool _isBuffering = false;
  bool _hasCompleted = false;

  bool _disposed = false;
  bool _disposing = false;
  bool _initialized = false;

  /// Serializes initialize / dispose so they never overlap.
  Completer<void>? _lifecycleLock;

  /// Unique ID for the current media session to ignore stale async events.
  int _mediaSessionId = 0;

  /// Latch to ensure we only emit one fatal error per media session.
  bool _fatalErrorEmittedForSession = false;

  /// Currently playing URL for context in error logs.
  String? _currentStreamUrl;

  /// Consecutive transient error count. Reset on any successful playback event.
  int _transientErrorCount = 0;

  /// Threshold: if this many consecutive transient errors occur without any
  /// successful playback event in between, escalate to a fatal error.
  static const int _maxTransientErrors = 30;

  /// Transient mpv error patterns that should be logged as warnings,
  /// not propagated as fatal PlayerEventError. These occur normally during
  /// HLS/IPTV segment switches and codec initialization.
  static final List<RegExp> _transientErrorPatterns = [
    RegExp(r'Error decoding audio', caseSensitive: false),
    RegExp(r'Error decoding video', caseSensitive: false),
    RegExp(r'Failed to create EGL surface', caseSensitive: false),
    RegExp(r'Failed to create file cache', caseSensitive: false),
    RegExp(r'Could not open/read file', caseSensitive: false),
    RegExp(r'cache.* failed', caseSensitive: false),
    RegExp(r'surface.*NULL|native_window.*NULL', caseSensitive: false),
    // CDN hostname rotation causes ffmpeg to reject its own keepalive
    // connection and retry with a new one — expected behavior, not an error.
    RegExp(
      r'Cannot reuse HTTP connection for different host',
      caseSensitive: false,
    ),
    RegExp(r'keepalive request failed', caseSensitive: false),
  ];

  /// Fatal log patterns from mpv/ffmpeg that indicate the stream is unplayable.
  /// These come through stream.log (not stream.error) but represent real failures.
  static final List<RegExp> _fatalLogPatterns = [
    RegExp(r'HTTP error 4\d{2}', caseSensitive: false),
    RegExp(r'Failed to open segment', caseSensitive: false),
    RegExp(r'segment.*failed.*too many times', caseSensitive: false),
    RegExp(r'Server returned [45]\d{2}', caseSensitive: false),
  ];

  /// Consecutive fatal log hits. Reset on successful playback.
  int _fatalLogHitCount = 0;

  /// Threshold: escalate to fatal error after this many fatal log hits.
  static const int _fatalLogThreshold = 3;

  @override
  Stream<PlayerEvent> get events => _eventController.stream;

  /// Returns the persistent position stream — survives player re-initialization.
  @override
  Stream<Duration> get positionStream => _positionController.stream;

  /// Returns the persistent duration stream — survives player re-initialization.
  @override
  Stream<Duration> get durationStream => _durationController.stream;

  @override
  Duration get currentPosition => _player?.state.position ?? Duration.zero;

  @override
  Duration get duration => _player?.state.duration ?? Duration.zero;

  @override
  bool get isPlaying => _player?.state.playing ?? false;

  @override
  bool get isBuffering => _isBuffering;

  @override
  bool get isInitialized =>
      _videoController != null && _player != null && _initialized;

  /// Last fit used to create the cached video widget — used to detect when
  /// the fit mode changes and the cached widget must be invalidated.
  BoxFit _cachedFit = BoxFit.contain;

  @override
  Widget? get nativeView => buildVideoView();

  @override
  Widget? buildVideoView({BoxFit fit = BoxFit.contain}) {
    if (_videoController == null || _disposed) return null;
    // Invalidate the cached widget when fit changes so the Video widget is
    // recreated with the new BoxFit — this is a presentation-only change.
    if (_cachedVideoWidget != null && _cachedFit != fit) {
      _cachedVideoWidget = null;
    }
    _cachedFit = fit;
    _cachedVideoWidget ??= Video(
      controller: _videoController!,
      controls: NoVideoControls,
      fill: const Color(0xFF000000),
      fit: fit,
    );
    return _cachedVideoWidget;
  }

  /// Acquire the lifecycle lock — waits for any in-flight init/dispose to finish.
  Future<void> _acquireLifecycleLock() async {
    while (_lifecycleLock != null) {
      await _lifecycleLock!.future;
    }
    _lifecycleLock = Completer<void>();
  }

  /// Release the lifecycle lock.
  void _releaseLifecycleLock() {
    final lock = _lifecycleLock;
    _lifecycleLock = null;
    lock?.complete();
  }

  @override
  Future<void> initialize(String streamUrl) async {
    await _acquireLifecycleLock();
    try {
      _currentStreamUrl = streamUrl;
      await _initializeGuarded(streamUrl);
    } finally {
      _releaseLifecycleLock();
    }
  }

  Future<void> _initializeGuarded(String streamUrl) async {
    _logger.i('[PROFILER] media_player_init_start');
    final initStartTime = DateTime.now();
    _logger.d(
      'MediaKitPlayerImpl.initialize: url=${AppLogger.sanitizeUrl(streamUrl)}',
    );

    // Reset disposed flag — we are (re-)initializing.
    _disposed = false;
    _initialized = false;

    // Make sure media kit is initialized here rather than at startup
    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      _logger.d('MediaKit already initialized');
    }

    // Recreate event controller if previously closed by dispose().
    if (_eventController.isClosed) {
      _logger.d('MediaKitPlayerImpl: recreating closed _eventController');
      _eventController = StreamController<PlayerEvent>.broadcast();
    }

    // Dispose previous player if re-initializing.
    await _disposeInternal();

    // Check if disposed during _disposeInternal (race guard).
    if (_disposed) {
      _logger.w(
        'MediaKitPlayerImpl.initialize: aborted — disposed during cleanup',
      );
      return;
    }

    try {
      // Platform-specific safe initializer
      bool initSuccess = false;
      int retries = Platform.isAndroid ? 1 : 0;

      for (int i = 0; i <= retries; i++) {
        try {
          // Yield to avoid blocking UI thread on Android
          await Future.delayed(Duration.zero);

          // Check disposed after async gap.
          if (_disposed) {
            _logger.w(
              'MediaKitPlayerImpl.initialize: aborted — disposed during retry',
            );
            return;
          }

          _player = Player(
            configuration: const PlayerConfiguration(
              // Buffer configuration for IPTV/HLS live streams.
              bufferSize: 32 * 1024 * 1024, // 32 MB demuxer buffer
              logLevel: MPVLogLevel.warn,
            ),
          );

          final mpv = _player!.platform as NativePlayer;
          await mpv.getProperty(
            'stream-pos',
          ); // Dummy property call to test pointer

          initSuccess = true;
          break; // It worked!
        } catch (e) {
          _logger.w('Player initialization failed (attempt ${i + 1}): $e');
          await _disposeInternal();
          if (i == retries) rethrow; // rethrow on last failure
        }
      }

      if (!initSuccess) {
        throw Exception('Failed to initialize Player native reference');
      }

      // Check disposed after player creation.
      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after player creation',
        );
        await _disposeInternal();
        return;
      }

      // Set mpv properties for robust IPTV/HLS playback.
      final mpv = _player!.platform as NativePlayer;
      await mpv.setProperty('cache', 'auto');
      await mpv.setProperty('demuxer-max-bytes', '32MiB');
      await mpv.setProperty('demuxer-max-back-bytes', '16MiB');
      await mpv.setProperty('force-seekable', 'yes');
      // Override default libmpv user-agent to prevent provider blocking (403).
      await mpv.setProperty(
        'http-header-fields',
        'User-Agent: VLC/3.0.16 LibVLC/3.0.16',
      );
      // Allow hardware decoding to prevent EGL/surface init failures.
      await mpv.setProperty('hwdec', 'auto-safe');
      // Normalize timestamps so VOD position always starts at 0, preventing
      // impossible positions when HLS VOD segments have non-zero base timestamps.
      await mpv.setProperty('rebase-start-time', 'yes');

      _videoController = VideoController(_player!);
      _mediaSessionId++;
      _hasCompleted = false;
      _transientErrorCount = 0;
      _fatalLogHitCount = 0;
      _fatalErrorEmittedForSession = false;

      _subscribeToStreams();

      // Check disposed after subscriptions.
      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after subscriptions',
        );
        await _disposeInternal();
        return;
      }

      _logger.d('MediaKitPlayerImpl: opening media');
      // open() with play:false so we control playback timing.
      await _player!.open(Media(streamUrl), play: false);

      // Wait briefly for the player to report readiness.
      // media_kit fires stream events asynchronously after open().
      await _waitForReady();

      // Check disposed after waitForReady.
      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after waitForReady',
        );
        await _disposeInternal();
        return;
      }

      // Force metadata/first frame materialization without autoplay
      // media_kit sometimes fails to populate duration/frames on play:false
      // until playback begins or we explicitly buffer it.
      await _player!.play();
      await Future.delayed(const Duration(milliseconds: 50));
      if (_disposed) return; // Guard async gap.
      await _player!.pause();
      await _player!.seek(Duration.zero);

      if (_disposed) return; // Guard after seek.

      _initialized = true;

      final w = _player!.state.width;
      final h = _player!.state.height;
      final dims = (w != null && h != null) ? '${w}x$h' : 'pending';
      _logger.i(
        'MediaKitPlayerImpl.initialize: success, '
        'duration=${_player!.state.duration}, width=$dims',
      );
      _eventController.add(const PlayerEvent(PlayerEventType.initialized));

      final elapsed = DateTime.now().difference(initStartTime).inMilliseconds;
      _logger.i('[PROFILER] media_player_init_end: ${elapsed}ms');
    } catch (e, st) {
      _logger.e('MediaKitPlayerImpl.initialize: failed — $e\n$st');
      await _disposeInternal();
      rethrow;
    }
  }

  Future<void> _waitForReady() async {
    final waitStartMs = DateTime.now().millisecondsSinceEpoch;
    final completer = Completer<void>();
    Timer? timeout;
    String? initError;

    // We no longer complete immediately on duration. We need video dimensions
    // to ensure the video track is actually demuxed and ready to render.
    final durSub = _player!.stream.duration.listen((d) {
      // Just keep track, don't complete.
    });

    // Strong readiness indicator: video dimensions detected.
    final widthSub = _player!.stream.width.listen((w) {
      if (!completer.isCompleted && w != null && w > 0) {
        completer.complete();
      }
    });

    // Failure indicator: error during initialization.
    final errSub = _player!.stream.error.listen((err) {
      if (err.isNotEmpty) {
        initError ??= err; // Keep first error.
        if (!completer.isCompleted) {
          completer.complete(); // Unblock — will check error after.
        }
      }
    });

    // Failure indicator: fatal log messages (HLS 403, segment failures).
    final logSub = _player!.stream.log.listen((log) {
      if (_fatalLogPatterns.any((p) => p.hasMatch(log.text))) {
        initError ??= log.text;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    // Wait up to 15 seconds for video to materialize.
    timeout = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future;
    timeout.cancel();
    await durSub.cancel();
    await widthSub.cancel();
    await errSub.cancel();
    await logSub.cancel();

    // Validate: did media actually load?
    final d = _player!.state.duration;
    final w = _player!.state.width;
    final hasDuration = d > Duration.zero;
    final hasVideo = w != null && w > 0;

    if (initError != null) {
      final isFatalPattern = _fatalLogPatterns.any(
        (p) => p.hasMatch(initError!),
      );
      if (isFatalPattern || (!hasDuration && !hasVideo)) {
        _logger.e('_waitForReady: init failed — $initError');
        throw Exception('Stream failed to load: $initError');
      }
      _logger.w('_waitForReady: init warning (media detected): $initError');
    }

    if (hasVideo) {
      final waitElapsedMs = DateTime.now().millisecondsSinceEpoch - waitStartMs;
      _logger.i(
        '_waitForReady: video ready [elapsed=${waitElapsedMs}ms, '
        'hasDuration=$hasDuration, hasVideo=$hasVideo]',
      );
      return;
    }

    // Fallback: no video, but has duration (possibly audio-only VOD/radio).
    if (hasDuration) {
      final waitElapsedMs = DateTime.now().millisecondsSinceEpoch - waitStartMs;
      _logger.w(
        '_waitForReady: Audio-only or slow video [elapsed=${waitElapsedMs}ms, '
        'hasDuration=$hasDuration, hasVideo=$hasVideo]',
      );
      return;
    }

    // No error, no media — silent failure.
    throw Exception('Stream failed to load: no playable media detected.');
  }

  void _subscribeToStreams() {
    final sessionId = _mediaSessionId;

    // Forward position to the persistent stream with bounds validation.
    // Some HLS VOD streams have segment timestamps that don't normalize cleanly,
    // causing libmpv to report positions beyond the manifest duration. Guard here
    // so downstream consumers never see impossible values.
    _subscriptions.add(
      _player!.stream.position.listen((p) {
        if (_disposed || sessionId != _mediaSessionId) {
          return; // Guard: do not emit after dispose.
        }
        final dur = _player?.state.duration ?? Duration.zero;
        if (p < Duration.zero) {
          _logger.w('MediaKitPlayerImpl: position negative ($p) — ignoring');
          return;
        }
        if (dur > Duration.zero && p > dur + const Duration(seconds: 10)) {
          _logger.w(
            'MediaKitPlayerImpl: position out of bounds '
            '(pos=$p, dur=$dur) — ignoring',
          );
          return;
        }
        if (!_positionController.isClosed) _positionController.add(p);
      }),
    );

    // Forward duration to the persistent stream.
    _subscriptions.add(
      _player!.stream.duration.listen((d) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (!_durationController.isClosed) _durationController.add(d);
      }),
    );

    // Playing state changes.
    _subscriptions.add(
      _player!.stream.playing.listen((playing) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (playing) {
          _transientErrorCount = 0; // Reset on successful playback.
          _fatalLogHitCount = 0;
          _eventController.add(
            PlayerEvent(PlayerEventType.playing, position: currentPosition),
          );
        } else if (!_hasCompleted) {
          _eventController.add(
            PlayerEvent(PlayerEventType.paused, position: currentPosition),
          );
        }
      }),
    );

    // Buffering state changes.
    _subscriptions.add(
      _player!.stream.buffering.listen((buffering) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (buffering && !_isBuffering) {
          _isBuffering = true;
          _eventController.add(
            PlayerEvent(PlayerEventType.buffering, position: currentPosition),
          );
        } else if (!buffering && _isBuffering) {
          _isBuffering = false;
          _transientErrorCount = 0; // Reset on successful buffer recovery.
          _fatalLogHitCount = 0;
          _eventController.add(
            PlayerEvent(
              PlayerEventType.bufferingEnd,
              position: currentPosition,
            ),
          );
        }
      }),
    );

    // Completed (stream ended).
    _subscriptions.add(
      _player!.stream.completed.listen((completed) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (completed) {
          _hasCompleted = true;
          _eventController.add(const PlayerEvent(PlayerEventType.ended));
        }
      }),
    );

    // Error events — filter transient mpv warnings from fatal errors.
    _subscriptions.add(
      _player!.stream.error.listen((error) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (_fatalErrorEmittedForSession) return;
        if (error.isEmpty) return;

        final isTransient = _transientErrorPatterns.any(
          (p) => p.hasMatch(error),
        );
        if (isTransient) {
          _transientErrorCount++;
          if (_transientErrorCount >= _maxTransientErrors) {
            _fatalErrorEmittedForSession = true;
            _logger.e(
              'MediaKitPlayerImpl: too many transient errors, escalating to fatal. '
              'url=${AppLogger.sanitizeUrl(_currentStreamUrl ?? '')}, sessionId=$sessionId',
            );
            _eventController.add(
              const PlayerEvent(
                PlayerEventType.error,
                errorMessage:
                    'Playback failed: stream may be unsupported or unavailable.',
              ),
            );
          } else {
            _logger.w(
              'MediaKitPlayerImpl: transient error ($_transientErrorCount/$_maxTransientErrors) — $error',
            );
          }
        } else {
          _fatalErrorEmittedForSession = true;
          _logger.e(
            'MediaKitPlayerImpl: playback error — $error. '
            'url=${AppLogger.sanitizeUrl(_currentStreamUrl ?? '')}, sessionId=$sessionId',
          );
          _eventController.add(
            PlayerEvent(PlayerEventType.error, errorMessage: error),
          );
        }
      }),
    );

    // Log events — detect fatal HLS/HTTP patterns that only surface here.
    _subscriptions.add(
      _player!.stream.log.listen((log) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (_fatalErrorEmittedForSession) return;
        // Skip debug logging for known transient noise (e.g. CDN keepalive
        // retries) to avoid flooding the log file on every HLS segment.
        final isTransientLog = _transientErrorPatterns.any(
          (p) => p.hasMatch(log.text),
        );
        if (!isTransientLog) {
          _logger.d('MediaKitPlayerImpl [${log.prefix}]: ${log.text}');
        }

        final isFatal = _fatalLogPatterns.any((p) => p.hasMatch(log.text));
        if (isFatal) {
          _fatalLogHitCount++;
          if (_fatalLogHitCount >= _fatalLogThreshold) {
            _fatalErrorEmittedForSession = true;
            _logger.e(
              'MediaKitPlayerImpl: stream unplayable — repeated HLS/HTTP failures. '
              'url=${AppLogger.sanitizeUrl(_currentStreamUrl ?? '')}, sessionId=$sessionId',
            );
            _eventController.add(
              const PlayerEvent(
                PlayerEventType.error,
                errorMessage:
                    'Stream access denied or unavailable (HTTP error).',
              ),
            );
          } else {
            _logger.w(
              'MediaKitPlayerImpl: fatal log hit '
              '($_fatalLogHitCount/$_fatalLogThreshold) — [${log.prefix}] ${log.text}',
            );
          }
        }
      }),
    );
  }

  @override
  Future<void> play() async {
    if (_disposed || _disposing) return; // Guard: no calls after dispose.
    await _player?.play();
    // Playing event emitted by stream subscription.
  }

  @override
  Future<void> pause() async {
    if (_disposed || _disposing) return;
    await _player?.pause();
    // Paused event emitted by stream subscription.
  }

  @override
  Future<void> seekTo(Duration position) async {
    if (_disposed || _disposing) return;
    await _player?.seek(position);
    if (!_disposed && !_eventController.isClosed) {
      _eventController.add(
        PlayerEvent(PlayerEventType.seekCompleted, position: position),
      );
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    if (_disposed || _disposing) return;
    await _player?.setVolume(volume * 100.0);
  }

  @override
  Future<void> dispose() async {
    _logger.d('MediaKitPlayerImpl.dispose');
    _logger.i('MediaKitPlayerImpl.dispose');

    await _acquireLifecycleLock();
    try {
      _disposing = true;
      _disposed = true;
      _initialized = false;
      await _disposeInternal();
      await _eventController.close();
      _disposing = false;
    } finally {
      _releaseLifecycleLock();
    }
  }

  Future<void> _disposeInternal() async {
    final snapshot = List<StreamSubscription>.of(_subscriptions);
    _subscriptions.clear();
    for (final sub in snapshot) {
      await sub.cancel();
    }
    await _player?.dispose();
    _player = null;
    _videoController = null;
    _cachedVideoWidget = null;
    _isBuffering = false;
    _hasCompleted = false;
    _transientErrorCount = 0;
    _fatalLogHitCount = 0;
    _fatalErrorEmittedForSession = false;
    // Emit reset to persistent streams so UI (SmartPlaybackControls etc.)
    // sees position=0/duration=0 immediately when a new media starts loading.
    if (!_positionController.isClosed) _positionController.add(Duration.zero);
    if (!_durationController.isClosed) _durationController.add(Duration.zero);
  }
}
