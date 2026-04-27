import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';

class ConfigMissingScreen extends StatelessWidget {
  final String? error;
  const ConfigMissingScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLogo(size: 40),
                const SizedBox(height: AppSpacing.xxl),
                const Icon(
                  Icons.settings_suggest_outlined,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Configuration Missing',
                  style: AppTypography.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'App configuration is missing or invalid. Please follow these steps:',
                  style: AppTypography.body
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildStep(
                  '1',
                  'Copy client/assets/config/appsettings.example.json to client/assets/config/appsettings.local.json',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStep(
                  '2',
                  'Update the values in appsettings.local.json with your provider URLs.',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildStep(
                  '3',
                  'Restart the application.',
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.xxl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'Error detail: $error',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.accentPrimary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: AppTypography.body.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}
