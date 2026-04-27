import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../bloc/room_bloc.dart';
import '../bloc/room_event.dart';
import '../bloc/room_state.dart';

import '../bloc/room_list_bloc.dart';

import '../widgets/room_card.dart';
import '../widgets/premium_error_state.dart';

/// Premium Rooms tab: active rooms list + manual code entry.
class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen>
    with SingleTickerProviderStateMixin {
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _refreshTimer;

  String? _joiningCode;
  bool get _joining => _joiningCode != null;

  bool _navigatedToWatch = false;

  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();

    // Initial fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomListBloc>().add(const RoomListFetch());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (isVisible) {
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) =>
            context.read<RoomListBloc>().add(const RoomListFetch(silent: true)),
      );
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _codeCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _joinRoom(String code) {
    setState(() => _joiningCode = code.toUpperCase());
    context.read<RoomBloc>().add(RoomEventJoinRoom(code.toUpperCase()));
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > AppBreakpoint.desktop;
    final isTablet = sw > AppBreakpoint.tablet;

    return BlocListener<RoomBloc, RoomState>(
      listener: (context, state) {
        if (state is RoomStateActive ||
            state is RoomStateJoined ||
            state is RoomStateWaiting) {
          if (_navigatedToWatch) return;
          _navigatedToWatch = true;
          Navigator.pushReplacementNamed(context, '/watch');
        } else if (state is RoomStateError) {
          setState(() => _joiningCode = null);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Atmospheric glow
            Positioned(
              top: -150,
              left: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentPrimary.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: _buildLayout(sw, isDesktop, isTablet),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLayout(double sw, bool isDesktop, bool isTablet) {
    if (isDesktop) {
      // Desktop: two-column layout
      return Row(
        children: [
          Expanded(flex: 6, child: _buildScrollContent(sw, isDesktop)),
          Container(width: 1, color: AppColors.borderSubtle),
          Expanded(
            flex: 4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.huge),
                child: _buildCodeEntry(wide: true),
              ),
            ),
          ),
        ],
      );
    }
    return _buildScrollContent(sw, isDesktop);
  }

  Widget _buildScrollContent(double sw, bool isDesktop) {
    final hPad = isDesktop ? sw * 0.04 : AppSpacing.lg;
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              hPad,
              AppSpacing.xl,
              hPad,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: AppTypography.badge.copyWith(
                              color: AppColors.success,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Drop right in.',
                  style: AppTypography.display.copyWith(
                    fontSize: 48,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Six letters from the host is all it takes. Your player will match their playhead within milliseconds.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Room list section
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          sliver: SliverToBoxAdapter(child: _buildRoomsSection()),
        ),
        // Divider + code entry (mobile/tablet only)
        if (sw <= AppBreakpoint.desktop)
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
              vertical: AppSpacing.xxl,
            ),
            sliver: SliverToBoxAdapter(child: _buildCodeEntry(wide: false)),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.huge)),
      ],
    );
  }

  Widget _buildRoomsSection() {
    return BlocBuilder<RoomListBloc, RoomListState>(
      builder: (context, state) {
        if (state is RoomListLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentPrimary,
                ),
              ),
            ),
          );
        }
        if (state is RoomListError) {
          return PremiumErrorState(
            message: state.message,
            onRetry: () =>
                context.read<RoomListBloc>().add(const RoomListFetch()),
          );
        }
        if (state is RoomListLoaded) {
          final rooms = state.rooms;
          if (rooms.isEmpty) {
            return _buildEmptyRooms();
          }
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${rooms.length} room${rooms.length == 1 ? '' : 's'} available',
                      style: AppTypography.caption,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: AppColors.accentPrimary,
                    ),
                    onPressed: () =>
                        context.read<RoomListBloc>().add(const RoomListFetch()),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...rooms.map(
                (r) => RoomCard(
                  room: r,
                  isJoining: _joiningCode == r['roomCode'],
                  canJoin: !_joining,
                  onJoin: (code) => _joinRoom(code),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildEmptyRooms() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceElevated,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.meeting_room_outlined,
              size: 26,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No active rooms',
            style: AppTypography.titleSmall.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ask a host to create one, or enter a code below',
            style: AppTypography.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onTap: () =>
                context.read<RoomListBloc>().add(const RoomListFetch()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Refresh',
                    style: AppTypography.buttonSmall.copyWith(
                      color: AppColors.textSecondary,
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

  Widget _buildCodeEntry({required bool wide}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: AppColors.accentPrimary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (wide) ...[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.accentPrimary.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.dialpad_rounded,
                  color: AppColors.accentPrimary,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'JOIN WITH CODE',
                      style: AppTypography.sectionLabel.copyWith(
                        letterSpacing: 2.0,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider)),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Text(
              'Got a code?',
              style: AppTypography.title.copyWith(
                fontFamily: AppTypography.displayHero.fontFamily,
                fontSize: 24,
                letterSpacing: -0.5,
                fontStyle: FontStyle.italic,
                color: AppColors.accentPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter the 6-letter room code below',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextFormField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: AppTypography.monoCode.copyWith(
                  color: AppColors.accentPrimary,
                  fontSize: 32,
                  letterSpacing: 12,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(
                      color: AppColors.accentPrimary.withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                cursorColor: AppColors.accentPrimary,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  counterText: '',
                  hintStyle: TextStyle(
                    color: AppColors.textDisabled.withValues(alpha: 0.3),
                    letterSpacing: 12,
                    fontSize: 32,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppRadius.lgBorder.topLeft.x,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppRadius.lgBorder.topLeft.x,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppRadius.lgBorder.topLeft.x,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.accentPrimary,
                      width: 2,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length != 6) {
                    return 'Must be 6 characters';
                  }
                  if (!RegExp(r'^[A-Z2-9]{6}$').hasMatch(v)) {
                    return 'Invalid code format';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _joining
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _joinRoom(_codeCtrl.text);
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    elevation: 8,
                    shadowColor: AppColors.accentPrimary.withValues(alpha: 0.5),
                  ),
                  child: _joining
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Connect to Room',
                          style: AppTypography.button.copyWith(
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
