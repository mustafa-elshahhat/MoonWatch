import 'dart:async';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/http_client.dart';
import '../../../core/network/signalr_client.dart';
import '../../../core/protocol/room_events.dart';
import '../../../core/protocol/payloads.dart';
import '../bloc/room_event.dart';

/// Callback types for sync-related events handled outside RoomBloc.
typedef PlaybackEventCallback = void Function(Map<String, dynamic> json);
typedef BufferingStallCallback = void Function(
    BufferingStallBroadcastPayload payload);
typedef BufferingResumeCallback = void Function(BufferingResumePayload payload);
typedef PlaybackPlayCallback = void Function(PlaybackPlayPayload payload);
typedef PlaybackPauseCallback = void Function(PlaybackPausePayload payload);
typedef PlaybackSeekCallback = void Function(PlaybackSeekPayload payload);
typedef PlaybackStateSyncCallback = void Function(
    PlaybackStateSyncPayload payload);

/// Translates SignalRClient events into RoomBloc events and exposes
/// REST room-listing for the join screen.
class RoomRepository {
  final SignalRClient _signalRClient;
  final HttpClient _httpClient;
  final AppLogger _logger = AppLogger('RoomRepository');
  final _eventController = StreamController<RoomEvent>.broadcast();

  /// Callback for buffering:stall events from peer.
  BufferingStallCallback? onBufferingStall;

  /// Callback for buffering:resume events.
  BufferingResumeCallback? onBufferingResume;

  /// Callbacks for playback sync events.
  PlaybackPlayCallback? onPlaybackPlay;
  PlaybackPauseCallback? onPlaybackPause;
  PlaybackSeekCallback? onPlaybackSeek;
  PlaybackStateSyncCallback? onPlaybackStateSync;

  Stream<RoomEvent> get events => _eventController.stream;

  RoomRepository({
    required SignalRClient signalRClient,
    required HttpClient httpClient,
  })  : _signalRClient = signalRClient,
        _httpClient = httpClient;

  void registerHandlers() {
    unregisterHandlers();
    _signalRClient.on(RoomEvents.roomJoined, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      _logger.i('SignalR event room:joined — $json');
      final payload = RoomJoinedPayload.fromJson(json);
      _eventController.add(
        RoomEventRoomJoined(
          roomCode: payload.roomCode,
          role: payload.role,
          guestPresent: payload.guestPresent,
          contentDescriptor: payload.contentDescriptor,
        ),
      );
    });

    _signalRClient.on(RoomEvents.roomGuestJoined, (args) {
      _logger.i('SignalR event room:guest_joined');
      _eventController.add(const RoomEventGuestJoined());
    });

    _signalRClient.on(RoomEvents.roomGuestLeft, (args) {
      _logger.i('SignalR event room:guest_left');
      _eventController.add(const RoomEventGuestLeft());
    });

    _signalRClient.on(RoomEvents.roomGuestReconnected, (args) {
      _logger.i('SignalR event room:guest_reconnected');
      _eventController.add(const RoomEventGuestReconnected());
    });

