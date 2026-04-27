import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/protocol/payloads.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';
import '../../room/bloc/room_bloc.dart';
import '../../room/bloc/room_event.dart';
import '../bloc/iptv_bloc.dart';
import '../bloc/iptv_event.dart';
import '../bloc/iptv_state.dart';
import '../models/series_item.dart';
import '../repository/iptv_repository.dart';
import '../service/iptv_navigation_memory.dart';
import '../../../core/services/episode_nav_service.dart';

class IptvSeriesDetailScreen extends StatefulWidget {
  final int seriesId;
  final String seriesName;
  final String mode;

  const IptvSeriesDetailScreen({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.mode = 'solo',
  });

  @override
  State<IptvSeriesDetailScreen> createState() => _IptvSeriesDetailScreenState();
}

class _IptvSeriesDetailScreenState extends State<IptvSeriesDetailScreen> {
  String? _selectedSeason;

  @override
  void initState() {
    super.initState();
    context.read<IptvBloc>().add(
          IptvLoadSeriesInfo(
            seriesId: widget.seriesId,
            seriesName: widget.seriesName,
          ),
        );
  }

  void _handleSelection({
    required IptvContentDescriptor descriptor,
    required String title,
    required SeriesInfo info,
  }) {
    final allEpisodes = <EpisodeRef>[];
    for (final s in info.seasonNumbers) {
      final eps = info.seasons[s] ?? [];
      for (final ep in eps) {
        allEpisodes.add(
          EpisodeRef(
            id: ep.id,
            containerExtension: ep.containerExtension,
            seriesId: widget.seriesId,
            seriesName: widget.seriesName,
            seasonNum: s,
            episodeNum: ep.episodeNum,
            episodeTitle: ep.title,
          ),
        );
      }
    }

    EpisodeNavService().setContext(
      EpisodeNavContext(
        allEpisodes: allEpisodes,
        currentEpisodeId: descriptor.streamId,
      ),
    );

    if (widget.mode == 'solo') {
      final url = GetIt.instance<IptvRepository>().resolvePlaybackUrl(
        descriptor,
      );
      Navigator.of(context, rootNavigator: true).pushNamed(
        '/solo-player',
        arguments: {
          'url': url,
          'title': title,
          'contentType': descriptor.contentType.name,
        },
      );
    } else {
      GetIt.I<IptvNavigationMemory>().isSelectionPop = true;
      context.read<RoomBloc>().add(RoomEventSetContent(descriptor));
      Navigator.of(context).popUntil(ModalRoute.withName('/watch'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final isDesktop = sw > AppBreakpoint.desktop;
    final isTablet = sw > AppBreakpoint.tablet;
    final hPad = isDesktop
        ? sw * 0.15
        : isTablet
            ? AppSpacing.xxl
            : AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocBuilder<IptvBloc, IptvState>(
        builder: (context, state) {
          if (state is IptvLoading) {
            return const LoadingState(message: 'Loading Series Details...');
          }
          if (state is IptvError) {
            return ErrorState(
              message: state.message,
              onRetry: () => context.read<IptvBloc>().add(
                    IptvLoadSeriesInfo(
                      seriesId: widget.seriesId,
                      seriesName: widget.seriesName,
                    ),
                  ),
            );
          }
          if (state is IptvSeriesInfoLoaded) {
            return _buildContent(state.info, hPad, isDesktop, isTablet);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(
    SeriesInfo info,
    double hPad,
    bool isDesktop,
    bool isTablet,
  ) {
    final seasons = info.seasonNumbers;
    _selectedSeason ??= seasons.isNotEmpty ? seasons.first : null;
    final episodes = _selectedSeason != null
        ? (info.seasons[_selectedSeason] ?? [])
        : <SeriesEpisode>[];

    return CustomScrollView(
      slivers: [
        _buildHero(info),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                _buildMetadata(info),
                if (info.plot != null && info.plot!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    info.plot!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
                if (seasons.isNotEmpty) _buildSeasonSelector(seasons),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        if (episodes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Center(
                child: Text(
                  'No episodes available for this season.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: hPad,
            ).copyWith(bottom: AppSpacing.huge),
            sliver: isDesktop || isTablet
                ? SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisExtent: 140,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _EpisodeCard(
                        episode: episodes[index],
                        seriesName: info.name,
                        onTap: () => _handleSelection(
                          descriptor: IptvContentDescriptor(
                            contentType: IptvDescriptorType.episode,
                            streamId: episodes[index].id,
                            containerExtension:
                                episodes[index].containerExtension,
                            title:
                                '${info.name} - S$_selectedSeason E${episodes[index].episodeNum}',
                          ),
                          title:
                              '${info.name} - S$_selectedSeason E${episodes[index].episodeNum}',
                          info: info,
                        ),
                      ),
                      childCount: episodes.length,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _EpisodeCard(
                          episode: episodes[index],
                          seriesName: info.name,
                          onTap: () => _handleSelection(
                            descriptor: IptvContentDescriptor(
                              contentType: IptvDescriptorType.episode,
                              streamId: episodes[index].id,
                              containerExtension:
                                  episodes[index].containerExtension,
                              title:
                                  '${info.name} - S$_selectedSeason E${episodes[index].episodeNum}',
                            ),
                            title:
                                '${info.name} - S$_selectedSeason E${episodes[index].episodeNum}',
                            info: info,
                          ),
                        ),
                      ),
                      childCount: episodes.length,
                    ),
                  ),
          ),
      ],
    );
  }

  Widget _buildHero(SeriesInfo info) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.textPrimary,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        info.name,
        style: AppTypography.display.copyWith(
          fontSize: 32,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.borderSubtle, height: 1),
      ),
    );
  }

  Widget _buildMetadata(SeriesInfo info) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        if (info.rating != null && info.rating! > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                info.rating!.toStringAsFixed(1),
                style: AppTypography.captionSmall.copyWith(color: Colors.amber),
              ),
            ],
          ),
        if (info.genre != null && info.genre!.isNotEmpty)
          _MetaChip(label: info.genre!),
        if (info.cast != null && info.cast!.isNotEmpty)
          Text(
            'Cast: ${info.cast!}',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildSeasonSelector(List<String> seasons) {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: seasons.length,
        itemBuilder: (context, index) {
          final s = seasons[index];
          final isSelected = s == _selectedSeason;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSeason = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentPrimary.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPrimary.withValues(alpha: 0.5)
                        : AppColors.borderSubtle,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  'S$s',
                  style: AppTypography.mono.copyWith(
                    fontSize: 11,
                    color: isSelected
                        ? AppColors.accentPrimaryHover
                        : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Text(
          label,
          style: AppTypography.captionSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _EpisodeCard extends StatefulWidget {
  final SeriesEpisode episode;
  final String seriesName;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.seriesName,
    required this.onTap,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 140,
          decoration: BoxDecoration(
            color: _h ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _h
                  ? AppColors.accentPrimary.withValues(alpha: 0.5)
                  : AppColors.borderSubtle,
            ),
            boxShadow: _h
                ? [
                    BoxShadow(
                      color: AppColors.accentPrimary.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(AppRadius.lg - 1),
                      ),
                      child: ep.coverBig != null && ep.coverBig!.isNotEmpty
                          ? Image.network(
                              ep.coverBig!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.backgroundSecondary,
                              ),
                            )
                          : Container(color: AppColors.backgroundSecondary),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(AppRadius.lg - 1),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black54,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        ep.episodeNum.toString(),
                        style: AppTypography.display.copyWith(
                          fontSize: 42,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (_h)
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.horizontal(
                            left: Radius.circular(AppRadius.lg - 1),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.accentPrimary,
                            size: 44,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ep.title,
                              style: AppTypography.titleSmall.copyWith(
                                color: _h
                                    ? AppColors.accentPrimaryHover
                                    : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ep.duration != null &&
                              ep.duration!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              ep.duration!,
                              style: AppTypography.captionSmall.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'EP ${ep.episodeNum}',
                          style: AppTypography.mono.copyWith(
                            fontSize: 9,
                            color: AppColors.accentPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      if (ep.plot != null && ep.plot!.isNotEmpty)
                        Expanded(
                          child: Text(
                            ep.plot!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
