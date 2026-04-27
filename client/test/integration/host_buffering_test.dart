import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../mocks/mock_room_repository.dart';



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
        
        syncBloc.add(
          const SyncEventPlayReceived(
            positionMs: 10000,
            serverTimestampMs: 0,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(mockPlayer.isPlaying, true);

        
        syncBloc.add(
          const SyncEventPeerStalled(positionMs: 10500, episodeId: 1),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        
        expect(mockPlayer.isPlaying, false);
        expect(mockPlayer.actionHistory, contains('pause'));
        expect(syncBloc.state, const SyncStateBuffering());
      },
    );

    test('buffering:resume after peer stall → seeks and resumes', () async {
      
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 10000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, true);

      
      syncBloc.add(const SyncEventPeerStalled(positionMs: 10500, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, false);

      
      syncBloc.add(
        const SyncEventBufferingResumeReceived(
          resumePositionMs: 11000,
          episodeId: 1,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 11000));
      expect(mockPlayer.isPlaying, true);
      expect(syncBloc.state, const SyncStateSyncing());
    });

    test('buffering:resume while paused → seeks but stays paused', () async {
      
      syncBloc.add(const SyncEventPauseReceived(positionMs: 10000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockPlayer.isPlaying, false);

      
      syncBloc.add(const SyncEventPeerStalled(positionMs: 10000, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));

      
      syncBloc.add(
        const SyncEventBufferingResumeReceived(
          resumePositionMs: 10000,
          episodeId: 1,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      
      expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 10000));
      expect(mockPlayer.isPlaying, false);
      expect(syncBloc.state, const SyncStatePaused());
    });

    test('full host stall scenario from guest perspective', () async {
      
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 20000,
          serverTimestampMs: 0,
          hostRttMs: 80,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      
      syncBloc.add(const SyncEventPeerStalled(positionMs: 21000, episodeId: 1));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateBuffering());
      expect(mockPlayer.isPlaying, false);

      
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
