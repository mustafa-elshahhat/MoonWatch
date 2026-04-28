import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/player_ui_context.dart';
import '../models/video_fit_mode.dart';

enum _GestureMode {
  none,
  verticalVolume,
  verticalBrightness,
  horizontalScrub,
  pinchFit,
}

class PlayerGestureLayer extends StatefulWidget {
  final PlayerUIContext uiContext;
  final VideoFitMode fitMode;
  final ValueChanged<VideoFitMode> onFitModeChanged;
  final VoidCallback onShowOverlays;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<Duration>? onSeek;

  const PlayerGestureLayer({
    super.key,
    required this.uiContext,
    required this.fitMode,
    required this.onFitModeChanged,
    required this.onShowOverlays,
    required this.brightness,
    required this.onBrightnessChanged,
    this.onSeek,
  });

  @override
  State<PlayerGestureLayer> createState() => _PlayerGestureLayerState();
}

class _PlayerGestureLayerState extends State<PlayerGestureLayer> {
  final _pc = GetIt.I<PlayerController>();

  String? _feedbackText;
  IconData? _feedbackIcon;
  Timer? _feedbackTimer;
  Offset? _doubleTapPosition;
  _GestureMode _gestureMode = _GestureMode.none;
  bool _gestureLocked = false;
  Offset _gestureDelta = Offset.zero;
  Offset _gestureStart = Offset.zero;

  void _showFeedback(String text, IconData icon) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedbackText = text;
      _feedbackIcon = icon;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _feedbackText = null);
    });
  }

  void _onVerticalDrag(Offset delta) {
    final amount = -delta.dy / 200.0;

    if (_gestureMode == _GestureMode.verticalBrightness) {
      final newBrightness = (widget.brightness + amount).clamp(0.0, 1.0);
      widget.onBrightnessChanged(newBrightness);
      _showFeedback(
        'Brightness ${(newBrightness * 100).toInt()}%',
        Icons.brightness_medium_rounded,
      );
    } else {
      final newVolume = (_pc.volume + amount).clamp(0.0, 1.0);
      _pc.setVolume(newVolume);
      _showFeedback(
        'Volume ${(newVolume * 100).toInt()}%',
        newVolume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
      );
    }
    widget.onShowOverlays();
  }

  void _toggleFitMode() {
    final next = widget.fitMode == VideoFitMode.contain
        ? VideoFitMode.cover
        : VideoFitMode.contain;
    widget.onFitModeChanged(next);
    _showFeedback(
      next == VideoFitMode.cover ? 'Fill Screen' : 'Fit to Screen',
      next.icon,
    );
    widget.onShowOverlays();
  }

  Duration _scrubPosition = Duration.zero;

  void _startHorizontalScrub() {
    setState(() {
      _scrubPosition = _pc.currentPosition;
    });
    widget.onShowOverlays();
  }

  void _onHorizontalDragUpdate(Offset delta) {
    if (_gestureMode != _GestureMode.horizontalScrub) return;
    final seekDelta = delta.dx * 100; // 100ms per pixel
    setState(() {
      final newMs = _scrubPosition.inMilliseconds + seekDelta.toInt();
      _scrubPosition = Duration(
        milliseconds: newMs.clamp(0, _pc.duration.inMilliseconds),
      );
    });
    _showFeedback(
      'Seek to ${_fmtDuration(_scrubPosition)}',
      Icons.timer_outlined,
    );
    widget.onShowOverlays();
  }

  void _onHorizontalDragEnd() {
    if (_gestureMode != _GestureMode.horizontalScrub) return;
    if (widget.onSeek != null) {
      widget.onSeek!(_scrubPosition);
    } else {
      _pc.seekTo(_scrubPosition);
    }
    widget.onShowOverlays();
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _onScaleStart(ScaleStartDetails details) {
    widget.onShowOverlays();
    _gestureMode =
        details.pointerCount >= 2 ? _GestureMode.pinchFit : _GestureMode.none;
    _gestureLocked = details.pointerCount >= 2;
    _gestureDelta = Offset.zero;
    _gestureStart = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    widget.onShowOverlays();

    if (_gestureMode == _GestureMode.pinchFit || details.pointerCount >= 2) {
      _gestureMode = _GestureMode.pinchFit;
      _gestureLocked = true;
      _handlePinch(details.scale);
      return;
    }

    if (details.pointerCount != 1) return;

    final delta = details.focalPointDelta;
    if (!_gestureLocked) {
      _gestureDelta += delta;
      if (_gestureDelta.distance < 8) return;

      final dx = _gestureDelta.dx.abs();
      final dy = _gestureDelta.dy.abs();
      if (dy > dx * 1.25) {
        final width = MediaQuery.of(context).size.width;
        _gestureMode = _gestureStart.dx < width / 2
            ? _GestureMode.verticalBrightness
            : _GestureMode.verticalVolume;
      } else if (dx > dy * 1.25) {
        _gestureMode = widget.uiContext.canControlPlayback
            ? _GestureMode.horizontalScrub
            : _GestureMode.none;
        if (_gestureMode == _GestureMode.horizontalScrub) {
          _startHorizontalScrub();
        }
      } else {
        return;
      }
      _gestureLocked = true;
    }

    switch (_gestureMode) {
      case _GestureMode.verticalBrightness:
      case _GestureMode.verticalVolume:
        _onVerticalDrag(delta);
        break;
      case _GestureMode.horizontalScrub:
        _onHorizontalDragUpdate(delta);
        break;
      case _GestureMode.pinchFit:
      case _GestureMode.none:
        break;
    }
  }

  void _handlePinch(double scale) {
    if (scale > 1.1 && widget.fitMode != VideoFitMode.cover) {
      widget.onFitModeChanged(VideoFitMode.cover);
      _showFeedback('Fill Screen', VideoFitMode.cover.icon);
    } else if (scale < 0.9 && widget.fitMode != VideoFitMode.contain) {
      widget.onFitModeChanged(VideoFitMode.contain);
      _showFeedback('Fit to Screen', VideoFitMode.contain.icon);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _onHorizontalDragEnd();
    _gestureMode = _GestureMode.none;
    _gestureLocked = false;
    _gestureDelta = Offset.zero;
  }

  bool _isCenterDoubleTap() {
    final position = _doubleTapPosition;
    if (position == null) return false;
    final size = context.size;
    if (size == null || size.isEmpty) return false;

    final left = size.width * 0.25;
    final right = size.width * 0.75;
    final top = size.height * 0.15;
    final bottom = size.height * 0.75;

    return position.dx >= left &&
        position.dx <= right &&
        position.dy >= top &&
        position.dy <= bottom;
  }

  void _onDoubleTap() {
    if (_isCenterDoubleTap()) {
      _toggleFitMode();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onShowOverlays,
      onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
      onDoubleTap: _onDoubleTap,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      child: Stack(
        children: [
          if (_feedbackText != null)
            Center(
              child: _GestureFeedback(
                text: _feedbackText!,
                icon: _feedbackIcon!,
              ),
            ),
        ],
      ),
    );
  }
}

class _GestureFeedback extends StatelessWidget {
  final String text;
  final IconData icon;

  const _GestureFeedback({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 42),
          const SizedBox(height: AppSpacing.sm),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
