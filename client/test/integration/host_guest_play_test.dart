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

  group('host_guest_play integration', () {
    test('guest receives play and seeks to latency-adjusted position',
        () async {
      
      mockPlayer.setPosition(Duration.zero);

      
      syncBloc.add(
        SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          hostRttMs: 80,
        ),
      );

      
      await Future.delayed(const Duration(milliseconds: 100));

      
      expect(mockPlayer.seekHistory, isNotEmpty);
      
      
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
      syncBloc.updateGuestRtt(200); 

      syncBloc.add(
        SyncEventPlayReceived(
          positionMs: 10000,
          serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          hostRttMs: 100,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      
      expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(10050, 5));
      expect(mockPlayer.isPlaying, true);
    });

    
    
    
    
    test(
      'guest play positions correctly — no premature correction within cooldown',
      () async {
        
        mockPlayer.setPosition(const Duration(milliseconds: 5000));

        
        syncBloc.add(
          SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        
        expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5050, 10));
        expect(syncBloc.state, const SyncStateSyncing());

        
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
