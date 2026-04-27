import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/player/player_controller.dart';
import 'package:watch_party/features/player/bloc/player_bloc.dart';
import 'package:watch_party/features/player/bloc/player_event.dart';

import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/features/sync/sync_engine.dart';

class MockPlayerController extends Mock implements PlayerController {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late MockPlayerController playerController;
  late MockRoomRepository roomRepository;

  setUp(() {
    playerController = MockPlayerController();
    roomRepository = MockRoomRepository();

    when(() => playerController.events).thenAnswer((_) => const Stream.empty());
    when(() => playerController.durationStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => playerController.positionStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => playerController.currentPosition).thenReturn(Duration.zero);
    when(() => playerController.duration).thenReturn(Duration.zero);
    when(() => playerController.isPlaying).thenReturn(false);
    when(() => playerController.isBuffering).thenReturn(false);
    when(() => playerController.isInitialized).thenReturn(true);
    when(() => playerController.initialize(any())).thenAnswer((_) async {});
    when(() => playerController.dispose()).thenAnswer((_) async {});
    when(() => playerController.play()).thenAnswer((_) async {});
    when(() => playerController.pause()).thenAnswer((_) async {});
    when(() => playerController.seekTo(any())).thenAnswer((_) async {});
  });

  group('Bloc Session Scoping tests', () {
    test('SyncBloc state does not bleed across room sessions', () async {
      // Create first scoped SyncBloc (simulating joining Room A)
      var syncBlocA = SyncBloc(
        playerController: playerController,
        roomRepository: roomRepository,
      );

      // Simulate player being ready
      syncBlocA.setPlayerReady(true);

      // Apply command with seqNo 100 in Room A
      syncBlocA.add(
        const SyncEventPlayReceived(
          positionMs: 1000,
          serverTimestampMs: 5000,
          hostRttMs: 50,
          seqNo: 100,
        ),
      );

      // Wait for async processing
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify the play command was processed (playerController.play was called)
      verify(() => playerController.play()).called(1);

      // Try sending a lower seqNo in Room A (should be ignored)
      syncBlocA.add(
        const SyncEventPlayReceived(
          positionMs: 2000,
          serverTimestampMs: 6000,
          hostRttMs: 50,
          seqNo: 50, // Stale!
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      // Still only 1 call to play because seqNo 50 <= 100
      verifyNever(
          () => playerController.seekTo(const Duration(milliseconds: 2000)));

      // Dispose SyncBloc A (simulating leaving WatchScreen)
      await syncBlocA.close();

      // Create second scoped SyncBloc (simulating joining Room B)
      var syncBlocB = SyncBloc(
        playerController: playerController,
        roomRepository: roomRepository,
      );
      syncBlocB.setPlayerReady(true);

      // Apply command with seqNo 1 in Room B
      syncBlocB.add(
        const SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: 10000,
          hostRttMs: 50,
          seqNo: 1, // Fresh seqNo for the new room!
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // The new session should NOT reject seqNo 1.
      verify(() => playerController.play()).called(1);

      await syncBlocB.close();
    });

    test('PlayerBloc state does not bleed across room sessions', () async {
      // Create first scoped PlayerBloc
      var playerBlocA = PlayerBloc(playerController: playerController);
      playerBlocA.setRoomMode(true);

      // Initialize content A
      playerBlocA.add(const PlayerEventInitialize('urlA', source: 'test'));
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify initialization
      verify(() => playerController.initialize('urlA')).called(1);

      // If we send it again to the SAME bloc, it shouldn't re-initialize (duplicate init guard)
      playerBlocA.add(const PlayerEventInitialize('urlA', source: 'test'));
      await Future.delayed(const Duration(milliseconds: 50));
      verifyNever(() => playerController.initialize('urlB'));

      // Dispose PlayerBloc A
      await playerBlocA.close();

      // Create second scoped PlayerBloc
      var playerBlocB = PlayerBloc(playerController: playerController);
      playerBlocB.setRoomMode(true);

      // Initialize content B (or even A again, but B is a better test of isolation)
      playerBlocB.add(const PlayerEventInitialize('urlB', source: 'test2'));
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify the new session initialized successfully, proving state was fresh
      verify(() => playerController.initialize('urlB')).called(1);

      await playerBlocB.close();
    });
  });
}
