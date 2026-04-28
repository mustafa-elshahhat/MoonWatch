import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import 'package:get_it/get_it.dart';
import '../../../core/player/player_controller.dart';
import '../../../core/protocol/payloads.dart';
import '../../../core/services/fullscreen_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_components.dart';
import '../../room/bloc/room_bloc.dart';
import '../../room/bloc/room_event.dart';
import '../../room/bloc/room_state.dart';
import '../../room/domain/peer_status.dart';
import '../../room/repository/room_repository.dart';
import '../../sync/sync_engine.dart';
import '../../sync/latency_estimator.dart';
import '../../reconnect/reconnect_bloc.dart';
import '../../../core/services/episode_nav_service.dart';
import '../../iptv/bloc/iptv_state.dart';
import '../../iptv/repository/iptv_repository.dart';
import '../../iptv/service/iptv_navigation_memory.dart';
import '../bloc/player_bloc.dart';
import '../bloc/player_event.dart';
import '../bloc/player_state.dart';
import '../models/player_ui_context.dart';
import '../models/video_fit_mode.dart';
import '../widgets/player_top_bar.dart';
import '../widgets/player_gesture_layer.dart';
import '../widgets/smart_playback_controls.dart';

class WatchScreen extends StatelessWidget {
  const WatchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PlayerBloc>(create: (_) => GetIt.I<PlayerBloc>()),
        BlocProvider<SyncBloc>(create: (_) => GetIt.I<SyncBloc>()),
      ],
      child: const WatchScreenContent(),
    );
  }
}

class WatchScreenContent extends StatefulWidget {
  const WatchScreenContent({super.key});

  @override
  State<WatchScreenContent> createState() => WatchScreenContentState();
}

class WatchScreenContentState extends State<WatchScreenContent> {
  static final AppLogger _logger = AppLogger('WatchScreen');

  String? _lastContentKey;

  bool _roomWired = false;
  bool _isRoomClosed = false;

  late final PlayerBloc _playerBloc;
  late final PlayerController _playerController;
  late final RoomRepository _roomRepository;
  late final LatencyEstimator _latencyEstimator;
  late final IptvRepository _iptvRepository;
  final GlobalKey<SmartPlaybackControlsState> _controlsKey =
      GlobalKey<SmartPlaybackControlsState>();

  VideoFitMode _fitMode = VideoFitMode.contain;
  double _brightness = 1.0;

  bool _topBarVisible = true;
  Timer? _topBarHideTimer;

