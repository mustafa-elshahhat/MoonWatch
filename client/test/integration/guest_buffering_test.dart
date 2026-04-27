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

  group('guest_buffering integration ', () {
    test(
      'guest stalls → notifyBufferingStall called, SyncBloc enters Buffering',
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

        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

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

        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));

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

      mockPlayer.setPosition(const Duration(milliseconds: 5500));
      syncBloc.add(const SyncEventPlayerStalled());
      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockRepo.notifyBufferingStallCalls, hasLength(1));

      syncBloc.add(const SyncEventPlayerReady());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(mockRepo.notifyBufferingReadyCalls, 1);
    });

    test(
      'guest ready guard: ready without prior stall does not send notification',
      () async {
        syncBloc.add(const SyncEventPlayerReady());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRepo.notifyBufferingReadyCalls, 0);
      },
    );

    test(
      'full buffering cycle: stall → peer pause → both ready → resume',
      () async {
        syncBloc.add(
          const SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: 0,
            hostRttMs: 100,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(mockPlayer.isPlaying, true);

        mockPlayer.setPosition(const Duration(milliseconds: 5500));
        syncBloc.add(const SyncEventPlayerStalled());
        await Future.delayed(const Duration(milliseconds: 50));
        expect(syncBloc.state, const SyncStateBuffering());

        syncBloc.add(const SyncEventPlayerReady());
        await Future.delayed(const Duration(milliseconds: 50));

        syncBloc.add(
          const SyncEventBufferingResumeReceived(
            resumePositionMs: 6000,
            episodeId: 1,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 6000));
        expect(mockPlayer.isPlaying, true);
        expect(syncBloc.state, const SyncStateSyncing());
      },
    );
  });
}
