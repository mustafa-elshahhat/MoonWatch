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
    when(
      () => playerController.durationStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => playerController.positionStream,
    ).thenAnswer((_) => const Stream.empty());
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
      var syncBlocA = SyncBloc(
        playerController: playerController,
        roomRepository: roomRepository,
      );

      syncBlocA.setPlayerReady(true);

      syncBlocA.add(
        const SyncEventPlayReceived(
          positionMs: 1000,
          serverTimestampMs: 5000,
          hostRttMs: 50,
          seqNo: 100,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => playerController.play()).called(1);

      syncBlocA.add(
        const SyncEventPlayReceived(
          positionMs: 2000,
          serverTimestampMs: 6000,
          hostRttMs: 50,
          seqNo: 50,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      verifyNever(
        () => playerController.seekTo(const Duration(milliseconds: 2000)),
      );

      await syncBlocA.close();

      var syncBlocB = SyncBloc(
        playerController: playerController,
        roomRepository: roomRepository,
      );
      syncBlocB.setPlayerReady(true);

      syncBlocB.add(
        const SyncEventPlayReceived(
          positionMs: 5000,
          serverTimestampMs: 10000,
          hostRttMs: 50,
          seqNo: 1,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => playerController.play()).called(1);

      await syncBlocB.close();
    });

    test('PlayerBloc state does not bleed across room sessions', () async {
      var playerBlocA = PlayerBloc(playerController: playerController);
      playerBlocA.setRoomMode(true);

      playerBlocA.add(const PlayerEventInitialize('urlA', source: 'test'));
      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => playerController.initialize('urlA')).called(1);

      playerBlocA.add(const PlayerEventInitialize('urlA', source: 'test'));
      await Future.delayed(const Duration(milliseconds: 50));
      verifyNever(() => playerController.initialize('urlB'));

      await playerBlocA.close();

      var playerBlocB = PlayerBloc(playerController: playerController);
      playerBlocB.setRoomMode(true);

      playerBlocB.add(const PlayerEventInitialize('urlB', source: 'test2'));
      await Future.delayed(const Duration(milliseconds: 50));

      verify(() => playerController.initialize('urlB')).called(1);

      await playerBlocB.close();
    });
  });
}
