import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/player_ui_context.dart';

/// Cinematic state overlays for the player area.
class PlayerStateOverlay extends StatelessWidget {
  final PlayerUIContext uiContext;
  final PlayerOverlayType type;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onBrowseContent;
  final VoidCallback? onBack;

  const PlayerStateOverlay({
    super.key,
    required this.uiContext,
    required this.type,
    this.errorMessage,
    this.onRetry,
    this.onBrowseContent,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isSemi = type == PlayerOverlayType.buffering;
    return Container(
      color: isSemi
          ? AppColors.playerBackground.withValues(alpha: 0.65)
          : AppColors.playerBackground,
      child: Center(child: _buildContent()),
    );
  }

  Widget _buildContent() => switch (type) {
    PlayerOverlayType.loading => _loading(),
    PlayerOverlayType.buffering => _buffering(),
    PlayerOverlayType.error => _error(),
    PlayerOverlayType.ended => _ended(),
    PlayerOverlayType.idle => _idle(),
  };

  Widget _loading() => const _SpinnerOverlay(message: 'Loading stream...');
  Widget _buffering() =>
      const _SpinnerOverlay(message: 'Buffering...', semi: true);

  Widget _error() {
    final msg = _friendlyError(errorMessage ?? '');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.errorSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
            color: AppColors.error,
            size: 30,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            msg,
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (uiContext.canControlPlayback || !uiContext.isRoomMode) ...[
          if (uiContext.canChangeContent && onBrowseContent != null)
            _PlayerActionBtn(
              label: 'Choose Different Content',
              icon: Icons.video_library_rounded,
              onTap: onBrowseContent!,
            )
          else if (onRetry != null)
            _PlayerActionBtn(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onTap: onRetry!,
            ),
        ] else
          Text(
            'Waiting for host to select new content...',
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _ended() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Icon(Icons.replay_rounded, color: Colors.white, size: 28),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Playback ended',
        style: AppTypography.body.copyWith(
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      if (onBack != null) ...[
        const SizedBox(height: AppSpacing.xl),
        _PlayerActionBtn(
          label: 'Back to Browse',
          icon: Icons.arrow_back_rounded,
          onTap: onBack!,
        ),
      ],
    ],
  );

  Widget _idle() {
    if (uiContext.isRoomMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: const Icon(
              Icons.movie_creation_outlined,
              size: 36,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            uiContext.isHost
                ? 'Choose something to watch'
                : 'Waiting for host to\nselect content...',
            style: AppTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
            textAlign: TextAlign.center,
          ),
          if (uiContext.isHost && onBrowseContent != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _PlayerActionBtn(
              label: 'Browse Content',
              icon: Icons.video_library_rounded,
              onTap: onBrowseContent!,
            ),
          ],
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.videocam_off,
          color: Colors.white38,
          size: AppIconSize.xxl,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No content selected',
          style: AppTypography.body.copyWith(color: Colors.white38),
        ),
      ],
    );
  }

  String _friendlyError(String raw) {
    final l = raw.toLowerCase();
    if (l.contains('connection') || l.contains('network')) {
      return 'Connection problem. Check your network and try again.';
    }
    if (l.contains('format') ||
        l.contains('codec') ||
        l.contains('unsupported')) {
      return 'This stream format is not supported.';
    }
    if (l.contains('timeout')) {
      return 'Stream took too long to respond. Try again.';
    }
    if (l.contains('404') || l.contains('not found')) {
      return 'This content is no longer available.';
    }
    return 'Playback could not start. Try different content.';
  }
}

class _SpinnerOverlay extends StatelessWidget {
  final String message;
  final bool semi;
  const _SpinnerOverlay({required this.message, this.semi = false});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: semi ? 0.05 : 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentPrimary,
            strokeCap: StrokeCap.round,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        message,
        style: AppTypography.bodySmall.copyWith(
          color: Colors.white.withValues(alpha: 0.65),
        ),
      ),
    ],
  );
}

class _PlayerActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PlayerActionBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  State<_PlayerActionBtn> createState() => _PlayerActionBtnState();
}

class _PlayerActionBtnState extends State<_PlayerActionBtn> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _hovered ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: Colors.white.withValues(alpha: _hovered ? 0.0 : 0.25),
          ),
          boxShadow: _hovered
              ? const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              size: 16,
              color: _hovered ? AppColors.background : Colors.white,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              widget.label,
              style: AppTypography.buttonSmall.copyWith(
                color: _hovered ? AppColors.background : Colors.white,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Overlay types for state-dependent display.
enum PlayerOverlayType { loading, buffering, error, ended, idle }
