import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/protocol/payloads.dart';
import '../../../core/services/episode_nav_service.dart';
import '../../../core/services/fullscreen_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../iptv/repository/iptv_repository.dart';
import '../../player/bloc/player_bloc.dart';
import '../../player/bloc/player_event.dart';
import '../../player/bloc/player_state.dart';
import '../models/player_ui_context.dart';
import '../models/video_fit_mode.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/player_state_overlay.dart';
import '../widgets/smart_playback_controls.dart';

/// Standalone playback screen — plays content without a room.
/// Uses PlayerBloc directly; no sync/room involvement.
class SoloPlayerScreen extends StatelessWidget {
  const SoloPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlayerBloc>(
      create: (_) => GetIt.I<PlayerBloc>(),
      child: const _SoloPlayerScreenContent(),
    );
  }
}

class _SoloPlayerScreenContent extends StatefulWidget {
  const _SoloPlayerScreenContent();

  @override
  State<_SoloPlayerScreenContent> createState() =>
      _SoloPlayerScreenContentState();
}

class _SoloPlayerScreenContentState extends State<_SoloPlayerScreenContent> {
  final AppLogger _logger = AppLogger('SoloPlayer');
  String? _title;
  String? _streamUrl;
  IptvDescriptorType _contentType = IptvDescriptorType.movie;
  final GlobalKey<SmartPlaybackControlsState> _controlsKey =
      GlobalKey<SmartPlaybackControlsState>();

  /// Current video fit/fill mode — presentation-only, no effect on playback.
  VideoFitMode _fitMode = VideoFitMode.contain;

  /// Whether the top bar overlay is currently visible.
  bool _topBarVisible = true;
  Timer? _topBarHideTimer;

