import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/network/http_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../bloc/room_bloc.dart';
import '../bloc/room_event.dart';
import '../bloc/room_state.dart';

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

  List<Map<String, dynamic>>? _rooms;
  bool _loadingRooms = false;
  String? _roomsError;
  bool _isRefreshing = false;
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
    // Removed _fetchRooms() from initState to prevent API calls on app startup
    // before user explicitly navigates to this screen.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TickerMode.valuesOf(context).enabled;
    if (isVisible) {
      if (_rooms == null && !_loadingRooms) {
        _fetchRooms();
      }
      _refreshTimer ??= Timer.periodic(
        const Duration(seconds: 10),
        (_) => _silentRefresh(),
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

  Future<void> _silentRefresh() async {
    if (!mounted || _isRefreshing || _joining) return;
    _isRefreshing = true;
    try {
      final rooms = await GetIt.instance<HttpClient>().listRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _roomsError = null;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) _isRefreshing = false;
    }
  }

  Future<void> _fetchRooms() async {
    debugPrint('[PROFILER] rooms_load_start');
    final start = DateTime.now();
    setState(() {
      _loadingRooms = true;
      _roomsError = null;
    });
    try {
      final rooms = await GetIt.instance<HttpClient>().listRooms();
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _loadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _roomsError = 'Could not load rooms. Check your connection.';
          _loadingRooms = false;
        });
      }
    } finally {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      debugPrint('[PROFILER] rooms_load_end: ${elapsed}ms');
    }
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
    if (_loadingRooms) {
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
    if (_roomsError != null) {
      return _PremiumErrorState(message: _roomsError!, onRetry: _fetchRooms);
    }
    if (_rooms == null || _rooms!.isEmpty) {
      return _buildEmptyRooms();
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_rooms!.length} room${_rooms!.length == 1 ? '' : 's'} available',
                style: AppTypography.caption,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppColors.accentPrimary,
              ),
              onPressed: _fetchRooms,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._rooms!.map(
          (r) => _RoomCard(
            room: r,
            isJoining: _joiningCode == r['roomCode'],
            canJoin: !_joining,
            onJoin: (code) => _joinRoom(code),
          ),
        ),
      ],
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
            onTap: _fetchRooms,
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

// ── Room Card ──────────────────────────────────────────────────────────────────

class _RoomCard extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool isJoining;
  final bool canJoin;
  final void Function(String) onJoin;
  const _RoomCard({
    required this.room,
    required this.isJoining,
    required this.canJoin,
    required this.onJoin,
  });
  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
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
              // Dynamic Icon
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
              // Info
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
              // Join button
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

class _PremiumErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _PremiumErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Retry',
                  style: AppTypography.buttonSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
