import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../room/bloc/room_bloc.dart';
import '../../room/bloc/room_state.dart';
import '../bloc/player_bloc.dart';
import '../bloc/player_state.dart';
import '../screens/watch_screen.dart';

/// Cinematic playback controls bar.
/// Host: full interactive controls. Guest: read-only position display.
class PlaybackControls extends StatefulWidget {
  const PlaybackControls({super.key});

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  bool _isMuted = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoomBloc, RoomState>(
      builder: (context, roomState) {
        final String? role;
        if (roomState is RoomStateActive) {
          role = roomState.role;
        } else if (roomState is RoomStateJoined) {
          role = roomState.role;
        } else {
          return const SizedBox.shrink();
        }

        final isHost = role == 'host';
        return BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, playerState) {
            if (playerState is PlayerStateIdle ||
                playerState is PlayerStateLoading) {
              return const SizedBox.shrink();
            }
            if (isHost) return _buildHostControls(context, playerState);
            return _buildGuestDisplay(context, playerState);
          },
        );
      },
    );
  }

  Widget _buildHostControls(BuildContext context, PlayerState playerState) {
    final isPlaying = playerState is PlayerStatePlaying;
    final isPaused = playerState is PlayerStatePaused;
    final canControl = isPlaying || isPaused || playerState is PlayerStateReady;
    final position = _position(playerState);
    final playerController = GetIt.instance<PlayerController>();
    final duration = _duration(playerController);
    final isLive = duration >= const Duration(hours: 3, minutes: 59);

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (e) => _onKey(e, context, playerState),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xEE000000), Color(0x66000000), Color(0x00000000)],
            stops: [0.0, 0.65, 1.0],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress row
            if (!isLive) _buildSeekBar(context, position, duration, canControl),
            // Controls row
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  // Time / LIVE badge
                  _buildTimeDisplay(position, duration, isLive),
                  const Spacer(),
                  // Transport controls
                  _buildTransportControls(
                    context,
                    playerState,
                    position,
                    duration,
                    canControl,
                    isLive,
                  ),
                  const Spacer(),
                  // Utilities
                  _buildUtilityControls(playerController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar(
    BuildContext context,
    Duration position,
    Duration duration,
    bool canControl,
  ) {
    final maxMs = duration.inMilliseconds.toDouble().clamp(
          1.0,
          double.infinity,
        );
    final valMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: AppColors.accentPrimary,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
        thumbColor: Colors.white,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        overlayColor: AppColors.accentPrimary.withValues(alpha: 0.25),
        disabledActiveTrackColor: AppColors.accentPrimaryMuted,
        disabledInactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        disabledThumbColor: Colors.white.withValues(alpha: 0.4),
      ),
      child: Slider(
        value: valMs,
        min: 0,
        max: maxMs,
        onChanged: canControl
            ? (v) {
                final ws =
                    context.findAncestorStateOfType<WatchScreenContentState>();
                ws?.invokeSeekAction(Duration(milliseconds: v.toInt()));
              }
            : null,
      ),
    );
  }

  Widget _buildTimeDisplay(Duration position, Duration duration, bool isLive) {
    if (isLive) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Text(
          _fmt(position),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        Text(
          ' / ${_fmt(duration)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls(
    BuildContext context,
    PlayerState playerState,
    Duration position,
    Duration duration,
    bool canControl,
    bool isLive,
  ) {
    final isPlaying = playerState is PlayerStatePlaying;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Rewind (VOD)
        if (!isLive)
          _ChrBtn(
            icon: Icons.replay_10_rounded,
            tooltip: 'Rewind 10s',
            onTap: canControl
                ? () => _seekRel(context, position, duration, -10)
                : null,
          ),
        const SizedBox(width: AppSpacing.sm),
        // Play/Pause — larger focal button
        _PlayPauseBtn(
          isPlaying: isPlaying,
          canControl: canControl,
          onTap: () {
            final ws =
                context.findAncestorStateOfType<WatchScreenContentState>();
            if (isPlaying) {
              ws?.invokePauseAction(position);
            } else {
              ws?.invokePlay(position);
            }
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        // Forward (VOD)
        if (!isLive)
          _ChrBtn(
            icon: Icons.forward_10_rounded,
            tooltip: 'Forward 10s',
            onTap: canControl
                ? () => _seekRel(context, position, duration, 10)
                : null,
          ),
      ],
    );
  }

  Widget _buildUtilityControls(PlayerController playerController) {
    return Row(
      children: [
        _ChrBtn(
          icon: _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          tooltip: _isMuted ? 'Unmute' : 'Mute',
          onTap: () {
            setState(() => _isMuted = !_isMuted);
            playerController.setVolume(_isMuted ? 0.0 : 1.0);
          },
        ),
      ],
    );
  }

  Widget _buildGuestDisplay(BuildContext context, PlayerState playerState) {
    final position = _position(playerState);
    final isPlaying = playerState is PlayerStatePlaying;
    final playerController = GetIt.instance<PlayerController>();
    final duration = _duration(playerController);
    final isLive = duration >= const Duration(hours: 3, minutes: 59);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
          stops: [0.0, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPlaying ? Icons.play_arrow_rounded : Icons.pause_rounded,
            color: Colors.white.withValues(alpha: 0.5),
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'LIVE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            )
          else
            Text(
              _fmt(position),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'VIEWING',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _seekRel(BuildContext context, Duration pos, Duration dur, int secs) {
    final target = Duration(
      milliseconds: (pos.inMilliseconds + secs * 1000).clamp(
        0,
        dur.inMilliseconds,
      ),
    );
    context
        .findAncestorStateOfType<WatchScreenContentState>()
        ?.invokeSeekAction(target);
  }

  void _onKey(KeyEvent event, BuildContext context, PlayerState playerState) {
    if (event is! KeyDownEvent) return;
    final isPlaying = playerState is PlayerStatePlaying;
    final isPaused = playerState is PlayerStatePaused;
    final canControl = isPlaying || isPaused || playerState is PlayerStateReady;
    if (!canControl) return;
    final pos = _position(playerState);
    final dur = _duration(GetIt.instance<PlayerController>());
    final ws = context.findAncestorStateOfType<WatchScreenContentState>();
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (isPlaying) {
        ws?.invokePauseAction(pos);
      } else {
        ws?.invokePlay(pos);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _seekRel(context, pos, dur, -10);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _seekRel(context, pos, dur, 10);
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      setState(() => _isMuted = !_isMuted);
      GetIt.instance<PlayerController>().setVolume(_isMuted ? 0.0 : 1.0);
    }
  }

  Duration _position(PlayerState state) => switch (state) {
        PlayerStatePlaying(position: final p) => p,
        PlayerStatePaused(position: final p) => p,
        PlayerStateBuffering(lastKnownPosition: final p) => p,
        _ => Duration.zero,
      };

  Duration _duration(PlayerController c) {
    final d = c.duration;
    return d > Duration.zero ? d : const Duration(hours: 4);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// —— Play/Pause focal button ———————————————————————————————————————————————————

class _PlayPauseBtn extends StatefulWidget {
  final bool isPlaying;
  final bool canControl;
  final VoidCallback onTap;
  const _PlayPauseBtn({
    required this.isPlaying,
    required this.canControl,
    required this.onTap,
  });
  @override
  State<_PlayPauseBtn> createState() => _PlayPauseBtnState();
}

class _PlayPauseBtnState extends State<_PlayPauseBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.canControl ? widget.onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _hovered
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: _hovered ? 0.0 : 0.25),
                width: 1.5,
              ),
              boxShadow: _hovered
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
              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: _hovered ? AppColors.background : Colors.white,
              size: 26,
            ),
          ),
        ),
      );
}

// —— Chrome button —————————————————————————————————————————————————————————————

class _ChrBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _ChrBtn({required this.icon, required this.tooltip, this.onTap});
  @override
  State<_ChrBtn> createState() => _ChrBtnState();
}

class _ChrBtnState extends State<_ChrBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: widget.tooltip,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hovered
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.onTap == null
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
}