  PlayerBloc? _playerBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logger.d(
      'SoloPlayerScreen.didChangeDependencies: _streamUrl=${AppLogger.sanitizeUrl(_streamUrl ?? '')}',
    );
    if (_streamUrl != null) return;
    _playerBloc = context.read<PlayerBloc>();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    _logger.d(
      'SoloPlayerScreen args: title=${args?["title"]} '
      'contentType=${args?["contentType"]} '
      'url=${AppLogger.sanitizeUrl(args?["url"] ?? "")}',
    );
    if (args != null) {
      _title = args['title'];
      _streamUrl = args['url'];
      final ctName = args['contentType'];
      if (ctName != null) {
        _contentType = IptvDescriptorType.values.firstWhere(
          (e) => e.name == ctName,
          orElse: () => IptvDescriptorType.movie,
        );
      }
      if (_streamUrl != null && _streamUrl!.isNotEmpty) {
        _logger.i('Solo playback start: $_title');
        _logger.d('Dispatching PlayerEventInitialize');
        _playerBloc!.add(PlayerEventInitialize(_streamUrl!, source: 'solo'));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    FullscreenService().addListener(_onFullscreenChanged);
  }

  @override
  void dispose() {
    FullscreenService().removeListener(_onFullscreenChanged);
    _topBarHideTimer?.cancel();
    FullscreenService().exitFullscreen();
    _playerBloc?.add(const PlayerEventDispose());
    super.dispose();
  }

  void _onFullscreenChanged() {
    if (!mounted) return;
    if (FullscreenService().isFullscreen) {
      setState(() => _topBarVisible = true);
      _scheduleTopBarHide();
    } else {
      _topBarHideTimer?.cancel();
      setState(() => _topBarVisible = true);
    }
  }

  void _showOverlays() {
    if (!_topBarVisible) setState(() => _topBarVisible = true);
    _controlsKey.currentState?.showControls();
    _scheduleTopBarHide();
  }

  void _scheduleTopBarHide() {
    _topBarHideTimer?.cancel();
    if (FullscreenService().isFullscreen) {
      _topBarHideTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _topBarVisible = false);
      });
    }
  }

  PlayerUIContext get _uiContext {
    final navCtx = EpisodeNavService().current;
    final hasNext = _contentType == IptvDescriptorType.episode &&
        navCtx != null &&
        navCtx.hasNext;
    return PlayerUIContext.solo(
      contentType: _contentType,
      title: _title ?? 'Now Playing',
      hasNextEpisode: hasNext,
    );
  }

  /// Advance to the next episode in the same series.
  /// Called when the user taps the Next Episode button (solo mode only).
  void _handleNextEpisode() {
    final navCtx = EpisodeNavService().current;
    final next = navCtx?.nextEpisode;
    if (next == null || !mounted) return;

    final url = GetIt.instance<IptvRepository>().getEpisodePlaybackUrl(
      next.id,
      next.containerExtension,
    );

    // Advance the service first so the rebuilt _uiContext reflects the new
    // episode's hasNext status immediately after setState.
    EpisodeNavService().advanceTo(next.id);

    setState(() {
      _streamUrl = url;
      _title = next.displayTitle;
    });
    _playerBloc?.add(PlayerEventInitialize(url, source: 'next_episode'));
  }

  @override
  Widget build(BuildContext context) {
    final uiContext = _uiContext;
    return Scaffold(
      backgroundColor: AppColors.playerBackground,
      body: ListenableBuilder(
        listenable: FullscreenService(),
        builder: (context, _) {
          final isFullscreen = FullscreenService().isFullscreen;
          final playerBody = _buildPlayerStack(
            context,
            uiContext,
            isFullscreen,
          );
          // Removing top-level SafeArea allows the video surface to stretch edge-to-edge.
          // Overlay controls maintain their own SafeArea padding.
          return playerBody;
        },
      ),
    );
  }

  /// Stack-based player layout: video is the base layer, controls and top bar
  /// are positioned overlays. Hiding overlays never reduces the video area.
  Widget _buildPlayerStack(
    BuildContext context,
    PlayerUIContext uiContext,
    bool isFullscreen,
  ) {
    return MouseRegion(
      onHover: (_) => _showOverlays(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showOverlays,
        child: BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            PlayerOverlayType? overlayType;
            String? errorMessage;
            if (state is PlayerStateLoading) {
              overlayType = PlayerOverlayType.loading;
            } else if (state is PlayerStateBuffering) {
              overlayType = PlayerOverlayType.buffering;
            } else if (state is PlayerStateError) {
              overlayType = PlayerOverlayType.error;
              errorMessage = state.message;
            } else if (state is PlayerStateEnded) {
              overlayType = PlayerOverlayType.ended;
            } else if (state is PlayerStateIdle && _streamUrl == null) {
              overlayType = PlayerOverlayType.idle;
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Video surface — always fills full area ──────────────────
                _buildVideoView(_fitMode.boxFit),
                // ── State overlays (loading / buffering / error / ended) ──
                if (overlayType != null)
                  PlayerStateOverlay(
                    type: overlayType,
                    uiContext: uiContext,
                    errorMessage: errorMessage,
                    onRetry: _streamUrl != null
                        ? () => context.read<PlayerBloc>().add(
                              PlayerEventInitialize(_streamUrl!,
                                  source: 'retry'),
                            )
                        : null,
                    onBack: () => Navigator.pop(context),
                  ),
                // ── Top bar overlay — fades out in fullscreen after idle ────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: (!isFullscreen || _topBarVisible) ? 1.0 : 0.0,
                    duration: AppAnimation.normal,
                    child: IgnorePointer(
                      ignoring: isFullscreen && !_topBarVisible,
                      child: SafeArea(
                        bottom: false,
                        child: PlayerTopBar(
                          uiContext: uiContext,
                          onBack: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Bottom controls overlay — SmartPlaybackControls manages its own visibility ─
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: _buildSmartControls(context, state, uiContext),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSmartControls(
    BuildContext context,
    PlayerState state,
    PlayerUIContext uiContext,
  ) {
    final isPlaying = state is PlayerStatePlaying;
    final isPaused = state is PlayerStatePaused;
    return SmartPlaybackControls(
      key: _controlsKey,
      uiContext: uiContext,
      isPlaying: isPlaying,
      isPaused: isPaused,
      canInteract: isPlaying || isPaused || state is PlayerStateReady,
      fitMode: _fitMode,
      onFitModeChanged: (mode) => setState(() => _fitMode = mode),
      onPlay: (_) => context.read<PlayerBloc>().add(const PlayerEventPlay()),
      onPause: (_) => context.read<PlayerBloc>().add(const PlayerEventPause()),
      onSeek: (target) =>
          context.read<PlayerBloc>().add(PlayerEventSeek(target)),
      onNextEpisode: _handleNextEpisode,
    );
  }

  Widget _buildVideoView(BoxFit fit) {
    final playerController = GetIt.instance<PlayerController>();
    final videoWidget = playerController.buildVideoView(fit: fit);
    if (videoWidget != null && playerController.isInitialized) {
      return Container(color: AppColors.playerBackground, child: videoWidget);
    }
    return Container(color: AppColors.playerBackground);
  }
}
