import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../logging/app_logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'player_controller.dart';

class MediaKitPlayerImpl implements PlayerController {
  Player? _player;
  VideoController? _videoController;

  Widget? _cachedVideoWidget;
  StreamController<PlayerEvent> _eventController =
      StreamController<PlayerEvent>.broadcast();

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  final AppLogger _logger = AppLogger('MediaKitPlayer');

  final List<StreamSubscription> _subscriptions = [];
  bool _isBuffering = false;
  bool _hasCompleted = false;

  bool _disposed = false;
  bool _disposing = false;
  bool _initialized = false;

  Completer<void>? _lifecycleLock;

  int _mediaSessionId = 0;

  bool _fatalErrorEmittedForSession = false;

  String? _currentStreamUrl;

  int _transientErrorCount = 0;

  static const int _maxTransientErrors = 30;

  static final List<RegExp> _transientErrorPatterns = [
    RegExp(r'Error decoding audio', caseSensitive: false),
    RegExp(r'Error decoding video', caseSensitive: false),
    RegExp(r'Failed to create EGL surface', caseSensitive: false),
    RegExp(r'Failed to create file cache', caseSensitive: false),
    RegExp(r'Could not open/read file', caseSensitive: false),
    RegExp(r'cache.* failed', caseSensitive: false),
    RegExp(r'surface.*NULL|native_window.*NULL', caseSensitive: false),
    RegExp(
      r'Cannot reuse HTTP connection for different host',
      caseSensitive: false,
    ),
    RegExp(r'keepalive request failed', caseSensitive: false),
  ];

  static final List<RegExp> _fatalLogPatterns = [
    RegExp(r'HTTP error 4\d{2}', caseSensitive: false),
    RegExp(r'Failed to open segment', caseSensitive: false),
    RegExp(r'segment.*failed.*too many times', caseSensitive: false),
    RegExp(r'Server returned [45]\d{2}', caseSensitive: false),
  ];

  int _fatalLogHitCount = 0;

  static const int _fatalLogThreshold = 3;

  @override
  Stream<PlayerEvent> get events => _eventController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

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

  @override
  double get playbackSpeed => _player?.state.rate ?? 1.0;

  @override
  Stream<double> get playbackSpeedStream => _speedController.stream;

  @override
  double get volume => (_player?.state.volume ?? 100.0) / 100.0;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  BoxFit _cachedFit = BoxFit.contain;

  @override
  Widget? get nativeView => buildVideoView();

  @override
  Widget? buildVideoView({BoxFit fit = BoxFit.contain}) {
    if (_videoController == null || _disposed) return null;

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

  Future<void> _acquireLifecycleLock() async {
    while (_lifecycleLock != null) {
      await _lifecycleLock!.future;
    }
    _lifecycleLock = Completer<void>();
  }

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

    _disposed = false;
    _initialized = false;

    try {
      MediaKit.ensureInitialized();
    } catch (e) {
      _logger.d('MediaKit already initialized');
    }

    if (_eventController.isClosed) {
      _logger.d('MediaKitPlayerImpl: recreating closed _eventController');
      _eventController = StreamController<PlayerEvent>.broadcast();
    }

    await _disposeInternal();

    if (_disposed) {
      _logger.w(
        'MediaKitPlayerImpl.initialize: aborted — disposed during cleanup',
      );
      return;
    }

    try {
      bool initSuccess = false;
      int retries = Platform.isAndroid ? 1 : 0;

      for (int i = 0; i <= retries; i++) {
        try {
          await Future.delayed(Duration.zero);

          if (_disposed) {
            _logger.w(
              'MediaKitPlayerImpl.initialize: aborted — disposed during retry',
            );
            return;
          }

          _player = Player(
            configuration: const PlayerConfiguration(
              bufferSize: 32 * 1024 * 1024,
              logLevel: MPVLogLevel.warn,
            ),
          );

          final mpv = _player!.platform as NativePlayer;
          await mpv.getProperty(
            'stream-pos',
          );

          initSuccess = true;
          break;
        } catch (e) {
          _logger.w('Player initialization failed (attempt ${i + 1}): $e');
          await _disposeInternal();
          if (i == retries) rethrow;
        }
      }

      if (!initSuccess) {
        throw Exception('Failed to initialize Player native reference');
      }

      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after player creation',
        );
        await _disposeInternal();
        return;
      }

