import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class RoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool isJoining;
  final bool canJoin;
  final void Function(String) onJoin;

  const RoomCard({
    super.key,
    required this.room,
    required this.isJoining,
    required this.canJoin,
    required this.onJoin,
  });

  @override
  State<RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<RoomCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final code = room['roomCode'] as String;
    final hasGuest = room['hasGuest'] as bool? ?? false;
    final isJoinable = room['isJoinable'] as bool? ?? (!hasGuest);
    final contentSet = room['contentSet'] as bool? ?? false;
    final contentType = room['contentType'] as String?;
    final hostRtt = room['hostRtt'] as int?;
    final createdAtStr = room['createdAt'] as String?;

    String statusText = 'Waiting for guest';
    Color statusColor = AppColors.success;
    if (!isJoinable) {
      statusText = 'Room is full';
      statusColor = AppColors.error;
    } else if (contentSet) {
      statusText = 'Playing: ${contentType ?? 'Content'}';
      statusColor = AppColors.accentPrimary;
    }

    String ageText = '';
    if (createdAtStr != null) {
      final ca = DateTime.tryParse(createdAtStr);
      if (ca != null) {
        final age = DateTime.now().difference(ca.toLocal());
        ageText = age.inMinutes < 60
            ? '${age.inMinutes}m ago'
            : '${age.inHours}h ago';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuart,
          transform: Matrix4.translationValues(
            0.0,
            _hovered && isJoinable ? -2.0 : 0.0,
            0.0,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _hovered && isJoinable
                ? AppColors.surfaceElevated
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _hovered && isJoinable
                  ? statusColor.withValues(alpha: 0.4)
                  : AppColors.borderSubtle,
              width: _hovered && isJoinable ? 1.5 : 1,
            ),
            boxShadow: _hovered && isJoinable
                ? [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isJoinable
                      ? statusColor.withValues(alpha: 0.12)
                      : AppColors.errorSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isJoinable
                        ? statusColor.withValues(alpha: 0.3)
                        : AppColors.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  isJoinable
                      ? (contentSet
                          ? Icons.play_circle_outline_rounded
                          : Icons.sensors_rounded)
                      : Icons.do_not_disturb_alt_rounded,
                  color: isJoinable ? statusColor : AppColors.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          code,
                          style: AppTypography.mono.copyWith(
                            color: AppColors.textPrimary,
                            letterSpacing: 4,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            shadows: _hovered
                                ? [
                                    Shadow(
                                      color: statusColor.withValues(alpha: 0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                        ),
                        if (ageText.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.md),
                          Text(ageText, style: AppTypography.captionSmall),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.6),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            statusText,
                            style: AppTypography.captionSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (hostRtt != null && hostRtt > 0 && hostRtt < 500) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.signal_cellular_alt_rounded,
                            size: 10,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${hostRtt}ms ping',
                            style: AppTypography.captionSmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _JoinBtn(
                isJoining: widget.isJoining,
                canJoin: widget.canJoin && isJoinable,
                onJoin: () => widget.onJoin(code),
                accentColor: statusColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinBtn extends StatefulWidget {
  final bool isJoining;
  final bool canJoin;
  final VoidCallback onJoin;
  final Color accentColor;

  const _JoinBtn({
    required this.isJoining,
    required this.canJoin,
    required this.onJoin,
    this.accentColor = AppColors.accentPrimary,
  });

  @override
  State<_JoinBtn> createState() => _JoinBtnState();
}

class _JoinBtnState extends State<_JoinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.canJoin && !widget.isJoining ? widget.onJoin : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: !widget.canJoin
                ? AppColors.surfaceElevated
                : _hovered
                    ? widget.accentColor
                    : widget.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: !widget.canJoin
                  ? AppColors.border
                  : _hovered
                      ? widget.accentColor
                      : widget.accentColor.withValues(alpha: 0.3),
            ),
            boxShadow: _hovered && widget.canJoin
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: widget.isJoining
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.accentColor,
                  ),
                )
              : Text(
                  'Join',
                  style: AppTypography.buttonSmall.copyWith(
                    color: !widget.canJoin
                        ? AppColors.textDisabled
                        : _hovered
                            ? Colors.white
                            : widget.accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
