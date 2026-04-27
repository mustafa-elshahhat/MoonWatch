import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';

/// CL-24: Integration test — host plays, guest player receives seek-and-play
/// at the correct latency-adjusted position.
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

  group('host_guest_play integration', () {
    test('guest receives play and seeks to latency-adjusted position',
        () async {
      // Setup: guest player at position 0, default RTT = 100ms
      mockPlayer.setPosition(Duration.zero);

      // Host plays at position 5000ms with hostRttMs=80
      syncBloc.add(
        SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          hostRttMs: 80,
        ),
      );

      // Wait for bloc to process
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify player was seeked and played
      expect(mockPlayer.seekHistory, isNotEmpty);
      // adjusted = 5000 + ~0 (elapsed) + 80/2 = ~5040 (within 5ms tolerance)
      // (guestRttMs/2 no longer added — clock offset handles server→guest delay)
      expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5040, 5));
      expect(mockPlayer.isPlaying, true);
      expect(
        mockPlayer.actionHistory,
        containsAllInOrder([
          'seekTo:${mockPlayer.seekHistory.last.inMilliseconds}',
          'play',
        ]),
      );
    });

    test('guest play uses updated guest RTT for compensation', () async {
      mockPlayer.setPosition(Duration.zero);
      syncBloc.updateGuestRtt(200); // set guest RTT to 200ms

      syncBloc.add(
        SyncEventPlayReceived(
          positionMs: 10000,
          serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          hostRttMs: 100,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // adjusted = 10000 + ~0 (elapsed) + 100/2 = ~10050 (within 5ms tolerance)
      expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(10050, 5));
      expect(mockPlayer.isPlaying, true);
    });

    // Note: The 6-second post-command cooldown (_kPostCommandCooldownMs) and the
    // 2-hit hysteresis (_kRequiredDriftHits) prevent correction seeks from firing
    // within 50ms of a play command. This test verifies the play applies correctly
    // and that the state_sync does NOT trigger a premature correction during cooldown.
    test(
      'guest play positions correctly — no premature correction within cooldown',
      () async {
        // Guest at position 5000ms
        mockPlayer.setPosition(const Duration(milliseconds: 5000));

        // Host plays at 5000ms
        syncBloc.add(
          SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify play applied to adjusted position (5000 + 50 = 5050)
        expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5050, 10));
        expect(syncBloc.state, const SyncStateSyncing());

        // State sync within cooldown window should NOT trigger correction seek
        final now = DateTime.now().millisecondsSinceEpoch;
        mockPlayer.setPosition(const Duration(milliseconds: 5200));
        syncBloc.add(
          SyncEventStateSyncReceived(
            hostPositionMs: 8000,
            isPlaying: true,
            serverTimestampMs: now,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 100));

        // No additional seek during cooldown — last seek is still the play seek
        expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5050, 10));
        expect(syncBloc.state, const SyncStateSyncing());
      },
    );

    test('SyncBloc transitions from Idle to Syncing on play', () async {
      expect(syncBloc.state, const SyncStateIdle());

      syncBloc.add(
        SyncEventPlayReceived(
          positionMs: 1000,
          serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 100));

      expect(syncBloc.state, const SyncStateSyncing());
    });
  });
}
