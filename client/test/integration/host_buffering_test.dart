import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';

/// Integration test for host buffering behavior.
/// Host stalls, guest pauses when receiving buffering:stall from peer.
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

  group('host_buffering integration ', () {
    test(
      'peer stalls → local player pauses, SyncBloc enters Buffering',
      () async {
        // Setup: playing
        syncBloc.add(
          const SyncEventPlayReceived(
            positionMs: 10000,
            serverTimestampMs: 0,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(mockPlayer.isPlaying, true);

        // Receive buffering:stall from peer (host stalled, we are guest)
        syncBloc.add(
          const SyncEventPeerStalled(positionMs: 10500, episodeId: 1),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Verify: player paused, SyncBloc in Buffering
        expect(mockPlayer.isPlaying, false);
        expect(mockPlayer.actionHistory, contains('pause'));
        expect(syncBloc.state, const SyncStateBuffering());
      },
    );

    test('buffering:resume after peer stall → seeks and resumes', () async {
      // Setup: playing
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 10000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, true);

      // Peer stalls
      syncBloc.add(const SyncEventPeerStalled(positionMs: 10500, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, false);

      // Server sends buffering:resume
      syncBloc.add(
        const SyncEventBufferingResumeReceived(
          resumePositionMs: 11000,
          episodeId: 1,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify: sought to resume position and playing
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 11000));
      expect(mockPlayer.isPlaying, true);
      expect(syncBloc.state, const SyncStateSyncing());
    });

    test('buffering:resume while paused → seeks but stays paused', () async {
      // Setup: paused (host had paused before stall)
      syncBloc.add(const SyncEventPauseReceived(positionMs: 10000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, false);

      // Peer stalls (we were paused)
      syncBloc.add(const SyncEventPeerStalled(positionMs: 10000, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));

      // Server sends resume
      syncBloc.add(
        const SyncEventBufferingResumeReceived(
          resumePositionMs: 10000,
          episodeId: 1,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Should seek to position but remain paused (was not playing)
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 10000));
      expect(mockPlayer.isPlaying, false);
      expect(syncBloc.state, const SyncStatePaused());
    });

    test('full host stall scenario from guest perspective', () async {
      // Playing
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 20000,
          serverTimestampMs: 0,
          hostRttMs: 80,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Host's player stalls → guest receives buffering:stall
      syncBloc.add(const SyncEventPeerStalled(positionMs: 21000, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateBuffering());
      expect(mockPlayer.isPlaying, false);

      // Host recovers, server sends buffering:resume to both
      syncBloc.add(
        const SyncEventBufferingResumeReceived(
          resumePositionMs: 21000,
          episodeId: 1,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(syncBloc.state, const SyncStateSyncing());
      expect(mockPlayer.isPlaying, true);
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 21000));
    });
  });
}
