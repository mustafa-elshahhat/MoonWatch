import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const AppLogo({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _LogoPainter(color: c),
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            text: 'moon',
            style: AppTypography.displayHero.copyWith(
              fontSize: size * 1.1,
              fontStyle: FontStyle.normal,
              color: c,
              letterSpacing: -0.5,
              height: 1.0,
            ),
            children: [
              const TextSpan(
                text: '.',
                style: TextStyle(
                  color: AppColors.accentPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color color;
  _LogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.45,
      paint,
    );

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.35, size.height * 0.3)
      ..lineTo(size.width * 0.65, size.height * 0.5)
      ..lineTo(size.width * 0.35, size.height * 0.7)
      ..close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionEyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const SectionEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.mono.copyWith(
        fontSize: 10,
        color: color ?? AppColors.textMuted,
        letterSpacing: 2.0,
      ),
    );
  }
}

class StripedPoster extends StatelessWidget {
  final String? label;
  final double aspectRatio;
  final Color accent;
  final Widget? child;

  const StripedPoster({
    super.key,
    this.label,
    this.aspectRatio = 2 / 3,
    this.accent = AppColors.accentPrimary,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: AppColors.borderSubtle),
          color: AppColors.background,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _StripedPainter(color: AppColors.surface)),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.4, -0.6),
                    radius: 1.2,
                    colors: [
                      accent.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
            if (child != null) child!,
            if (label != null)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Text(
                  label!.toUpperCase(),
                  style: AppTypography.mono.copyWith(
                    fontSize: 9,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripedPainter extends CustomPainter {
  final Color color;
  _StripedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    double maxDim = max(size.width, size.height) * 2;
    for (double i = -maxDim; i < maxDim; i += 16) {
      canvas.drawLine(Offset(i, 0), Offset(i + maxDim, maxDim), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppIconSize.md, color: AppColors.accentPrimary),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(child: Text(title, style: AppTypography.titleSmall)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(label, style: AppTypography.sectionLabel),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? backgroundColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  factory StatusBadge.host() => const StatusBadge(
        label: 'HOST',
        color: AppColors.hostBadge,
        backgroundColor: AppColors.hostBadgeBg,
      );

  factory StatusBadge.guest() => const StatusBadge(
        label: 'GUEST',
        color: AppColors.guestBadge,
        backgroundColor: AppColors.guestBadgeBg,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.15),
        borderRadius: AppRadius.xsBorder,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label, style: AppTypography.badge.copyWith(color: color)),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Widget? leading;
  final bool showSpinner;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.leading,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSpinner) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.xs + 1),
          ],
          Text(label, style: AppTypography.chip.copyWith(color: color)),
        ],
      ),
    );
  }
}

class RoomCodeCard extends StatelessWidget {
  final String roomCode;
  final VoidCallback? onCopy;

  const RoomCodeCard({super.key, required this.roomCode, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text('ROOM CODE', style: AppTypography.sectionLabel),
          const SizedBox(height: AppSpacing.md),
          Text(
            roomCode,
            style: AppTypography.monoLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (onCopy != null) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: AppIconSize.sm),
              label: const Text('Copy Code'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 40)),
            ),
          ],
        ],
      ),
    );
  }
}

class AppConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color? confirmColor;
  final IconData? icon;

  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmColor,
    this.icon,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color? confirmColor,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: confirmColor,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = confirmColor ?? AppColors.accentPrimary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xF21A1714),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.72),
                  blurRadius: 42,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-0.72, -0.85),
                          radius: 1.2,
                          colors: [
                            actionColor.withValues(alpha: 0.13),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (icon != null)
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: actionColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: actionColor.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Icon(
                                  icon,
                                  size: AppIconSize.lg,
                                  color: actionColor,
                                ),
                              ),
                            if (icon != null)
                              const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    message,
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.48,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stackButtons = constraints.maxWidth < 330;
                            final stayButton = FocusTraversalOrder(
                              order: const NumericFocusOrder(1),
                              child: OutlinedButton(
                                autofocus: true,
                                onPressed: () => Navigator.pop(context, false),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size(
                                    stackButtons ? double.infinity : 120,
                                    46,
                                  ),
                                  foregroundColor: AppColors.textPrimary,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.04),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(cancelLabel),
                              ),
                            );
                            final leaveButton = FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: FilledButton.icon(
                                onPressed: () => Navigator.pop(context, true),
                                icon: const Icon(
                                  Icons.exit_to_app_rounded,
                                  size: 18,
                                ),
                                label: Text(confirmLabel),
                                style: FilledButton.styleFrom(
                                  minimumSize: Size(
                                    stackButtons ? double.infinity : 128,
                                    46,
                                  ),
                                  backgroundColor: actionColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            );

                            if (stackButtons) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  leaveButton,
                                  const SizedBox(height: AppSpacing.sm),
                                  stayButton,
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                stayButton,
                                const SizedBox(width: AppSpacing.sm),
                                leaveButton,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MediaTile extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const MediaTile({
    super.key,
    this.imageUrl,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: ClipRRect(
        borderRadius: AppRadius.smBorder,
        child: SizedBox(
          width: 48,
          height: 48,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagePlaceholder(),
                )
              : _imagePlaceholder(),
        ),
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTypography.caption)
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.surfaceElevated,
      child: const Icon(
        Icons.image,
        size: AppIconSize.lg,
        color: AppColors.textDisabled,
      ),
    );
  }
}

class PlayIconButton extends StatelessWidget {
  const PlayIconButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.hostBadgeBg,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: AppIconSize.md,
        color: AppColors.accentPrimary,
      ),
    );
  }
}
