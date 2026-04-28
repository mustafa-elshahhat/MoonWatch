import 'dart:async';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/features/room/domain/room_repository_event.dart';

class MockRoomRepository implements RoomRepository {
  final _eventController = StreamController<RoomRepositoryEvent>.broadcast();

  final List<int> notifyBufferingStallCalls = [];

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
  PlaybackSpeedCallback? onPlaybackSpeed;

  @override
  Stream<RoomRepositoryEvent> get events => _eventController.stream;

  @override
  void clearCallbacks() {
    onBufferingStall = null;
    onBufferingResume = null;
    onPlaybackPlay = null;
    onPlaybackPause = null;
    onPlaybackSeek = null;
    onPlaybackStateSync = null;
    onPlaybackSpeed = null;
  }

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

  final List<String> notifyPlayerReadyCalls = [];

  @override
  Future<void> notifyPlayerReady(String contentKey) async {
    notifyPlayerReadyCalls.add(contentKey);
  }

  final List<List<int>> invokePlayCalls = [];

  final List<int> invokePauseCalls = [];

  final List<int> invokeSeekCalls = [];

  final List<double> invokeSetPlaybackSpeedCalls = [];

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

  @override
  Future<void> invokeSetPlaybackSpeed(double speed) async {
    invokeSetPlaybackSpeedCalls.add(speed);
  }

  void injectEvent(RoomRepositoryEvent event) {
    _eventController.add(event);
  }

  @override
  Future<List<Map<String, dynamic>>> listRooms() async => [];

  @override
  Future<void> dispose() async {
    await _eventController.close();
  }
}
