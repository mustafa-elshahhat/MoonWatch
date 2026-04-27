import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/state_views.dart';
import '../bloc/iptv_bloc.dart';
import '../bloc/iptv_event.dart';
import '../bloc/iptv_state.dart';
import '../models/iptv_category.dart';
import '../repository/iptv_repository.dart';
import '../../../shared/widgets/app_components.dart';
import 'iptv_category_content_screen.dart';
import 'iptv_series_detail_screen.dart';
import '../../navigation/screens/main_shell.dart';
import '../service/iptv_navigation_memory.dart';

class IptvBrowseScreen extends StatefulWidget {
  const IptvBrowseScreen({super.key});

  @override
  State<IptvBrowseScreen> createState() => _IptvBrowseScreenState();
}

class _IptvBrowseScreenState extends State<IptvBrowseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    IptvContentType.live,
    IptvContentType.movie,
    IptvContentType.series,
  ];

  String _mode = 'solo';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late final IptvBloc _iptvBloc;

  @override
  void initState() {
    super.initState();
    _iptvBloc = context.read<IptvBloc>();

    final memory = GetIt.I<IptvNavigationMemory>();
    memory.isSelectionPop = false;
    final initialTab = memory.activeTab ?? IptvContentType.live;
    final initialIndex = _tabs.indexOf(initialTab);

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex != -1 ? initialIndex : 0,
    );
    _tabController.addListener(_onTabChanged);
    _iptvBloc.add(IptvLoadCategories(_tabs[_tabController.index]));

    if (memory.activeCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _restoreDeepLink(memory);
      });
    }
  }

  void _restoreDeepLink(IptvNavigationMemory memory) {
    final cat = memory.activeCategory;
    if (cat == null) return;

    Navigator.of(context)
        .push(
      PageRouteBuilder(
        pageBuilder: (context, _, __) => BlocProvider(
          create: (_) => IptvBloc(repository: GetIt.instance<IptvRepository>()),
          child: IptvCategoryContentScreen(
            contentType: memory.activeTab ?? IptvContentType.live,
            categoryId: cat.categoryId,
            categoryName: cat.categoryName,
            mode: _mode,
          ),
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    )
        .then((result) {
      if (result is IptvContentSelected) {
        GetIt.I<IptvNavigationMemory>().isSelectionPop = true;
        
        
        if (mounted) Navigator.of(context).pop(result);
        return;
      }
      GetIt.I<IptvNavigationMemory>().clearCategory();
    });

    if (memory.activeSeriesId != null && memory.activeSeriesName != null) {
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (context, _, __) => BlocProvider(
            create: (_) =>
                IptvBloc(repository: GetIt.instance<IptvRepository>()),
            child: IptvSeriesDetailScreen(
              seriesId: int.tryParse(memory.activeSeriesId!) ?? 0,
              seriesName: memory.activeSeriesName!,
              mode: _mode,
            ),
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      )
          .then((result) {
        if (result is IptvContentSelected) {
          GetIt.I<IptvNavigationMemory>().isSelectionPop = true;
          
          
          if (mounted) Navigator.of(context).pop(result);
          return;
        }
        GetIt.I<IptvNavigationMemory>().clearSeries();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is String) _mode = arg;
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _searchController.clear();
      setState(() => _searchQuery = '');
      GetIt.I<IptvNavigationMemory>().saveTab(_tabs[_tabController.index]);
      _iptvBloc.add(IptvLoadCategories(_tabs[_tabController.index]));
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    final shell = context.findAncestorStateOfType<MainShellState>();
    if (shell != null) {
      shell.switchToHome();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(),
            _buildFlagshipSearchBar(isDesktop),
            _buildPremiumSegmentedTabs(),
            Expanded(child: _buildStatefulContent(isDesktop)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.lg,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_mode == 'solo') ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                color: AppColors.textPrimary,
                onPressed: _handleBack,
                tooltip: 'Back to Home',
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow(_mode == 'room' ? 'Room Library' : 'Library'),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: _mode == 'room' ? 'Select Content' : 'Browse',
                    style: AppTypography.display.copyWith(
                      fontSize: 46,
                      letterSpacing: -1.4,
                      height: 1.0,
                    ),
                    children: const [
                      TextSpan(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagshipSearchBar(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal:
            isDesktop ? MediaQuery.of(context).size.width * 0.1 : AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
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
        child: TextField(
          controller: _searchController,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
          cursorColor: AppColors.accentPrimaryHover,
          decoration: InputDecoration(
            hintText: 'Search categories, channels, or series...',
            hintStyle: AppTypography.bodyLarge.copyWith(
              color: AppColors.textMuted,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Icon(
                Icons.search_rounded,
                color: AppColors.accentPrimary,
                size: 28,
              ),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 60),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 22,
              horizontal: AppSpacing.xl,
            ),
          ),
          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
        ),
      ),
    );
  }

  Widget _buildPremiumSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xxl,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppColors.accentPrimary.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.accentPrimaryHover,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w500,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.live_tv_rounded, size: 13),
                    SizedBox(width: 6),
                    Text('Live'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.movie_creation_rounded, size: 13),
                    SizedBox(width: 6),
                    Text('Films'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_rounded, size: 13),
                    SizedBox(width: 6),
                    Text('Series'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatefulContent(bool isDesktop) {
    return BlocBuilder<IptvBloc, IptvState>(
      buildWhen: (_, current) =>
          current is IptvInitial ||
          current is IptvLoading ||
          current is IptvError ||
          current is IptvCategoriesLoaded,
      builder: (context, state) {
        if (state is IptvLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentPrimary),
          );
        }
        if (state is IptvError) {
          return Center(
            child: ErrorState(
              message: state.message,
              onRetry: () => _iptvBloc.add(
                IptvLoadCategories(_tabs[_tabController.index]),
              ),
            ),
          );
        }
        if (state is IptvCategoriesLoaded) {
          return _buildCategoryGrid(
            state.contentType,
            state.categories,
            isDesktop,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCategoryGrid(
    IptvContentType contentType,
    List<IptvCategory> categories,
    bool isDesktop,
  ) {
    final allCategories = [
      const IptvCategory(categoryId: '0', categoryName: 'All Content'),
      ...categories,
    ];

    final displayed = allCategories
        .where((c) => c.categoryName.toLowerCase().contains(_searchQuery))
        .toList();

    if (displayed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No categories found',
              style: AppTypography.title.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
          ],
        ),
      );
    }

    final sw = MediaQuery.of(context).size.width;
    final crossAxisCount = sw > 1200
        ? 5
        : sw > 800
            ? 4
            : sw > 600
                ? 3
                : 2;

    return GridView.builder(
      key: PageStorageKey<IptvContentType>(contentType),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? sw * 0.05 : AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 1.55,
      ),
      itemCount: displayed.length,
      itemBuilder: (context, index) {
        final cat = displayed[index];
        return _PremiumCategoryCard(
          name: cat.categoryName,
          contentType: contentType,
          index: index,
          onTap: () async {
            final navigator = Navigator.of(context);
            GetIt.I<IptvNavigationMemory>().saveCategory(cat);
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (_) =>
                      IptvBloc(repository: GetIt.instance<IptvRepository>()),
                  child: IptvCategoryContentScreen(
                    contentType: contentType,
                    categoryId: cat.categoryId,
                    categoryName: cat.categoryName,
                    mode: _mode,
                  ),
                ),
              ),
            );
            if (result != null && mounted) {
              GetIt.I<IptvNavigationMemory>().isSelectionPop = true;
              navigator.pop(result);
            } else {
              GetIt.I<IptvNavigationMemory>().clearCategory();
            }
          },
        );
      },
    );
  }
}

