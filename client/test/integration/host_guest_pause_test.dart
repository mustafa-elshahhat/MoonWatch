import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';

/// CL-25: Integration tests — host pauses, verify guest behavior.
/// Seek tests are in host_guest_seek_test.dart per TESTING_STRATEGY.md.
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

  // ── host_guest_pause_test ──────────────────────────────────────────────

  group('host_guest_pause integration', () {
    test(
      'both playing, host pauses — guest pauses at specified position',
      () async {
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
        expect(mockPlayer.isPlaying, true);

        // Host pauses at position 7500ms
        syncBloc.add(const SyncEventPauseReceived(positionMs: 7500));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(syncBloc.state, const SyncStatePaused());
        expect(mockPlayer.isPlaying, false);
        expect(mockPlayer.actionHistory, contains('pause'));
        expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 7500));
      },
    );

    test(
      'guest pauses at exact host position (no latency compensation on pause)',
      () async {
        // Pause should seek to exact position without RTT compensation
        syncBloc.updateGuestRtt(200);
        syncBloc.add(const SyncEventPauseReceived(positionMs: 12000));
        await Future.delayed(const Duration(milliseconds: 50));

        // Pause seeks to exact positionMs, not adjusted
        expect(
          mockPlayer.seekHistory.last,
          const Duration(milliseconds: 12000),
        );
      },
    );

    test('SyncBloc transitions Syncing → Paused on pause', () async {
      // Put bloc into Syncing state first
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 1000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateSyncing());

      // Now pause
      syncBloc.add(const SyncEventPauseReceived(positionMs: 3000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStatePaused());
    });
  });
}
