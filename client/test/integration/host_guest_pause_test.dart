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

  group('host_guest_pause integration', () {
    test(
      'both playing, host pauses — guest pauses at specified position',
      () async {
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
        syncBloc.updateGuestRtt(200);
        syncBloc.add(const SyncEventPauseReceived(positionMs: 12000));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          mockPlayer.seekHistory.last,
          const Duration(milliseconds: 12000),
        );
      },
    );

    test('SyncBloc transitions Syncing → Paused on pause', () async {
      syncBloc.add(
        const SyncEventPlayReceived(
          positionMs: 1000,
          serverTimestampMs: 0,
          hostRttMs: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStateSyncing());

      syncBloc.add(const SyncEventPauseReceived(positionMs: 3000));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(syncBloc.state, const SyncStatePaused());
    });
  });
}
