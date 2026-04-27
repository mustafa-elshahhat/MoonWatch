import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../bloc/room_bloc.dart';
import '../bloc/room_event.dart';
import '../bloc/room_state.dart';

/// Premium create room screen — auto-creates room and shows cinematic loading.
class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen>
    with TickerProviderStateMixin {
  final AppLogger _logger = AppLogger('CreateRoomScreen');
  late final String _correlationId;
  late final DateTime _enterTime;
  bool _creating = false;
  Timer? _timeoutTimer;

  late final AnimationController _entryCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _pulseAnim;
  late final RoomBloc _roomBloc;

  @override
  void initState() {
    super.initState();
    _enterTime = DateTime.now();
    _correlationId =
        'cr_${_enterTime.millisecondsSinceEpoch.toRadixString(16)}';

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _roomBloc = context.read<RoomBloc>(); // cache before any async/dispose risk
    _entryCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _startCreation());
  }

  void _startCreation() {
    setState(() => _creating = true);
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _creating) {
        setState(() => _creating = false);
        context.read<RoomBloc>().add(
              const RoomEventError(
                code: 'timeout',
                message:
                    'Room creation timed out. The server might be waking up.',
              ),
            );
      }
    });
    _logger.i('[$_correlationId] Dispatching RoomEventCreateRoom');
    context.read<RoomBloc>().add(
          RoomEventCreateRoom(correlationId: _correlationId),
        );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    // Use cached _roomBloc — never call context.read in dispose()
    final state = _roomBloc.state;
    if (state is RoomStateConnecting || state is RoomStateCreating) {
      _logger.i('[$_correlationId] User backed out. Canceling.');
      _roomBloc.add(const RoomEventLeaveRoom());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > AppBreakpoint.desktop;

    return BlocConsumer<RoomBloc, RoomState>(
      listener: (context, state) {
        if (state is RoomStateWaiting) {
          final diff = DateTime.now().difference(_enterTime).inMilliseconds;
          _logger.i(
            '[$_correlationId] Room created. Time: ${diff}ms, code=${state.roomCode}',
          );
          Navigator.pushReplacementNamed(context, '/waiting');
        } else if (state is RoomStateActive) {
          Navigator.pushReplacementNamed(context, '/watch');
        } else if (state is RoomStateError) {
          _logger.w('[$_correlationId] Room creation failed: ${state.message}');
          _timeoutTimer?.cancel();
          setState(() => _creating = false);
        }
      },
      builder: (context, state) {
        final isLoading = _creating ||
            state is RoomStateConnecting ||
            state is RoomStateCreating ||
            state is RoomStateWaiting;

        String phase = 'Creating your room…';
        if (state is RoomStateConnecting) {
          phase = 'Connecting to server…';
        } else if (state is RoomStateCreating) {
          phase = 'Initializing session…';
        } else if (state is RoomStateWaiting) {
          phase = 'Room ready!';
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Glows
              Positioned(
                top: -200,
                right: -100,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentPrimary.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -200,
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.accentPrimaryHover.withValues(alpha: 0.03),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // Back button bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          _BackBtn(
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isDesktop ? 480 : sw * 0.9,
                            ),
                            child: isLoading
                                ? _buildLoadingView(phase)
                                : _buildErrorView(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView(String phase) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Animated icon
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentPrimary.withValues(
                          alpha: (1 - _pulseAnim.value) * 0.5,
                        ),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentPrimary.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.movie_creation_rounded,
                  color: AppColors.accentPrimary,
                  size: 36,
                ),
              ),
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.accentPrimary,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Setting up', style: AppTypography.display),
        const SizedBox(height: AppSpacing.sm),
        FadeTransition(
          opacity: _pulseAnim,
          child: Text(
            phase,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontFamily: AppTypography.mono.fontFamily,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        // Steps
        _buildStep('Establishing connection', true),
        const SizedBox(height: AppSpacing.sm),
        _buildStep('Creating your room', _creating),
        const SizedBox(height: AppSpacing.sm),
        _buildStep('Preparing session code', false),
      ],
    );
  }

  Widget _buildStep(String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? AppColors.accentPrimary.withValues(alpha: 0.15)
                : AppColors.surface,
            border: Border.all(
              color: active ? AppColors.accentPrimary : AppColors.border,
            ),
          ),
          child: active
              ? const Center(
                  child: SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.accentPrimary,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: active ? AppColors.textSecondary : AppColors.textDisabled,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 36,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Could not create room', style: AppTypography.display),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Please check your connection\nand try again.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        GestureDetector(
          onTap: () {
            _logger.i('[$_correlationId] Retrying');
            _startCreation();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentPrimaryHover, AppColors.accentPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentPrimary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Text(
              'Try Again',
              style: AppTypography.button.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(
            'Go Back',
            style: AppTypography.buttonSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _BackBtn({required this.onTap});
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _h ? AppColors.surfaceElevated : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: _h ? AppColors.border : AppColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 12,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  'BACK',
                  style: AppTypography.mono.copyWith(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
