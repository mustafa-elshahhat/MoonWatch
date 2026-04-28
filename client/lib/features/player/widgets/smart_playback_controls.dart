import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/services/fullscreen_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/player_ui_context.dart';
import '../models/video_fit_mode.dart';

typedef PlayCallback = void Function(Duration position);
typedef PauseCallback = void Function(Duration position);
typedef SeekCallback = void Function(Duration target);
typedef SpeedCallback = void Function(double speed);

class SmartPlaybackControls extends StatefulWidget {
  static SmartPlaybackControlsState? of(BuildContext context) =>
      context.findAncestorStateOfType<SmartPlaybackControlsState>();

  final PlayerUIContext uiContext;
  final bool isPlaying;
  final bool isPaused;
  final bool canInteract;
  final PlayCallback? onPlay;
  final PauseCallback? onPause;
  final SeekCallback? onSeek;
  final SpeedCallback? onSpeedChanged;
  final VoidCallback? onNextEpisode;
  final VideoFitMode fitMode;
  final ValueChanged<VideoFitMode>? onFitModeChanged;
  final double brightness;
  final ValueChanged<double>? onBrightnessChanged;

  const SmartPlaybackControls({
    super.key,
    required this.uiContext,
    required this.isPlaying,
    required this.isPaused,
    required this.canInteract,
    this.fitMode = VideoFitMode.contain,
    this.onFitModeChanged,
    this.onPlay,
    this.onPause,
    this.onSeek,
    this.onSpeedChanged,
    this.onNextEpisode,
    this.brightness = 1.0,
    this.onBrightnessChanged,
  });

  @override
  State<SmartPlaybackControls> createState() => SmartPlaybackControlsState();
}

