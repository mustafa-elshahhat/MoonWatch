import 'dart:async';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';

/// Manual test double for RoomRepository.
/// Records outgoing calls for assertions.
class MockRoomRepository implements RoomRepository {
  final _eventController = StreamController<RoomEvent>.broadcast();

  /// Recorded calls to notifyBufferingStall with positionMs.
  final List<int> notifyBufferingStallCalls = [];

  /// Recorded calls to notifyBufferingReady.
  int notifyBufferingReadyCalls = 0;

  @override
  BufferingStallCallback? onBufferingStall;

  @override
  BufferingResumeCallback? onBufferingResume;

  @override
  PlaybackPlayCallback? onPlaybackPlay;

  @override
  PlaybackPauseCallback? onPlaybackPause;

  @override
  PlaybackSeekCallback? onPlaybackSeek;

  @override
  PlaybackStateSyncCallback? onPlaybackStateSync;

  @override
  Stream<RoomEvent> get events => _eventController.stream;

  @override
  void registerHandlers() {}

  @override
  void unregisterHandlers() {}

  @override
  Future<void> notifyBufferingStall(int positionMs, int episodeId) async {
    notifyBufferingStallCalls.add(positionMs);
  }

  @override
  Future<void> notifyBufferingReady(int episodeId) async {
    notifyBufferingReadyCalls++;
  }

  /// Recorded calls to notifyPlayerReady, grouped by content key.
  final List<String> notifyPlayerReadyCalls = [];

  @override
  Future<void> notifyPlayerReady(String contentKey) async {
    notifyPlayerReadyCalls.add(contentKey);
  }

  /// Recorded calls to invokePlay with [positionMs, clientTimestampMs].
  final List<List<int>> invokePlayCalls = [];

  /// Recorded calls to invokePause with positionMs.
  final List<int> invokePauseCalls = [];

  /// Recorded calls to invokeSeek with targetPositionMs.
  final List<int> invokeSeekCalls = [];

  @override
  Future<void> invokePlay(int positionMs, int clientTimestampMs) async {
    invokePlayCalls.add([positionMs, clientTimestampMs]);
  }

  @override
  Future<void> invokePause(int positionMs) async {
    invokePauseCalls.add(positionMs);
  }

  @override
  Future<void> invokeSeek(int targetPositionMs) async {
    invokeSeekCalls.add(targetPositionMs);
  }

  /// Inject a room event for testing.
  void injectEvent(RoomEvent event) {
    _eventController.add(event);
  }

  @override
  Future<List<Map<String, dynamic>>> listRooms() async => [];

  @override
  Future<void> dispose() async {
    await _eventController.close();
  }
}
