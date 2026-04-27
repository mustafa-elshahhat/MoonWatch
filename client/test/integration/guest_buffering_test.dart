import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';

/// Integration test for guest buffering behavior.
/// Both playing, mock guest stall, verify both pause.
/// Both report ready, verify resume with position.
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

  group('guest_buffering integration ', () {
    test(
      'guest stalls → notifyBufferingStall called, SyncBloc enters Buffering',
      () async {
        // Setup: both playing
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

        // Guest's player stalls
        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify: SyncBloc in Buffering, stall notification sent
        expect(syncBloc.state, const SyncStateBuffering());
        expect(mockRepo.notifyBufferingStallCalls, hasLength(1));
        expect(mockRepo.notifyBufferingStallCalls.first, 5500);
      },
    );

    test(
      'guest stall guard: duplicate stall does not send second notification',
      () async {
        syncBloc.add(
          const SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: 0,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // First stall
        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

        // Second stall (duplicate)
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

        // Only one notification sent
        expect(mockRepo.notifyBufferingStallCalls, hasLength(1));
      },
    );

    test('guest ready after stall → notifyBufferingReady called', () async {
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Guest stalls
      mockPlayer.setPosition(const Duration(milliseconds: 5500));
      syncBloc.add(const SyncEventPlayerStalled());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.notifyBufferingStallCalls, hasLength(1));

      // Guest recovers
      syncBloc.add(const SyncEventPlayerReady());
      await Future.delayed(const Duration(milliseconds: 50));

      // Ready notification sent
      expect(mockRepo.notifyBufferingReadyCalls, 1);
    });

    test(
      'guest ready guard: ready without prior stall does not send notification',
      () async {
        // No stall sent — just send ready
        syncBloc.add(const SyncEventPlayerReady());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRepo.notifyBufferingReadyCalls, 0);
      },
    );

    test(
      'full buffering cycle: stall → peer pause → both ready → resume',
      () async {
        // Setup: playing
        syncBloc.add(
          const SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: 0,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(mockPlayer.isPlaying, true);

        // Guest stalls
        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));
        expect(syncBloc.state, const SyncStateBuffering());

        // Guest recovers locally
        syncBloc.add(const SyncEventPlayerReady());
        await Future.delayed(const Duration(milliseconds: 50));

        // Server sends buffering:resume (both participants are Ready)
        syncBloc.add(
          const SyncEventBufferingResumeReceived(
            resumePositionMs: 6000,
            episodeId: 1,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify: player sought to resumePositionMs and resumed
        expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 6000));
        expect(mockPlayer.isPlaying, true);
        expect(syncBloc.state, const SyncStateSyncing());
      },
    );
  });
}
