import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';
import '../../room/bloc/room_state.dart';
import '../models/player_ui_context.dart';
import 'peer_status_indicator.dart';

/// Cinematic player top bar overlay — flagship grade.
class PlayerTopBar extends StatelessWidget {
  final PlayerUIContext uiContext;
  final String? roomCode;
  final PeerStatus? peerStatus;
  final VoidCallback onBack;
  final VoidCallback? onBrowseContent;

  const PlayerTopBar({
    super.key,
    required this.uiContext,
    this.roomCode,
    this.peerStatus,
    required this.onBack,
    this.onBrowseContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xE6000000), Color(0x4D000000), Color(0x00000000)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _TopBarBtn(
              icon: Icons.arrow_back_rounded,
              tooltip: uiContext.isRoomMode ? 'Leave Room' : 'Back',
              onTap: onBack,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // ── Metadata + Title area ──────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Badges (Wrappable) ──────────────────────────────────────
                if (uiContext.showRoomCode ||
                    uiContext.showRoleBadge ||
                    uiContext.isLive ||
                    uiContext.isEpisode ||
                    uiContext.isMovie)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (uiContext.showRoomCode && roomCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.18)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: AppColors.success,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.success
                                            .withValues(alpha: 0.6),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  roomCode!,
                                  style: AppTypography.mono.copyWith(
                                    color: Colors.white,
                                    fontSize: 11,
                                    letterSpacing: 3.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (uiContext.showRoleBadge)
                          uiContext.isHost
                              ? StatusBadge.host()
                              : StatusBadge.guest(),
                        if (uiContext.isLive)
                          const _LiveChip()
                        else if (uiContext.isEpisode)
                          const _ContentTypeChip(
                            label: 'EPISODE',
                            color: AppColors.accentPrimary,
                          )
                        else if (uiContext.isMovie)
                          const _ContentTypeChip(
                            label: 'MOVIE',
                            color: AppColors.accentSecondary,
                          ),
                      ],
                    ),
                  ),

                // ── Title ───────────────────────────────────────────────────
                Text(
                  uiContext.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    shadows: [Shadow(color: Colors.black, blurRadius: 12)],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (uiContext.subtitle != null)
                  Text(
                    uiContext.subtitle!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),

          // ── Right side ──────────────────────────────────────────────
          if (uiContext.showPeerStatus && peerStatus != null) ...[
            const SizedBox(width: AppSpacing.sm),
            PeerStatusIndicator(status: peerStatus!),
          ],
          if (uiContext.canChangeContent && onBrowseContent != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _TopBarBtn(
              icon: Icons.explore_rounded,
              tooltip: 'Browse Desktop',
              onTap: onBrowseContent!,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Live chip ─────────────────────────────────────────────────────

class _LiveChip extends StatefulWidget {
  const _LiveChip();
  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _a = CurvedAnimation(parent: _c, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _a,
              builder: (_, __) => Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(
                        alpha: 0.4 + _a.value * 0.4,
                      ),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text(
              'LIVE',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                shadows: [Shadow(color: Colors.black, blurRadius: 6)],
              ),
            ),
          ],
        ),
      );
}

// ── Content type chip ─────────────────────────────────────────────

class _ContentTypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ContentTypeChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
          ),
        ),
      );
}

// ── Top bar icon button ───────────────────────────────────────────

class _TopBarBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _TopBarBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  State<_TopBarBtn> createState() => _TopBarBtnState();
}

class _TopBarBtnState extends State<_TopBarBtn> {
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _h
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: _h ? 0.25 : 0.1),
                ),
                boxShadow: _h
                    ? [
                        const BoxShadow(
                          color: Colors.black38,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: 17,
                shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
              ),
            ),
          ),
        ),
      );
}