class SmartPlaybackControlsState extends State<SmartPlaybackControls>
    with SingleTickerProviderStateMixin {
  double _volume = 1.0;
  bool _visible = true;
  bool _isDragging = false;
  double? _dragValue;
  bool _hoveredTrack = false;
  final GlobalKey _trackKey = GlobalKey();

  Timer? _hideTimer;
  final FocusNode _focusNode = FocusNode();
  final FullscreenService _fullscreenService = FullscreenService();
  late final PlayerController _pc;

  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _speedSub;
  StreamSubscription? _volSub;

  late final AnimationController _controlsAnim;

  PlayerUIContext get ctx => widget.uiContext;

  @override
  void initState() {
    super.initState();
    _controlsAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _scheduleHide();
    _pc = GetIt.instance<PlayerController>();

    _currentPosition = _pc.currentPosition;
    _currentDuration = _pc.duration;
    _posSub = _pc.positionStream.listen((p) {
      if (mounted && !_isDragging) {
        setState(() {
          _currentPosition = p;
          if (_currentDuration == Duration.zero) {
            final dur = _pc.duration;
            if (dur > Duration.zero) _currentDuration = dur;
          }
        });
      }
    });
    _durSub = _pc.durationStream.listen((d) {
      if (mounted) setState(() => _currentDuration = d);
    });
    _speedSub = _pc.playbackSpeedStream.listen((s) {
      if (mounted) setState(() {});
    });
    _volume = _pc.volume;
    _volSub = _pc.volumeStream.listen((v) {
      if (mounted) setState(() => _volume = v);
    });

    if (_currentDuration == Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final dur = _pc.duration;
          if (dur > Duration.zero && mounted) {
            setState(() => _currentDuration = dur);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _focusNode.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _speedSub?.cancel();
    _volSub?.cancel();
    _controlsAnim.dispose();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.isPlaying && !_isDragging && !_hoveredTrack) {
        _controlsAnim.reverse();
        if (mounted) setState(() => _visible = false);
      }
    });
  }

  void showControls() {
    if (isClosed) return;
    if (!_visible) {
      _controlsAnim.forward();
      setState(() => _visible = true);
    }
    _scheduleHide();
  }

  bool get isClosed => !mounted;

  void _toggleMute() {
    if (_volume > 0) {
      _pc.setVolume(0.0);
    } else {
      _pc.setVolume(_pc.lastNonZeroVolume);
    }
    showControls();
  }

  void _updateVolume(double value) {
    _pc.setVolume(value.clamp(0.0, 1.0));
    showControls();
  }

  void _toggleFullscreen() {
    _fullscreenService.toggle().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    showControls();
    if (!widget.canInteract || !ctx.canControlPlayback) return;
    final safe = _safeDuration;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.keyK:
        widget.isPlaying
            ? widget.onPause?.call(_currentPosition)
            : widget.onPlay?.call(_currentPosition);
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.keyJ:
        if (ctx.canSkip) _seekRelative(-10, safe);
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.keyL:
        if (ctx.canSkip) _seekRelative(10, safe);
      case LogicalKeyboardKey.keyM:
        _toggleMute();
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
      case LogicalKeyboardKey.keyN:
        if (ctx.canShowNextEpisode) widget.onNextEpisode?.call();
      case LogicalKeyboardKey.bracketLeft:
        if (_isVOD && ctx.canControlPlayback) _adjustSpeed(-0.25);
      case LogicalKeyboardKey.bracketRight:
        if (_isVOD && ctx.canControlPlayback) _adjustSpeed(0.25);
      default:
        break;
    }
  }

  void _adjustSpeed(double delta) {
    final current = _pc.playbackSpeed;
    final next = (current + delta).clamp(0.25, 2.0);
    if (next != current) {
      if (widget.onSpeedChanged != null) {
        widget.onSpeedChanged!(next);
      } else {
        _pc.setPlaybackSpeed(next);
      }
      showControls();
    }
  }

  Duration get _safeDuration => _currentDuration > Duration.zero
      ? _currentDuration
      : const Duration(hours: 4);

  bool get _isVOD => ctx.showSeekBar && !ctx.isLive;

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: showControls,
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !_visible,
            child: ctx.isGuest && ctx.showViewOnlyLabel
                ? _buildGuestBar()
                : _buildHostBar(),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestBar() {
    return _ChromeContainer(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              if (_isVOD) ...[
                Text(_fmt(_currentPosition), style: _timeStyle),
                Text(' / ${_fmt(_currentDuration)}', style: _durationStyle),
              ],
              if (ctx.isLive && ctx.showLiveBadge) const _LiveBadge(),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              _FitBtn(
                mode: widget.fitMode,
                onChanged: (m) {
                  showControls();
                  widget.onFitModeChanged?.call(m);
                },
              ),
              _VolumeControl(
                volume: _volume,
                onMuteToggle: _toggleMute,
                onVolumeChanged: _updateVolume,
              ),
              _BrightnessControl(
                value: widget.brightness,
                onChanged: (v) {
                  showControls();
                  widget.onBrightnessChanged?.call(v);
                },
              ),
              _ChromeBtn(
                icon: _fullscreenService.isFullscreen
                    ? Icons.fullscreen_exit_rounded
                    : Icons.fullscreen_rounded,
                tooltip: 'Fullscreen',
                onTap: _toggleFullscreen,
              ),
              if (_isVOD)
                _SpeedBtn(
                  speed: _pc.playbackSpeed,
                  onChanged: (s) {
                    showControls();
                    if (widget.onSpeedChanged != null) {
                      widget.onSpeedChanged!(s);
                    } else {
                      _pc.setPlaybackSpeed(s);
                    }
                  },
                  enabled: ctx.canControlPlayback,
                ),
              const _HostControlsBadge(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostBar() {
    final safe = _safeDuration;
    return _ChromeContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isVOD && ctx.showSeekBar) _buildPremiumTimeline(safe),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTimeArea(),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  if (ctx.canSkip)
                    _ChromeBtn(
                      icon: Icons.replay_10_rounded,
                      tooltip: 'Rewind 10s (←)',
                      onTap: widget.canInteract
                          ? () => _seekRelative(-10, safe)
                          : null,
                      size: 36,
                    ),
                  if (ctx.canControlPlayback)
                    _PlayPauseBtn(
                      isPlaying: widget.isPlaying,
                      canInteract: widget.canInteract,
                      onTap: () {
                        showControls();
                        widget.isPlaying
                            ? widget.onPause?.call(_currentPosition)
                            : widget.onPlay?.call(_currentPosition);
                      },
                    ),
                  if (ctx.canSkip)
                    _ChromeBtn(
                      icon: Icons.forward_10_rounded,
                      tooltip: 'Forward 10s (→)',
                      onTap: widget.canInteract
                          ? () => _seekRelative(10, safe)
                          : null,
                      size: 36,
                    ),
                  if (ctx.canShowNextEpisode)
                    _ChromeBtn(
                      icon: Icons.skip_next_rounded,
                      tooltip: 'Next Episode (N)',
                      onTap: widget.onNextEpisode,
                      accent: true,
                    ),
                ],
              ),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  _FitBtn(
                    mode: widget.fitMode,
                    onChanged: (m) {
                      showControls();
                      widget.onFitModeChanged?.call(m);
                    },
                  ),
                  _VolumeControl(
                    volume: _volume,
                    onMuteToggle: _toggleMute,
                    onVolumeChanged: _updateVolume,
                  ),
                  _BrightnessControl(
                    value: widget.brightness,
                    onChanged: (v) {
                      showControls();
                      widget.onBrightnessChanged?.call(v);
                    },
                  ),
                  _ChromeBtn(
                    icon: _fullscreenService.isFullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: 'Fullscreen (F)',
                    onTap: _toggleFullscreen,
                  ),
                  if (_isVOD)
                    _SpeedBtn(
                      speed: _pc.playbackSpeed,
                      onChanged: (s) {
                        showControls();
                        if (widget.onSpeedChanged != null) {
                          widget.onSpeedChanged!(s);
                        } else {
                          _pc.setPlaybackSpeed(s);
                        }
                      },
                      enabled: ctx.canControlPlayback,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTimeline(Duration safe) {
    final maxMs = safe.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final posMs = (_isDragging
            ? (_dragValue ?? 0)
            : _currentPosition.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);
    final progress = posMs / maxMs;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTrack = true),
      onExit: (_) => setState(() {
        _hoveredTrack = false;
        _scheduleHide();
      }),
      child: GestureDetector(
        onHorizontalDragStart: (d) {
          _hideTimer?.cancel();
          setState(() {
            _isDragging = true;
            _dragValue = posMs;
          });
        },
        onHorizontalDragUpdate: (d) {
          final box =
              _trackKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final trackWidth = box.size.width;
          final localX = d.localPosition.dx.clamp(0.0, trackWidth);
          final newVal = (localX / trackWidth * maxMs).clamp(0.0, maxMs);
          setState(() => _dragValue = newVal);
        },
        onHorizontalDragEnd: (_) {
          if (_dragValue != null) {
            widget.onSeek?.call(Duration(milliseconds: _dragValue!.toInt()));
            setState(() {
              _currentPosition = Duration(milliseconds: _dragValue!.toInt());
            });
          }
          setState(() {
            _isDragging = false;
            _dragValue = null;
          });
          _scheduleHide();
        },
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: SizedBox(
            key: _trackKey,
            height: 28,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: (_isDragging || _hoveredTrack) ? 5 : 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      return AnimatedContainer(
                        duration: _isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 80),
                        height: (_isDragging || _hoveredTrack) ? 5 : 3,
                        width: (constraints.maxWidth * progress).clamp(
                          0,
                          constraints.maxWidth,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.accentPrimaryMuted,
                              AppColors.accentPrimary,
                              AppColors.accentPrimaryHover,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.5,
                              ),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: (_isDragging || _hoveredTrack) ? 1.0 : 0.0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder: (_, constraints) {
                        final thumbX = (constraints.maxWidth * progress).clamp(
                          0,
                          constraints.maxWidth - 12,
                        );
                        return Transform.translate(
                          offset: Offset(thumbX.toDouble(), 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            width: _isDragging ? 16 : 12,
                            height: _isDragging ? 16 : 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentPrimary.withValues(
                                    alpha: 0.6,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeArea() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isVOD) ...[
          Text(_fmt(_currentPosition), style: _timeStyle),
          Text('  /  ${_fmt(_currentDuration)}', style: _durationStyle),
        ],
        if (ctx.isLive && ctx.showLiveBadge) const _LiveBadge(),
      ],
    );
  }

  TextStyle get _timeStyle => const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Inter',
        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
      );
  TextStyle get _durationStyle => TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFamily: 'Inter',
      );

  void _seekRelative(int seconds, Duration safe) {
    showControls();
    final target = Duration(
      milliseconds: (_currentPosition.inMilliseconds + seconds * 1000).clamp(
        0,
        safe.inMilliseconds,
      ),
    );
    widget.onSeek?.call(target);
    setState(() => _currentPosition = target);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _ChromeContainer extends StatelessWidget {
  final Widget child;
  const _ChromeContainer({required this.child});
  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xE6000000), Color(0x66000000), Color(0x00000000)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        safe.left + AppSpacing.md,
        AppSpacing.xl,
        safe.right + AppSpacing.md,
        safe.bottom + AppSpacing.md,
      ),
      child: child,
    );
  }
}

