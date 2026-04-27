import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../core/protocol/payloads.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';
import '../../../shared/widgets/state_views.dart';

import '../bloc/iptv_bloc.dart';
import '../bloc/iptv_event.dart';
import '../bloc/iptv_state.dart';
import '../models/iptv_category.dart';
import '../models/live_stream.dart';
import '../models/vod_stream.dart';
import '../models/series_item.dart';
import '../repository/iptv_repository.dart';
import '../service/iptv_navigation_memory.dart';
import 'iptv_series_detail_screen.dart';

class IptvCategoryContentScreen extends StatefulWidget {
  final IptvContentType contentType;
  final String categoryId;
  final String categoryName;
  final String mode;

  const IptvCategoryContentScreen({
    super.key,
    required this.contentType,
    required this.categoryId,
    required this.categoryName,
    this.mode = 'solo',
  });

  @override
  State<IptvCategoryContentScreen> createState() =>
      _IptvCategoryContentScreenState();
}

class _IptvCategoryContentScreenState extends State<IptvCategoryContentScreen> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadContent() {
    context.read<IptvBloc>().add(
      IptvLoadCategoryContent(
        contentType: widget.contentType,
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > AppBreakpoint.desktop;
    final hPad = isDesktop ? sw * 0.06 : AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Atmospheric glow
          Positioned(
            top: -150,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentPrimary.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(hPad),
                // Search
                _buildSearchBar(hPad),
                // Content
                Expanded(
                  child: BlocBuilder<IptvBloc, IptvState>(
                    builder: (context, state) {
                      if (state is IptvLoading) {
                        return const LoadingState();
                      }
                      if (state is IptvError) {
                        return ErrorState(
                          message: state.message,
                          onRetry: _loadContent,
                        );
                      }
                      if (state is IptvLiveStreamsLoaded) {
                        return _buildGrid(state.streams, hPad, isDesktop);
                      }
                      if (state is IptvVodStreamsLoaded) {
                        return _buildGrid(state.streams, hPad, isDesktop);
                      }
                      if (state is IptvSeriesListLoaded) {
                        return _buildGrid(state.seriesList, hPad, isDesktop);
                      }
                      return const LoadingState();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.xl, hPad, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackBtn(onTap: () => Navigator.of(context).pop()),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SectionEyebrow(
                  _contentTypeLabel,
                  color: AppColors.accentPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.categoryName,
                  style: AppTypography.display.copyWith(
                    fontSize: 32,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _contentTypeLabel => switch (widget.contentType) {
    IptvContentType.live => 'LIVE TV',
    IptvContentType.movie => 'MOVIES',
    IptvContentType.series => 'SERIES',
  };

  Widget _buildSearchBar(double hPad) {
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, AppSpacing.sm, hPad, AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          cursorColor: AppColors.accentPrimary,
          decoration: InputDecoration(
            hintText: 'Search in ${widget.categoryName}...',
            hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.accentPrimary,
              size: 20,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildGrid(List<dynamic> items, double hPad, bool isDesktop) {
    final filtered = _searchQuery.isEmpty
        ? items
        : items.where((item) {
            final name = switch (item) {
              LiveStream s => s.name.toLowerCase(),
              VodStream s => s.name.toLowerCase(),
              SeriesItem s => s.name.toLowerCase(),
              _ => '',
            };
            return name.contains(_searchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        message: 'No results for "$_searchQuery"',
        hint: 'Try a different search term',
      );
    }

    final sw = MediaQuery.of(context).size.width;
    // Determine grid columns based on content type and screen size
    final cols = switch (widget.contentType) {
      IptvContentType.live =>
        sw > 1200
            ? 5
            : sw > AppBreakpoint.desktop
            ? 4
            : sw > AppBreakpoint.tablet
            ? 3
            : 2,
      IptvContentType.movie =>
        sw > 1400
            ? 6
            : sw > 1100
            ? 5
            : sw > AppBreakpoint.desktop
            ? 4
            : sw > AppBreakpoint.tablet
            ? 3
            : 2,
      IptvContentType.series =>
        sw > 1400
            ? 5
            : sw > AppBreakpoint.desktop
            ? 4
            : sw > AppBreakpoint.tablet
            ? 3
            : 2,
    };

    // Aspect ratio per content type
    final aspect = switch (widget.contentType) {
      IptvContentType.live => 1.4, // widescreen channel card
      IptvContentType.movie => 0.68, // poster portrait
      IptvContentType.series => 0.68, // poster portrait
    };

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, AppSpacing.xl),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: aspect,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        return _buildCard(item, i);
      },
    );
  }

  Widget _buildCard(dynamic item, int index) {
    switch (item) {
      case LiveStream stream:
        return _LiveChannelCard(
          stream: stream,
          index: index,
          onTap: () => _handleLive(stream),
        );
      case VodStream stream:
        return _MovieCard(
          stream: stream,
          index: index,
          onTap: () => _handleVod(stream),
        );
      case SeriesItem series:
        return _SeriesCard(
          series: series,
          index: index,
          onTap: () => _handleSeries(series),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _handleLive(LiveStream s) {
    final repo = GetIt.instance<IptvRepository>();
    final url = repo.getLivePlaybackUrl(s.streamId);
    if (widget.mode == 'room') {
      Navigator.of(context, rootNavigator: true).pop(
        IptvContentSelected(
          descriptor: IptvContentDescriptor(
            contentType: IptvDescriptorType.live,
            streamId: s.streamId.toString(),
            title: s.name,
          ),
          title: s.name,
        ),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/solo-player',
        arguments: {'title': s.name, 'url': url, 'contentType': 'live'},
      );
    }
  }

  void _handleVod(VodStream s) {
    final repo = GetIt.instance<IptvRepository>();
    final url = repo.getVodPlaybackUrl(s.streamId, s.containerExtension);
    if (widget.mode == 'room') {
      Navigator.of(context, rootNavigator: true).pop(
        IptvContentSelected(
          descriptor: IptvContentDescriptor(
            contentType: IptvDescriptorType.movie,
            streamId: s.streamId.toString(),
            containerExtension: s.containerExtension,
            title: s.name,
          ),
          title: s.name,
        ),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/solo-player',
        arguments: {'title': s.name, 'url': url, 'contentType': 'movie'},
      );
    }
  }

  void _handleSeries(SeriesItem s) async {
    GetIt.I<IptvNavigationMemory>().saveSeries(s.seriesId.toString(), s.name);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => IptvBloc(repository: GetIt.instance<IptvRepository>()),
          child: IptvSeriesDetailScreen(
            seriesId: s.seriesId,
            seriesName: s.name,
            mode: widget.mode,
          ),
        ),
      ),
    );
    GetIt.I<IptvNavigationMemory>().clearSeries();
  }
}

// —— Live Channel Card ——————————————————————————————————————————————

class _LiveChannelCard extends StatefulWidget {
  final LiveStream stream;
  final int index;
  final VoidCallback onTap;
  const _LiveChannelCard({
    required this.stream,
    required this.index,
    required this.onTap,
  });
  @override
  State<_LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends State<_LiveChannelCard>
    with SingleTickerProviderStateMixin {
  bool _h = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 20), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    return FadeTransition(
      opacity: _fade,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: _h ? AppColors.surfaceElevated : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _h
                    ? AppColors.accentPrimary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
              boxShadow: _h
                  ? [
                      BoxShadow(
                        color: AppColors.accentPrimary.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel logo area
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md),
                        ),
                        child: s.streamIcon != null && s.streamIcon!.isNotEmpty
                            ? Image.network(
                                s.streamIcon!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    _channelPlaceholder(),
                              )
                            : _channelPlaceholder(),
                      ),
                      // LIVE badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Hover overlay
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _h ? 1.0 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.md),
                            ),
                            color: AppColors.accentPrimary.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Name
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(
                    s.name,
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _h
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _channelPlaceholder() => Container(
    color: AppColors.backgroundSecondary,
    child: const Center(
      child: Icon(
        Icons.live_tv_rounded,
        color: AppColors.textDisabled,
        size: 32,
      ),
    ),
  );
}

// —— Movie Poster Card ——————————————————————————————————————————————

class _MovieCard extends StatefulWidget {
  final VodStream stream;
  final int index;
  final VoidCallback onTap;
  const _MovieCard({
    required this.stream,
    required this.index,
    required this.onTap,
  });
  @override
  State<_MovieCard> createState() => _MovieCardState();
}

class _MovieCardState extends State<_MovieCard>
    with SingleTickerProviderStateMixin {
  bool _h = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 18), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stream;
    return FadeTransition(
      opacity: _fade,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0.0, _h ? -4.0 : 0.0, 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _h
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster image
                  s.streamIcon != null && s.streamIcon!.isNotEmpty
                      ? Image.network(
                          s.streamIcon!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _posterPlaceholder(),
                        )
                      : _posterPlaceholder(),
                  // Bottom gradient + metadata
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xF0000000), Color(0x00000000)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.rating != null && s.rating! > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                  color: AppColors.accentSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  s.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppColors.accentSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 2),
                          Text(
                            s.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hover play overlay
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _h ? 1.0 : 0.0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  // Border glow on hover
                  if (_h)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.accentPrimary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
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

  Widget _posterPlaceholder() => Container(
    color: AppColors.surface,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.movie_rounded,
          color: AppColors.textDisabled,
          size: 36,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            widget.stream.name,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

// —— Series Card ————————————————————————————————————————————————————

class _SeriesCard extends StatefulWidget {
  final SeriesItem series;
  final int index;
  final VoidCallback onTap;
  const _SeriesCard({
    required this.series,
    required this.index,
    required this.onTap,
  });
  @override
  State<_SeriesCard> createState() => _SeriesCardState();
}

class _SeriesCardState extends State<_SeriesCard>
    with SingleTickerProviderStateMixin {
  bool _h = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 18), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    return FadeTransition(
      opacity: _fade,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0.0, _h ? -4.0 : 0.0, 0.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _h
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Cover image
                  s.cover != null && s.cover!.isNotEmpty
                      ? Image.network(
                          s.cover!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _seriesPlaceholder(),
                        )
                      : _seriesPlaceholder(),
                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xF5000000), Color(0x00000000)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.rating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 10,
                                  color: AppColors.accentSecondary,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  s.rating!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: AppColors.accentSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 2),
                          Text(
                            s.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPrimary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SERIES',
                              style: TextStyle(
                                color: AppColors.accentPrimary,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Hover overlay
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _h ? 1.0 : 0.0,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                  if (_h)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: AppColors.accentPrimary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
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

  Widget _seriesPlaceholder() => Container(
    color: AppColors.surface,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.video_collection_rounded,
          color: AppColors.textDisabled,
          size: 36,
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            widget.series.name,
            style: AppTypography.captionSmall.copyWith(
              color: AppColors.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

// —— Shared components ——————————————————————————————————————————————

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
          borderRadius: AppRadius.smBorder,
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
