import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/services/brightness_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../models/player_ui_context.dart';
import '../models/video_fit_mode.dart';

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
  final _bs = GetIt.I<BrightnessService>();

  String? _feedbackText;
  IconData? _feedbackIcon;
  Timer? _feedbackTimer;
  double _baseScale = 1.0;

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

  void _onVerticalDrag(DragUpdateDetails details) {
    final width = MediaQuery.of(context).size.width;
    final isLeft = details.localPosition.dx < width / 2;
    final delta = -details.primaryDelta! / 200.0;

    if (isLeft) {
      final newBrightness = (widget.brightness + delta).clamp(0.0, 1.0);
      widget.onBrightnessChanged(newBrightness);
      _bs.setBrightness(newBrightness);
      _showFeedback(
        'Brightness ${(newBrightness * 100).toInt()}%',
        Icons.brightness_medium_rounded,
      );
    } else {
      final newVolume = (_pc.volume + delta).clamp(0.0, 1.0);
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

  bool _isScrubbing = false;
  Duration _scrubPosition = Duration.zero;

  void _onHorizontalDragStart(DragStartDetails details) {
    if (!widget.uiContext.canControlPlayback) return;
    setState(() {
      _isScrubbing = true;
      _scrubPosition = _pc.currentPosition;
    });
    widget.onShowOverlays();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isScrubbing) return;
    final delta = details.primaryDelta! * 100; // 100ms per pixel
    setState(() {
      final newMs = _scrubPosition.inMilliseconds + delta.toInt();
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

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isScrubbing) return;
    if (widget.onSeek != null) {
      widget.onSeek!(_scrubPosition);
    } else {
      _pc.seekTo(_scrubPosition);
    }
    setState(() => _isScrubbing = false);
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onShowOverlays,
      onDoubleTap: _toggleFitMode,
      onVerticalDragUpdate: _onVerticalDrag,
      onHorizontalDragStart: _onHorizontalDragStart,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onScaleStart: (_) {
        _baseScale = 1.0;
        widget.onShowOverlays();
      },
      onScaleUpdate: (details) {
        final scale = details.scale;
        if (scale > 1.05 && widget.fitMode != VideoFitMode.cover) {
          widget.onFitModeChanged(VideoFitMode.cover);
          _showFeedback('Fill Screen', VideoFitMode.cover.icon);
        } else if (scale < 0.95 && widget.fitMode != VideoFitMode.contain) {
          widget.onFitModeChanged(VideoFitMode.contain);
          _showFeedback('Fit to Screen', VideoFitMode.contain.icon);
        }
        widget.onShowOverlays();
      },
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