      final mpv = _player!.platform as NativePlayer;
      await mpv.setProperty('cache', 'auto');
      await mpv.setProperty('demuxer-max-bytes', '32MiB');
      await mpv.setProperty('demuxer-max-back-bytes', '16MiB');
      await mpv.setProperty('force-seekable', 'yes');

      await mpv.setProperty(
        'http-header-fields',
        'User-Agent: VLC/3.0.16 LibVLC/3.0.16',
      );

      await mpv.setProperty('hwdec', 'auto-safe');

      await mpv.setProperty('rebase-start-time', 'yes');

      _videoController = VideoController(_player!);
      _mediaSessionId++;
      _hasCompleted = false;
      _transientErrorCount = 0;
      _fatalLogHitCount = 0;
      _fatalErrorEmittedForSession = false;

      _subscribeToStreams();

      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after subscriptions',
        );
        await _disposeInternal();
        return;
      }

      _logger.d('MediaKitPlayerImpl: opening media');

      await _player!.open(Media(streamUrl), play: false);

      await _waitForReady();

      if (_disposed) {
        _logger.w(
          'MediaKitPlayerImpl.initialize: aborted — disposed after waitForReady',
        );
        await _disposeInternal();
        return;
      }

      await _player!.play();
      await Future.delayed(const Duration(milliseconds: 50));
      if (_disposed) return;
      await _player!.pause();
      await _player!.seek(Duration.zero);

      if (_disposed) return;

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

    final durSub = _player!.stream.duration.listen((d) {});

    final widthSub = _player!.stream.width.listen((w) {
      if (!completer.isCompleted && w != null && w > 0) {
        completer.complete();
      }
    });

    final errSub = _player!.stream.error.listen((err) {
      if (err.isNotEmpty) {
        initError ??= err;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    final logSub = _player!.stream.log.listen((log) {
      if (_fatalLogPatterns.any((p) => p.hasMatch(log.text))) {
        initError ??= log.text;
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

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

    if (hasDuration) {
      final waitElapsedMs = DateTime.now().millisecondsSinceEpoch - waitStartMs;
      _logger.w(
        '_waitForReady: Audio-only or slow video [elapsed=${waitElapsedMs}ms, '
        'hasDuration=$hasDuration, hasVideo=$hasVideo]',
      );
      return;
    }

    throw Exception('Stream failed to load: no playable media detected.');
  }

  void _subscribeToStreams() {
    final sessionId = _mediaSessionId;

    _subscriptions.add(
      _player!.stream.position.listen((p) {
        if (_disposed || sessionId != _mediaSessionId) {
          return;
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

    _subscriptions.add(
      _player!.stream.duration.listen((d) {
        if (!_durationController.isClosed) _durationController.add(d);
      }),
    );

    _subscriptions.add(
      _player!.stream.rate.listen((rate) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (!_speedController.isClosed) _speedController.add(rate);
      }),
    );

    _subscriptions.add(
      _player!.stream.volume.listen((volume) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (!_volumeController.isClosed) {
          _volumeController.add(volume / 100.0);
        }
      }),
    );

    _subscriptions.add(
      _player!.stream.playing.listen((playing) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (playing) {
          _transientErrorCount = 0;
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
          _transientErrorCount = 0;
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

    _subscriptions.add(
      _player!.stream.completed.listen((completed) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (completed) {
          _hasCompleted = true;
          _eventController.add(const PlayerEvent(PlayerEventType.ended));
        }
      }),
    );

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

    _subscriptions.add(
      _player!.stream.log.listen((log) {
        if (_disposed || sessionId != _mediaSessionId) return;
        if (_fatalErrorEmittedForSession) return;

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
    if (_disposed || _disposing) return;
    await _player?.play();
  }

  @override
  Future<void> pause() async {
    if (_disposed || _disposing) return;
    await _player?.pause();
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
  Future<void> setPlaybackSpeed(double speed) async {
    if (_disposed || _disposing) return;
    await _player?.setRate(speed);
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

    if (!_positionController.isClosed) _positionController.add(Duration.zero);
    if (!_durationController.isClosed) _durationController.add(Duration.zero);
    if (!_volumeController.isClosed) _volumeController.add(1.0);
  }
}
