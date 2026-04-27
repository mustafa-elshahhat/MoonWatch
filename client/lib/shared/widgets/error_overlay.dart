import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../features/room/bloc/room_state.dart';

/// ErrorOverlay — shows full-screen error message for RoomStateError.
/// Each error code has specific user-facing text per ERROR_HANDLING.md.
class ErrorOverlay extends StatelessWidget {
  final RoomErrorCode code;
  final String message;
  final VoidCallback? onDismiss;

  const ErrorOverlay({
    super.key,
    required this.code,
    required this.message,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background.withValues(alpha: 0.92),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xxl),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl + AppSpacing.xs,
            vertical: AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.errorSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: AppIconSize.xl,
                ),
              ),
              const SizedBox(height: AppSpacing.lg + AppSpacing.xxs),
              Text(_friendlyTitle(code), style: AppTypography.title),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _friendlyMessage(code, message),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      onDismiss ??
                      () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (route) => false,
                      ),
                  child: const Text('Go Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyTitle(RoomErrorCode code) {
    return switch (code) {
      RoomErrorCode.roomNotFound => 'Room Not Found',
      RoomErrorCode.roomFull => 'Room Full',
      RoomErrorCode.roomClosed => 'Room Closed',
      RoomErrorCode.roleUnauthorized => 'Unauthorized',
      RoomErrorCode.roleInvalid => 'Invalid Role',
      RoomErrorCode.alreadyJoined => 'Already in Room',
      RoomErrorCode.streamUrlInvalid => 'Invalid URL',
      RoomErrorCode.internalError => 'Server Error',
    };
  }

  String _friendlyMessage(RoomErrorCode code, String fallback) {
    return switch (code) {
      RoomErrorCode.roomNotFound =>
        'The room code you entered does not exist. Check the code and try again.',
      RoomErrorCode.roomFull =>
        'This room already has a guest. Only two participants are allowed.',
      RoomErrorCode.roomClosed => 'The host has closed this room.',
      RoomErrorCode.roleUnauthorized => 'Only the host can control playback.',
      RoomErrorCode.roleInvalid => 'Invalid role specified.',
      RoomErrorCode.alreadyJoined => 'You are already in a room.',
      RoomErrorCode.streamUrlInvalid =>
        'The stream URL must start with http://, https://, or rtsp://.',
      RoomErrorCode.internalError =>
        'An unexpected error occurred. Please try again.',
    };
  }
}
