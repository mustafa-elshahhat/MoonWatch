import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../room/bloc/room_state.dart';

/// PeerStatusIndicator — compact chip showing peer connection state.
/// 3 states: connected (green), buffering (amber spinner), away (grey).
class PeerStatusIndicator extends StatelessWidget {
  final PeerStatus status;

  const PeerStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _bgColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: _bgColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIcon(),
          const SizedBox(width: AppSpacing.xs + 1),
          Text(_label, style: AppTypography.chip.copyWith(color: _labelColor)),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return switch (status) {
      PeerStatus.connected => Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.peerConnected,
            shape: BoxShape.circle,
          ),
        ),
      PeerStatus.buffering => const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: AppColors.peerBuffering,
          ),
        ),
      PeerStatus.away => Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.peerAway,
            shape: BoxShape.circle,
          ),
        ),
    };
  }

  String get _label => switch (status) {
        PeerStatus.connected => 'Peer connected',
        PeerStatus.buffering => 'Peer buffering',
        PeerStatus.away => 'Peer away',
      };

  Color get _labelColor => switch (status) {
        PeerStatus.connected => AppColors.peerConnected,
        PeerStatus.buffering => AppColors.peerBuffering,
        PeerStatus.away => AppColors.peerAway,
      };

  Color get _bgColor => switch (status) {
        PeerStatus.connected => AppColors.peerConnected,
        PeerStatus.buffering => AppColors.peerBuffering,
        PeerStatus.away => AppColors.peerAway,
      };
}