class _PlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final bool canInteract;
  final VoidCallback onTap;
  const _PlayPauseBtn({
    required this.isPlaying,
    required this.canInteract,
    required this.onTap,
  });
  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: MouseRegion(
          onEnter: (_) => setState(() => _h = true),
          onExit: (_) => setState(() => _h = false),
          child: GestureDetector(
            onTap: widget.canInteract ? widget.onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _h ? Colors.white : Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: _h ? 0 : 0.3),
                  width: 1.5,
                ),
                boxShadow: _h
                    ? [
                        const BoxShadow(
                          color: Colors.black38,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                widget.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: _h ? AppColors.background : Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      );
}

class _ChromeBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool accent;
  final double size;
  const _ChromeBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.accent = false,
    this.size = 36,
  });
  @override
  State<_ChromeBtn> createState() => _ChromeBtnState();
}

class _ChromeBtnState extends State<_ChromeBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _h = true),
          onExit: (_) => setState(() => _h = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: _h
                    ? (widget.accent
                        ? AppColors.accentPrimary
                        : Colors.white.withValues(alpha: 0.15))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                widget.icon,
                color: widget.onTap == null
                    ? Colors.white.withValues(alpha: 0.25)
                    : (widget.accent && _h
                        ? Colors.white
                        : (widget.accent
                            ? AppColors.accentPrimary
                            : Colors.white)),
                size: 20,
              ),
            ),
          ),
        ),
      );
}