    _signalRClient.on(RoomEvents.roomClosed, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      _logger.i('SignalR event room:closed — $json');
      final payload = RoomClosedPayload.fromJson(json);
      _eventController.add(RoomEventRoomClosed(payload.reason));
    });

    _signalRClient.on(RoomEvents.roomContentSet, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      _logger.i('SignalR event room:content_set');
      final payload = RoomContentSetPayload.fromJson(json);
      _eventController.add(RoomEventContentSet(payload.descriptor));
    });

    _signalRClient.on(RoomEvents.roomError, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      _logger.w('SignalR event room:error — $json');
      final payload = ErrorPayload.fromJson(json);
      _eventController.add(
        RoomEventError(code: payload.code, message: payload.message),
      );
    });

    _signalRClient.on(RoomEvents.playerReady, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      _logger.i('SignalR event player:ready — $json');
      final payload = PlayerReadyPayload.fromJson(json);
      _eventController.add(RoomEventPlayerReady(payload));
    });

    _signalRClient.on(RoomEvents.bufferingStall, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = BufferingStallBroadcastPayload.fromJson(json);
      onBufferingStall?.call(payload);
    });

    _signalRClient.on(RoomEvents.bufferingResume, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = BufferingResumePayload.fromJson(json);
      onBufferingResume?.call(payload);
    });

    _signalRClient.on(RoomEvents.playbackPlay, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = PlaybackPlayPayload.fromJson(json);
      onPlaybackPlay?.call(payload);
    });

    _signalRClient.on(RoomEvents.playbackPause, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = PlaybackPausePayload.fromJson(json);
      onPlaybackPause?.call(payload);
    });

    _signalRClient.on(RoomEvents.playbackSeek, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = PlaybackSeekPayload.fromJson(json);
      onPlaybackSeek?.call(payload);
    });

    _signalRClient.on(RoomEvents.playbackStateSync, (args) {
      if (args == null || args.isEmpty) return;
      final json = args[0] as Map<String, dynamic>;
      final payload = PlaybackStateSyncPayload.fromJson(json);
      onPlaybackStateSync?.call(payload);
    });
  }

  void unregisterHandlers() {
    _signalRClient.off(RoomEvents.roomJoined);
    _signalRClient.off(RoomEvents.roomGuestJoined);
    _signalRClient.off(RoomEvents.roomGuestLeft);
    _signalRClient.off(RoomEvents.roomGuestReconnected);
    _signalRClient.off(RoomEvents.roomClosed);
    _signalRClient.off(RoomEvents.roomContentSet);
    _signalRClient.off(RoomEvents.roomError);
    _signalRClient.off(RoomEvents.playerReady);
    _signalRClient.off(RoomEvents.bufferingStall);
    _signalRClient.off(RoomEvents.bufferingResume);
    _signalRClient.off(RoomEvents.playbackPlay);
    _signalRClient.off(RoomEvents.playbackPause);
    _signalRClient.off(RoomEvents.playbackSeek);
    _signalRClient.off(RoomEvents.playbackStateSync);
  }

  /// Notify server that local player is buffering.
  Future<void> notifyBufferingStall(int positionMs, int episodeId) async {
    await _signalRClient.invoke(
      RoomEvents.hubNotifyBufferingStall,
      args: [positionMs, episodeId],
    );
  }

  /// Notify server that local player is ready after buffering.
  Future<void> notifyBufferingReady(int episodeId) async {
    await _signalRClient.invoke(
      RoomEvents.hubNotifyBufferingReady,
      args: [episodeId],
    );
  }

  Future<void> notifyPlayerReady(String contentKey) async {
    await _signalRClient.invoke(
      RoomEvents.hubNotifyPlayerReady,
      args: [contentKey],
    );
    _eventController.add(RoomEventLocalReady(contentKey));
  }

  /// Host: invoke Play via SignalR hub method.
  /// Per ARCHITECTURE.md: host controls flow through the protocol.
  Future<void> invokePlay(int positionMs, int clientTimestampMs) async {
    _logger.i('RoomRepository.invokePlay: positionMs=$positionMs');
    await _signalRClient.invoke(
      RoomEvents.hubPlay,
      args: [positionMs, clientTimestampMs],
    );
  }

  /// Host: invoke Pause via SignalR hub method.
  Future<void> invokePause(int positionMs) async {
    _logger.i('RoomRepository.invokePause: positionMs=$positionMs');
    await _signalRClient.invoke(RoomEvents.hubPause, args: [positionMs]);
  }

  /// Host: invoke Seek via SignalR hub method.
  Future<void> invokeSeek(int targetPositionMs) async {
    _logger.d('RoomRepository.invokeSeek: targetPositionMs=$targetPositionMs');
    await _signalRClient.invoke(RoomEvents.hubSeek, args: [targetPositionMs]);
  }

  /// Fetch the list of currently active rooms from the REST API.
  Future<List<Map<String, dynamic>>> listRooms() => _httpClient.listRooms();

  Future<void> dispose() async {
    unregisterHandlers();
    await _eventController.close();
  }
}
