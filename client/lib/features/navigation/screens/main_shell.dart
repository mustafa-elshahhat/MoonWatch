import 'dart:ui';
import 'package:flutter/material.dart';
import '../../room/screens/home_screen.dart';
import '../../room/screens/join_room_screen.dart';
import '../../iptv/screens/iptv_browse_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  final Set<int> _visitedIndices = {0};

  void switchToIptv({String mode = 'solo'}) {
    setState(() {
      _currentIndex = 1;
      _visitedIndices.add(1);
    });
  }

  void switchToHome() {
    setState(() {
      _currentIndex = 0;
      _visitedIndices.add(0);
    });
  }

  void switchToRooms() {
    setState(() {
      _currentIndex = 2;
      _visitedIndices.add(2);
    });
  }

  Widget _buildScreen(int index) {
    return IndexedStack(
      index: index,
      children: [
        const HomeScreen(),
        _visitedIndices.contains(1)
            ? Navigator(
                key: const PageStorageKey('iptv_nav'),
                onGenerateRoute: (settings) {
                  return MaterialPageRoute(
                    builder: (_) => const IptvBrowseScreen(),
                    settings: const RouteSettings(
                      name: '/iptv',
                      arguments: 'solo',
                    ),
                  );
                },
              )
            : const SizedBox.shrink(),
        _visitedIndices.contains(2)
            ? const JoinRoomScreen()
            : const SizedBox.shrink(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return Scaffold(
            body: Row(
              children: [
                _buildSideNavigation(),
                Expanded(child: _buildScreen(_currentIndex)),
              ],
            ),
          );
        } else {
          return Scaffold(
            extendBody: true,
            body: _buildScreen(_currentIndex),
            bottomNavigationBar: _buildPremiumBottomNav(),
          );
        }
      },
    );
  }

  Widget _buildPremiumBottomNav() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.75),
            border: const Border(
              top: BorderSide(color: AppColors.borderSubtle, width: 1.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Home'),
                  _buildNavItem(1, Icons.explore_rounded, 'Browse'),
                  _buildNavItem(2, Icons.meeting_room_rounded, 'Rooms'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideNavigation() {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          const CustomPaint(
            size: Size(24, 24),
            painter: _CrescentPainter(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.huge),
          _buildSideNavItem(0, Icons.home_rounded, 'Home'),
          _buildSideNavItem(1, Icons.explore_rounded, 'Browse'),
          _buildSideNavItem(2, Icons.meeting_room_rounded, 'Rooms'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              '1.0',
              style: AppTypography.mono.copyWith(
                fontSize: 9,
                color: AppColors.textDisabled,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _currentIndex = index;
        _visitedIndices.add(index);
      }),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.surfaceElevated.withValues(alpha: 0.8)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: isSelected ? AppColors.borderSubtle : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Icon(
                icon,
                key: ValueKey<bool>(isSelected),
                color: isSelected
                    ? AppColors.accentPrimary
                    : AppColors.textDisabled,
                size: isSelected ? 28 : 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.captionSmall.copyWith(
                color:
                    isSelected ? AppColors.textPrimary : AppColors.textDisabled,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() {
        _currentIndex = index;
        _visitedIndices.add(index);
      }),
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      child: SizedBox(
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 2.5 : 0,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.accentPrimary,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentPrimary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: AppTypography.captionSmall.copyWith(
                    fontFamily: 'Inter',
                    color: isSelected
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0.2,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CrescentPainter extends CustomPainter {
  final Color color;
  const _CrescentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.46;

    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

    final inner = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx + r * 0.42, cy - r * 0.08),
          radius: r * 0.78,
        ),
      );

    final crescent = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(crescent, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
