import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';
import '../../navigation/screens/main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _particleCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _fadeAnim = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
          ),
        );
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, c) {
          final isDesktop = c.maxWidth > 900;
          final isWide = c.maxWidth > 1200;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Rich atmospheric background
              _buildAtmosphere(c.maxWidth, c.maxHeight),
              // Main content
              SafeArea(
                child: isDesktop
                    ? _buildDesktopLayout(context, c.maxWidth, isWide)
                    : _buildMobileLayout(context),
              ),
            ],
          );
        },
      ),
    );
  }

  // —— Atmospheric background —————————————————————————————————————————

  Widget _buildAtmosphere(double w, double h) {
    return Stack(
      children: [
        // Deep space base
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.3, -0.4),
              radius: 1.2,
              colors: [Color(0xFF0C0A14), AppColors.background],
              stops: [0.0, 1.0],
            ),
          ),
        ),
        // Cinematic accent glow — top left
        Positioned(
          top: -h * 0.2,
          left: -w * 0.15,
          child: Container(
            width: w * 0.8,
            height: h * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.accentPrimary.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Gold accent — bottom right
        Positioned(
          bottom: -h * 0.1,
          right: -w * 0.2,
          child: Container(
            width: w * 0.7,
            height: h * 0.5,
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
        // Subtle film grain texture simulation via AnimatedBuilder
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) {
            return CustomPaint(
              painter: _ParticlePainter(_particleCtrl.value),
              size: Size(w, h),
            );
          },
        ),
        // Horizontal streak lines — cinematic atmosphere
        Positioned(
          top: h * 0.3,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.accentPrimary.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: h * 0.6,
          left: 0,
          right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.border.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // —— Desktop layout —————————————————————————————————————————————————

  Widget _buildDesktopLayout(BuildContext context, double w, bool isWide) {
    final hPad = isWide ? w * 0.12 : w * 0.08;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isWide ? 100 : 72),
              _buildHero(isDesktop: true),
              const SizedBox(height: 80),
              _buildDesktopCards(context),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionEyebrow('A—01  -  Watch Solo', color: AppColors.textMuted),
        const SizedBox(height: AppSpacing.lg),
        _WatchSoloCard(
          onTap: () {
            final shell = context.findAncestorStateOfType<MainShellState>();
            shell?.switchToIptv();
          },
        ),
        const SizedBox(height: AppSpacing.xxxl),
        const SectionEyebrow(
          'A—02  -  Watch Together',
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _RoomCard(
                type: _RoomCardType.create,
                onTap: () => Navigator.pushNamed(context, '/create'),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: _RoomCard(
                type: _RoomCardType.join,
                onTap: () {
                  final shell = context
                      .findAncestorStateOfType<MainShellState>();
                  shell?.switchToRooms();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // —— Mobile layout ——————————————————————————————————————————————————

  Widget _buildMobileLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              _buildHero(isDesktop: false),
              const SizedBox(height: 56),
              const SectionEyebrow(
                'A—01  -  Watch Solo',
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              _WatchSoloCard(
                onTap: () {
                  final shell = context
                      .findAncestorStateOfType<MainShellState>();
                  shell?.switchToIptv();
                },
              ),
              const SizedBox(height: AppSpacing.xxxl),
              const SectionEyebrow(
                'A—02  -  Watch Together',
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.md),
              _RoomCard(
                type: _RoomCardType.create,
                onTap: () => Navigator.pushNamed(context, '/create'),
              ),
              const SizedBox(height: AppSpacing.md),
              _RoomCard(
                type: _RoomCardType.join,
                onTap: () {
                  final shell = context
                      .findAncestorStateOfType<MainShellState>();
                  shell?.switchToRooms();
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // —— Hero ———————————————————————————————————————————————————————————

  Widget _buildHero({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        const SectionEyebrow('Tonight on moon', color: AppColors.accentPrimary),
        const SizedBox(height: AppSpacing.lg),

        // Cinematic headline
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Cinema,\nshared ',
                style:
                    (isDesktop
                            ? AppTypography.displayHero
                            : AppTypography.display)
                        .copyWith(
                          color: AppColors.textPrimary,
                          height: 1.05,
                          letterSpacing: -1.5,
                        ),
              ),
              TextSpan(
                text: 'in sync.',
                style:
                    (isDesktop
                            ? AppTypography.displayHero
                            : AppTypography.display)
                        .copyWith(
                          color: AppColors.accentPrimary,
                          height: 1.05,
                          letterSpacing: -1.5,
                          fontStyle: FontStyle.italic,
                          shadows: [
                            Shadow(
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 40,
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        // Tagline
        Text(
          'A quiet place to watch live TV, films, and series with the\npeople you care about — latency measured in milliseconds,\nnot moods.',
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.textMuted,
            height: 1.7,
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        // Stats row — inject trust/soul
        const Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: [
            _StatChip(label: 'HD Streams', value: '4K'),
            _StatChip(label: 'Sync Delay', value: '<50ms'),
            _StatChip(label: 'Channels', value: '1000+'),
          ],
        ),
      ],
    );
  }
}

// —— Watch Solo Card ————————————————————————————————————————————————

class _WatchSoloCard extends StatefulWidget {
  final VoidCallback onTap;
  const _WatchSoloCard({required this.onTap});
  @override
  State<_WatchSoloCard> createState() => _WatchSoloCardState();
}

class _WatchSoloCardState extends State<_WatchSoloCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutQuart,
        transform: Matrix4.translationValues(0.0, _h ? -4.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          gradient: _h
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentPrimary.withValues(alpha: 0.12),
                    AppColors.surfaceElevated,
                  ],
                )
              : const LinearGradient(
                  colors: [AppColors.surface, AppColors.surface],
                ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _h
                ? AppColors.accentPrimary.withValues(alpha: 0.35)
                : AppColors.border,
            width: _h ? 1.5 : 1,
          ),
          boxShadow: _h
              ? [
                  BoxShadow(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            // Icon cluster
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _h
                        ? AppColors.accentPrimary.withValues(alpha: 0.18)
                        : AppColors.accentPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: _h
                        ? [
                            BoxShadow(
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    Icons.play_circle_rounded,
                    color: AppColors.accentPrimary,
                    size: _h ? 38 : 34,
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Watch Solo',
                    style: AppTypography.titleLarge.copyWith(
                      letterSpacing: -0.3,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Live TV  -  Movies  -  Series — all in one place',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Mini tags
                  const Wrap(
                    spacing: 6,
                    children: [
                      _MiniTag('LIVE', AppColors.error),
                      _MiniTag('MOVIES', AppColors.accentPrimary),
                      _MiniTag('SERIES', AppColors.success),
                    ],
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 280),
              opacity: _h ? 1.0 : 0.3,
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textMuted,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// —— Room Cards —————————————————————————————————————————————————————

enum _RoomCardType { create, join }

class _RoomCard extends StatefulWidget {
  final _RoomCardType type;
  final VoidCallback onTap;
  const _RoomCard({required this.type, required this.onTap});
  @override
  State<_RoomCard> createState() => _RoomCardState();
}

class _RoomCardState extends State<_RoomCard> {
  bool _h = false;

  Color get _accent => widget.type == _RoomCardType.create
      ? AppColors.accentSecondary
      : AppColors.success;
  IconData get _icon => widget.type == _RoomCardType.create
      ? Icons.add_circle_rounded
      : Icons.login_rounded;
  String get _title =>
      widget.type == _RoomCardType.create ? 'Create a Room' : 'Join a Room';
  String get _sub => widget.type == _RoomCardType.create
      ? 'Host a synchronized session for your friends'
      : 'Enter a code to join someone\'s stream';
  String get _label =>
      widget.type == _RoomCardType.create ? 'NEW ROOM' : 'JOIN';

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _h = true),
    onExit: (_) => setState(() => _h = false),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutQuart,
        transform: Matrix4.translationValues(0.0, _h ? -4.0 : 0.0, 0.0),
        decoration: BoxDecoration(
          color: _h ? AppColors.surfaceElevated : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: _h
                ? _accent.withValues(alpha: 0.35)
                : AppColors.borderSubtle,
            width: _h ? 1.5 : 1,
          ),
          boxShadow: _h
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _h
                        ? _accent.withValues(alpha: 0.18)
                        : _accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: _h
                        ? [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.3),
                              blurRadius: 16,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(_icon, color: _accent, size: 22),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _h
                        ? _accent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: _accent.withValues(alpha: _h ? 0.4 : 0.2),
                    ),
                  ),
                  child: Text(
                    _label,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _title,
              style: AppTypography.title.copyWith(
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _sub,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _h ? 1.0 : 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _h
                        ? 'Tap to continue'
                        : 'Tap to ${widget.type == _RoomCardType.create ? 'create' : 'join'}',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, color: _accent, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// —— Shared micro-components ————————————————————————————————————————

// _SectionLabel removed in favor of SectionEyebrow

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.accentPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      ],
    ),
  );
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// —— Particle painter for cinematic atmosphere ——————————————————————

class _ParticlePainter extends CustomPainter {
  final double progress;
  static final _rng = math.Random(42);
  static final _particles = List.generate(
    25,
    (i) => [
      _rng.nextDouble(), // x
      _rng.nextDouble(), // y
      _rng.nextDouble() * 0.5 + 0.5, // speed
      _rng.nextDouble() * 2 + 1, // size
    ],
  );

  const _ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _particles) {
      final x = p[0] * size.width;
      final y = ((p[1] + progress * p[2] * 0.3) % 1.0) * size.height;
      final opacity =
          (math.sin(progress * math.pi * 2 + p[0] * math.pi) * 0.5 + 0.5) *
          0.08;
      paint.color = AppColors.textPrimary.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), p[3], paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
