import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';

/// CL-25: Integration tests — host seeks, verify guest behavior.
/// Per TESTING_STRATEGY.md: host_guest_seek_test is a separate test file.
void main() {
  late MockPlayerImpl mockPlayer;
  late MockRoomRepository mockRepo;
  late SyncBloc syncBloc;

  setUp(() {
    mockPlayer = MockPlayerImpl();
    mockRepo = MockRoomRepository();
    syncBloc = SyncBloc(playerController: mockPlayer, roomRepository: mockRepo);
    syncBloc.setPlayerReady(true);
  });

  tearDown(() async {
    await syncBloc.close();
  });

  group('host_guest_seek integration', () {
    test('both playing, host seeks to 2:00 — guest seeks to ~2:00', () async {
      // Start playing
      mockPlayer.setPosition(const Duration(seconds: 30));
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 30000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Host seeks to 2:00 (120000ms)
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 120000));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 120000));
    });

    test('seek does not change sync state', () async {
      // Start playing
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateSyncing());

      // Host seeks — state should remain Syncing
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 60000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateSyncing());
    });

    test('multiple seeks update guest position each time', () async {
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 10000));
      await Future.delayed(const Duration(milliseconds: 30));
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 20000));
      await Future.delayed(const Duration(milliseconds: 30));
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 30000));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockPlayer.seekHistory.length, greaterThanOrEqualTo(3));
      expect(
        mockPlayer.seekHistory,
        containsAllInOrder([
          const Duration(milliseconds: 10000),
          const Duration(milliseconds: 20000),
          const Duration(milliseconds: 30000),
        ]),
      );
    });

    test('seek while paused keeps paused state', () async {
      // Start paused
      syncBloc.add(const SyncEventPauseReceived(positionMs: 5000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStatePaused());

      // Seek while paused
      syncBloc.add(const SyncEventSeekReceived(targetPositionMs: 90000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStatePaused());
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 90000));
    });
  });
}