class _FitBtn extends StatelessWidget {
  final VideoFitMode mode;
  final ValueChanged<VideoFitMode>? onChanged;
  const _FitBtn({required this.mode, this.onChanged});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: mode.label,
        child: GestureDetector(
          onTap: () => onChanged?.call(mode.next),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              mode.icon,
              size: AppIconSize.lg,
              color: mode == VideoFitMode.contain
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppColors.accentPrimary,
            ),
          ),
        ),
      );
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
}

class _HostControlsBadge extends StatelessWidget {
  const _HostControlsBadge();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'CONTROLLED BY HOST',
          style: TextStyle(
            color: Colors.white.withValues(
              alpha: 0.8,
            ),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
}

class _SpeedBtn extends StatelessWidget {
  final double speed;
  final ValueChanged<double>? onChanged;
  final bool enabled;

  const _SpeedBtn({
    required this.speed,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      initialValue: speed,
      tooltip: 'Playback Speed',
      enabled: enabled,
      onSelected: onChanged,
      offset: const Offset(0, -180),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      itemBuilder: (context) => [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
          .map((s) => PopupMenuItem<double>(
                value: s,
                height: 36,
                child: Center(
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      color: s == speed ? AppColors.accentPrimary : Colors.white,
                      fontSize: 13,
                      fontWeight: s == speed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ))
          .toList(),
      child: Container(
        width: 48,
        height: 36,
        alignment: Alignment.center,
        child: Text(
          '${speed}x',
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _VolumeControl extends StatefulWidget {
  final double volume;
  final VoidCallback onMuteToggle;
  final ValueChanged<double> onVolumeChanged;

  const _VolumeControl({
    required this.volume,
    required this.onMuteToggle,
    required this.onVolumeChanged,
  });

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final icon = widget.volume <= 0
        ? Icons.volume_off_rounded
        : widget.volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChromeBtn(
            icon: icon,
            tooltip: widget.volume <= 0 ? 'Unmute (M)' : 'Mute (M)',
            onTap: widget.onMuteToggle,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _hovered ? 100 : 0,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: _hovered
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: AppColors.accentPrimary,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: widget.volume,
                      onChanged: widget.onVolumeChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BrightnessControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _BrightnessControl({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_BrightnessControl> createState() => _BrightnessControlState();
}

class _BrightnessControlState extends State<_BrightnessControl> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChromeBtn(
            icon: Icons.brightness_medium_rounded,
            tooltip: 'Brightness',
            onTap: () {}, // Icon only for now, hover shows slider
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _hovered ? 100 : 0,
            height: 36,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(),
            child: _hovered
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 12),
                      activeTrackColor: Colors.orangeAccent,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: widget.value,
                      onChanged: widget.onChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