class _PremiumCategoryCard extends StatefulWidget {
  final String name;
  final IptvContentType contentType;
  final int index;
  final VoidCallback onTap;

  const _PremiumCategoryCard({
    required this.name,
    required this.contentType,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PremiumCategoryCard> createState() => _PremiumCategoryCardState();
}

class _PremiumCategoryCardState extends State<_PremiumCategoryCard>
    with SingleTickerProviderStateMixin {
  bool _h = false;
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  
  static const _typeData = {
    IptvContentType.live: (
      icon: Icons.satellite_alt_rounded,
      color: AppColors.error,
    ),
    IptvContentType.movie: (
      icon: Icons.local_movies_rounded,
      color: AppColors.accentPrimary,
    ),
    IptvContentType.series: (
      icon: Icons.video_collection_rounded,
      color: AppColors.success,
    ),
  };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    Future.delayed(
      Duration(milliseconds: (widget.index * 28).clamp(0, 600)),
      () {
        if (mounted) _ctrl.forward();
      },
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final td = _typeData[widget.contentType]!;
    final accent = td.color;
    final icon = td.icon;
    final isAll = widget.name == 'All Content';

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: MouseRegion(
          onEnter: (_) => setState(() => _h = true),
          onExit: (_) => setState(() => _h = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutQuart,
              transform: Matrix4.translationValues(0.0, _h ? -4.0 : 0.0, 0.0),
              decoration: BoxDecoration(
                color: _h ? AppColors.surfaceElevated : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: _h
                      ? accent.withValues(alpha: 0.45)
                      : AppColors.borderSubtle,
                  width: _h ? 1.5 : 1,
                ),
                boxShadow: _h
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Stack(
                  children: [
                    
                    Positioned(
                      right: -18,
                      bottom: -18,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _h ? 0.13 : 0.05,
                        child: Icon(icon, size: 90, color: accent),
                      ),
                    ),
                    
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        height: _h ? 3 : 0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0),
                              accent,
                              accent.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: _h
                                  ? accent.withValues(alpha: 0.18)
                                  : accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: _h
                                    ? accent.withValues(alpha: 0.3)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              isAll ? Icons.grid_view_rounded : icon,
                              size: 20,
                              color: accent,
                            ),
                          ),
                          
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.name,
                                style: AppTypography.bodySmall.copyWith(
                                  color: _h
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_h) ...[
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Text(
                                      'Browse',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: accent,
                                      size: 10,
                                    ),
                                  ],
                                ),
                              ],
                            ],
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
      ),
    );
  }
}