  @override
  void initState() {
    super.initState();

    _playerController = GetIt.instance<PlayerController>();
    _roomRepository = GetIt.instance<RoomRepository>();
    _latencyEstimator = GetIt.instance<LatencyEstimator>();
    _iptvRepository = GetIt.instance<IptvRepository>();

    _playerBloc = context.read<PlayerBloc>();
    _playerBloc.setRoomMode(true);

    FullscreenService().addListener(_onFullscreenChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final roomState = context.read<RoomBloc>().state;
      if (roomState is RoomStateActive) {
        _handleNewContent(roomState);
      }
    });
  }

  @override
  void dispose() {
    FullscreenService().removeListener(_onFullscreenChanged);
    _topBarHideTimer?.cancel();

    FullscreenService().exitFullscreen();

    _playerBloc.setRoomMode(false);

    _latencyEstimator.stop();
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

  static String? _roleOf(RoomState s) => switch (s) {
        RoomStateWaiting(role: final r) => r,
        RoomStateJoined(role: final r) => r,
        RoomStateActive(role: final r) => r,
        _ => null,
      };

  static String? _roomCodeOf(RoomState s) => switch (s) {
        RoomStateWaiting(roomCode: final c) => c,
        RoomStateJoined(roomCode: final c) => c,
        RoomStateActive(roomCode: final c) => c,
        _ => null,
      };

  static String _contentKeyOf(IptvContentDescriptor descriptor) =>
      descriptor.contentKey;

  String? _activeContentKey(BuildContext context) {
    final roomState = context.read<RoomBloc>().state;
    if (roomState is! RoomStateActive) {
      return null;
    }
    return roomState.contentKey;
  }

  void invokePlay(Duration position) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _logger.i('host.play: positionMs=${position.inMilliseconds}');

    _playerController.play();

    _roomRepository.invokePlay(position.inMilliseconds, now);
  }

  void invokePauseAction(Duration position) {
    _logger.i('host.pause: positionMs=${position.inMilliseconds}');
    _playerController.pause();
    _roomRepository.invokePause(position.inMilliseconds);
  }

  void invokeSeekAction(Duration targetPosition) {
    _logger.d('host.seek: targetMs=${targetPosition.inMilliseconds}');
    _playerController.seekTo(targetPosition);
    _roomRepository.invokeSeek(targetPosition.inMilliseconds);
  }

  void invokeSpeedAction(double speed) {
    _logger.i('host.setPlaybackSpeed: speed=$speed');
    _playerController.setPlaybackSpeed(speed);
    _roomRepository.invokeSetPlaybackSpeed(speed);
  }

  void invokeNextEpisode() {
    final navCtx = EpisodeNavService().current;
    final next = navCtx?.nextEpisode;
    if (next == null || !mounted) return;
    EpisodeNavService().advanceTo(next.id);
    context.read<RoomBloc>().add(RoomEventSetContent(next.toDescriptor()));
  }

  void _handleNewContent(RoomStateActive state) {
    final contentKey = _contentKeyOf(state.contentDescriptor);

    if (contentKey == _lastContentKey) {
      _logger.i('[CONTENT_SET_DUPLICATE_IGNORED] key=$contentKey');
      return;
    }
    _lastContentKey = contentKey;

    final localUrl = _iptvRepository.resolvePlaybackUrl(
      state.contentDescriptor,
    );

    _logger.i('[PLAYER_INIT_SOURCE] source=room_active, key=$contentKey');

    if (!_roomWired) {
      _roomWired = true;
      _latencyEstimator.onRttUpdated = (rttMs) {
        context.read<SyncBloc>().updateGuestRtt(rttMs);
      };
      _latencyEstimator.onClockOffsetUpdated = (offsetMs) {
        context.read<SyncBloc>().updateClockOffset(offsetMs);
      };
      _latencyEstimator.start();

      final reconnectBloc = context.read<ReconnectBloc>();
      reconnectBloc.storeRoomCredentials(state.roomCode, state.role);
      reconnectBloc.startListening();
    }

    context.read<SyncBloc>().setRole(state.role);
    context.read<SyncBloc>().add(
          SyncEventSpeedReceived(
            speed: state.playbackRate,
            serverTimestampMs: 0,
          ),
        );

    context.read<PlayerBloc>().add(
          PlayerEventInitialize(
            localUrl,
            source: 'room_active',
            isRoomMode: true,
            role: state.role,
            roomCode: state.roomCode,
            contentKey: contentKey,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<RoomBloc, RoomState>(
          listenWhen: (previous, current) {
            if (current is RoomStateClosed) return true;

            if (current is! RoomStateActive) return false;

            if (previous is! RoomStateActive) return true;

            return previous.contentDescriptor != current.contentDescriptor;
          },
          listener: (context, state) {
            if (state is RoomStateClosed) {
              context.read<PlayerBloc>().add(const PlayerEventDispose());

              context.read<ReconnectBloc>().add(const ReconnectEventReset());
              GetIt.I<IptvNavigationMemory>().clear();

              _latencyEstimator.stop();
              setState(() {
                _isRoomClosed = true;
                _roomWired = false;
                _lastContentKey = null;
              });
              _showCloseMessageThenNavigate(context, state.reason);
            } else if (state is RoomStateActive) {
              _handleNewContent(state);
            }
          },
        ),
        BlocListener<PlayerBloc, PlayerState>(
          listener: (context, playerState) {
            if (playerState is PlayerStateIdle ||
                playerState is PlayerStateLoading ||
                playerState is PlayerStateError) {
              context.read<SyncBloc>().setPlayerReady(
                    false,
                    contentKey: _activeContentKey(context),
                  );

              if (playerState is PlayerStateError) {
                _lastContentKey = null;
              }
            }

            if (playerState is PlayerStateReady) {
              context.read<SyncBloc>().setPlayerReady(
                    true,
                    contentKey: _activeContentKey(context),
                  );
            }

            if (playerState is PlayerStateBuffering) {
              context.read<SyncBloc>().add(const SyncEventPlayerStalled());
            } else if (playerState is PlayerStatePlaying ||
                playerState is PlayerStatePaused) {
              context.read<SyncBloc>().add(const SyncEventPlayerReady());
            }
          },
        ),
      ],
      child: PopScope(
        canPop: _isRoomClosed,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_isRoomClosed) {
            _confirmLeave(context);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.playerBackground,
          body: ListenableBuilder(
            listenable: FullscreenService(),
            builder: (context, _) {
              final isFullscreen = FullscreenService().isFullscreen;
              final playerBody = BlocBuilder<RoomBloc, RoomState>(
                builder: (context, roomState) {
                  final role = _roleOf(roomState);
                  final roomCode = _roomCodeOf(roomState);
                  final descriptor = roomState is RoomStateActive
                      ? roomState.contentDescriptor
                      : null;
                  final peerStatus = roomState is RoomStateActive
                      ? roomState.peerStatus
                      : null;

                  final navCtx = EpisodeNavService().current;
                  final hasNext =
                      descriptor?.contentType == IptvDescriptorType.episode &&
                          navCtx != null &&
                          navCtx.hasNext;
                  final uiContext = descriptor != null && role != null
                      ? PlayerUIContext.fromRoom(
                          role: role,
                          descriptor: descriptor,
                          hasNextEpisode: hasNext,
                        )
                      : (role == 'host'
                          ? PlayerUIContext.roomHost(
                              contentType: IptvDescriptorType.movie,
                              title: 'WatchParty',
                            )
                          : PlayerUIContext.roomGuest(
                              contentType: IptvDescriptorType.movie,
                              title: 'WatchParty',
                            ));

                  return _buildPlayerStack(
                    context,
                    uiContext,
                    roomCode,
                    peerStatus,
                    isFullscreen,
                  );
                },
              );

              return playerBody;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerStack(
    BuildContext context,
    PlayerUIContext uiContext,
    String? roomCode,
    PeerStatus? peerStatus,
    bool isFullscreen,
  ) {
    return MouseRegion(
      onHover: (_) => _showOverlays(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          BlocBuilder<PlayerBloc, PlayerState>(
            builder: (context, _) => _buildVideoView(_fitMode.boxFit),
          ),
          PlayerGestureLayer(
            uiContext: uiContext,
            fitMode: _fitMode,
            onFitModeChanged: (m) => setState(() => _fitMode = m),
            onShowOverlays: _showOverlays,
            brightness: _brightness,
            onBrightnessChanged: (v) => setState(() => _brightness = v),
            onSeek: uiContext.canControlPlayback
                ? (target) => invokeSeekAction(target)
                : null,
          ),
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 50),
              color: Colors.black.withValues(
                alpha: (1.0 - _brightness).clamp(0.0, 1.0),
              ),
            ),
          ),
            BlocBuilder<RoomBloc, RoomState>(
              builder: (context, roomState) =>
                  BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, playerState) =>
                    _buildStateOverlay(playerState, roomState),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: (!isFullscreen || _topBarVisible) ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: isFullscreen && !_topBarVisible,
                  child: PlayerTopBar(
                    uiContext: uiContext,
                    roomCode: roomCode,
                    peerStatus: peerStatus,
                    onBack: () => _confirmLeave(context),
                    onBrowseContent: uiContext.canChangeContent
                        ? () => _browseContentInRoom(context)
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: BlocBuilder<PlayerBloc, PlayerState>(
                builder: (context, playerState) =>
                    _buildSmartControls(context, playerState, uiContext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateOverlay(PlayerState playerState, [RoomState? roomState]) {
    final isWaitingForPeer = roomState is RoomStateActive &&
        !roomState.bothReady &&
        playerState is PlayerStateReady;

    if (playerState is PlayerStateLoading || isWaitingForPeer) {
      return Container(
        color: AppColors.playerBackground,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: AppColors.accentPrimary,
                  strokeWidth: 2.5,
                ),
              ),
              if (isWaitingForPeer) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Waiting for peer to be ready...',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (playerState is PlayerStateError) {
      return Container(
        color: AppColors.playerBackground,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.errorSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: AppIconSize.xl,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  playerState.message,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                TextButton.icon(
                  onPressed: () {
                    final roomState = context.read<RoomBloc>().state;
                    if (roomState is RoomStateActive) {
                      final localUrl = _iptvRepository.resolvePlaybackUrl(
                        roomState.contentDescriptor,
                      );

                      _lastContentKey = null;
                      context.read<PlayerBloc>().clearDedupState();
                      context.read<PlayerBloc>().add(
                            PlayerEventInitialize(
                              localUrl,
                              source: 'retry',
                              isRoomMode: true,
                              role: roomState.role,
                              roomCode: roomState.roomCode,
                              contentKey: _contentKeyOf(
                                roomState.contentDescriptor,
                              ),
                            ),
                          );
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSmartControls(
    BuildContext context,
    PlayerState playerState,
    PlayerUIContext uiContext,
  ) {
    final roomState = context.read<RoomBloc>().state;
    final isWaitingForPeer = uiContext.isRoomMode &&
        roomState is RoomStateActive &&
        !roomState.bothReady;

    final isPlaying = playerState is PlayerStatePlaying;
    final isPaused =
        playerState is PlayerStatePaused || playerState is PlayerStateReady;

    final canInteract = (isPlaying || isPaused) && !isWaitingForPeer;

    return SmartPlaybackControls(
      key: _controlsKey,
      uiContext: uiContext,
      isPlaying: isPlaying,
      isPaused: isPaused,
      canInteract: canInteract,
      fitMode: _fitMode,
      onFitModeChanged: (mode) => setState(() => _fitMode = mode),
      brightness: _brightness,
      onBrightnessChanged: (v) => setState(() => _brightness = v),
      onPlay: (_) => invokePlay(_playerController.currentPosition),
      onPause: (_) => invokePauseAction(_playerController.currentPosition),
      onSeek: (pos) => invokeSeekAction(pos),
      onSpeedChanged: invokeSpeedAction,
      onNextEpisode: invokeNextEpisode,
    );
  }

  Widget _buildVideoView(BoxFit fit) {
    final videoWidget = _playerController.buildVideoView(fit: fit);
    if (videoWidget != null && _playerController.isInitialized) {
      return Container(color: AppColors.playerBackground, child: videoWidget);
    }
    return Container(color: AppColors.playerBackground);
  }

  Future<void> _browseContentInRoom(BuildContext context) async {
    _logger.i('Host opening in-room content browser');
    final result = await Navigator.pushNamed(
      context,
      '/iptv',
      arguments: 'room',
    );
    if (result is IptvContentSelected && context.mounted) {
      _logger.i('In-room content selected (fallback path): ${result.title}');
      context.read<RoomBloc>().add(RoomEventSetContent(result.descriptor));
    }
  }

  void _confirmLeave(BuildContext context) {
    if (_isRoomClosed) return;

    final roomState = context.read<RoomBloc>().state;
    final role = _roleOf(roomState);
    final isHost = role == 'host';

    final message = isHost
        ? 'Leaving will end the room for everyone.'
        : 'You will leave this session and can join again later.';

    AppConfirmDialog.show(
      context,
      title: 'Leave Room?',
      message: message,
      confirmLabel: 'Leave',
      cancelLabel: 'Stay',
      confirmColor: AppColors.error,
      icon: Icons.exit_to_app_rounded,
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        context.read<RoomBloc>().add(const RoomEventLeaveRoom());
      }
    });
  }

  void _showCloseMessageThenNavigate(BuildContext context, String reason) {
    if (!mounted) return;
    final message = _closeReasonMessage(reason);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }

  String _closeReasonMessage(String reason) => switch (reason) {
        'host_disconnected' =>
          'Your host has disconnected. The session has ended.',
        'host_left' => 'The host has left the room.',
        'room_expired' => 'This room has expired due to inactivity.',
        'user_left' => 'You have left the room.',
        _ => 'The session has ended.',
      };
}
