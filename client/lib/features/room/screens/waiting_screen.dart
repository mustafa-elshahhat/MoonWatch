import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/protocol/payloads.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';
import '../bloc/room_bloc.dart';
import '../bloc/room_event.dart';
import '../bloc/room_state.dart';
import '../../reconnect/reconnect_bloc.dart';
import '../../iptv/service/iptv_navigation_memory.dart';
import 'package:get_it/get_it.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});
  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _entryCtrl;
  late final AnimationController _orbitCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _orbitAnim;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    )..repeat();
    _pulseAnim = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _orbitAnim = Tween<double>(begin: 0, end: math.pi * 2).animate(_orbitCtrl);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > AppBreakpoint.desktop;

    return BlocListener<RoomBloc, RoomState>(
      listener: (context, state) {
        if (state is RoomStateJoined || state is RoomStateActive) {
          final pending = ModalRoute.of(context)?.settings.arguments
              as IptvContentDescriptor?;
          if (pending != null) {
            context.read<RoomBloc>().add(RoomEventSetContent(pending));
          }
          Navigator.pushReplacementNamed(context, '/watch');
        } else if (state is RoomStateClosed || state is RoomStateError) {
          context.read<ReconnectBloc>().add(const ReconnectEventReset());
          GetIt.I<IptvNavigationMemory>().clear();
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildAtmosphere(sw),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        const AppLogo(size: 18),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => context.read<RoomBloc>().add(
                                const RoomEventLeaveRoom(),
                              ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                          label: Text(
                            'LEAVE',
                            style: AppTypography.mono.copyWith(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isDesktop ? 460 : sw * 0.9,
                          ),
                          child: BlocBuilder<RoomBloc, RoomState>(
                            builder: (context, state) {
                              final roomCode = state is RoomStateWaiting
                                  ? state.roomCode
                                  : '------';
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildCinematicWaiting(),
                                  const SizedBox(height: AppSpacing.huge),
                                  Text(
                                    'Almost showtime.',
                                    style: AppTypography.display.copyWith(
                                      fontSize: 42,
                                      letterSpacing: -1.2,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Share this code with your guests. Playback starts soon.',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xxl),
                                  _buildRoomCodeCard(roomCode),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAtmosphere(double w) {
    return Stack(
      children: [
        Positioned(
          top: -w * 0.3,
          right: -w * 0.2,
          child: Container(
            width: w * 0.9,
            height: w * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentPrimary.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -w * 0.2,
          left: -w * 0.15,
          child: Container(
            width: w * 0.7,
            height: w * 0.7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentSecondary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCinematicWaiting() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _orbitAnim,
            builder: (_, __) {
              return Transform.rotate(
                angle: _orbitAnim.value,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentPrimary.withValues(alpha: 0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.6,
                            ),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _orbitAnim,
            builder: (_, __) {
              return Transform.rotate(
                angle: -_orbitAnim.value * 0.7,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentSecondary.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: const BoxDecoration(
                        color: AppColors.accentSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: 80 + _pulseAnim.value * 10,
              height: 80 + _pulseAnim.value * 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(
                    alpha: (1 - _pulseAnim.value) * 0.3,
                  ),
                  width: 1,
                ),
              ),
            ),
          ),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceElevated, AppColors.surface],
              ),
              border: Border.all(color: AppColors.border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPrimary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.group_rounded,
              color: AppColors.accentPrimary,
              size: 28,
            ),
          ),
          SizedBox(
            width: 76,
            height: 76,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.accentPrimary.withValues(alpha: 0.6),
              strokeCap: StrokeCap.round,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCodeCard(String roomCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: _copied
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
          width: _copied ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          if (_copied)
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.08),
              blurRadius: 24,
            ),
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.04),
            blurRadius: 40,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'ROOM CODE',
            style: AppTypography.sectionLabel.copyWith(
              letterSpacing: 2.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < roomCode.length; i++) ...[
                _CodeChar(char: roomCode[i], index: i),
                if (i < roomCode.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: roomCode));
              setState(() => _copied = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _copied = false);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 11),
              decoration: BoxDecoration(
                color: _copied
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: _copied
                      ? AppColors.success.withValues(alpha: 0.5)
                      : AppColors.accentPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 15,
                    color:
                        _copied ? AppColors.success : AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _copied ? 'Copied!' : 'Copy Code',
                    style: TextStyle(
                      color:
                          _copied ? AppColors.success : AppColors.accentPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChar extends StatelessWidget {
  final String char;
  final int index;
  const _CodeChar({required this.char, required this.index});
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Text(
          char,
          style: AppTypography.monoLarge.copyWith(
            color: AppColors.textPrimary,
            fontSize: 22,
            shadows: [
              Shadow(
                color: AppColors.accentPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      );
}
