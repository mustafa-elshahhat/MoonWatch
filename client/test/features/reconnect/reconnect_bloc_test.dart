import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/protocol/room_events.dart';
import 'package:watch_party/features/reconnect/reconnect_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late MockSignalRClient mockSignalRClient;
  late MockRoomRepository mockRoomRepository;
  late StreamController<SignalRConnectionState> connectionStateController;
  late StreamController<RoomEvent> roomEventsController;

  setUp(() {
    mockSignalRClient = MockSignalRClient();
    mockRoomRepository = MockRoomRepository();
    connectionStateController =
        StreamController<SignalRConnectionState>.broadcast();
    roomEventsController = StreamController<RoomEvent>.broadcast();

    when(
      () => mockSignalRClient.connectionState,
    ).thenAnswer((_) => connectionStateController.stream);
    when(
      () => mockSignalRClient.invoke(any(), args: any(named: 'args')),
    ).thenAnswer((_) async => null);
    when(
      () => mockRoomRepository.events,
    ).thenAnswer((_) => roomEventsController.stream);
  });

  tearDown(() async {
    await connectionStateController.close();
    await roomEventsController.close();
  });

  ReconnectBloc buildBloc() => ReconnectBloc(
        signalRClient: mockSignalRClient,
        roomRepository: mockRoomRepository,
      );

  // ── Initial state ──────────────────────────────────────────────────────

  group('ReconnectBloc — initial state', () {
    test('initial state is ReconnectStateIdle', () {
      final bloc = buildBloc();
      expect(bloc.state, const ReconnectStateIdle());
      bloc.close();
    });
  });

  // ── Disconnected event ─────────────────────────────────────────────────

  group('ReconnectBloc — Disconnected', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'Idle → Attempting on Disconnected',
      build: buildBloc,
      act: (bloc) => bloc.add(const ReconnectEventDisconnected()),
      expect: () => [const ReconnectStateAttempting(attemptNumber: 1)],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'Disconnected ignored if already Attempting',
      build: buildBloc,
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) => bloc.add(const ReconnectEventDisconnected()),
      expect: () => <ReconnectState>[],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'Disconnected ignored if already Failed',
      build: buildBloc,
      seed: () => const ReconnectStateFailed('max_retries'),
      act: (bloc) => bloc.add(const ReconnectEventDisconnected()),
      expect: () => <ReconnectState>[],
    );
  });

  // ── AttemptRejoin event ────────────────────────────────────────────────

  group('ReconnectBloc — AttemptRejoin', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'AttemptRejoin invokes SignalR JoinRoom with stored credentials',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        return bloc;
      },
      act: (bloc) => bloc.add(const ReconnectEventAttemptRejoin()),
      verify: (_) {
        verify(
          () => mockSignalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: ['ABC123', 'guest'],
          ),
        ).called(1);
      },
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'AttemptRejoin with no credentials → Failed(no_credentials)',
      build: buildBloc,
      act: (bloc) => bloc.add(const ReconnectEventAttemptRejoin()),
      expect: () => [const ReconnectStateFailed('no_credentials')],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'AttemptRejoin when invoke throws → Failed(rejoin_error)',
      build: () {
        when(
          () => mockSignalRClient.invoke(any(), args: any(named: 'args')),
        ).thenThrow(Exception('network error'));
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        return bloc;
      },
      act: (bloc) => bloc.add(const ReconnectEventAttemptRejoin()),
      wait: const Duration(seconds: 4),
      expect: () => [const ReconnectStateFailed('rejoin_error')],
    );
  });

  // ── Succeeded event ────────────────────────────────────────────────────

  group('ReconnectBloc — Succeeded', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'Succeeded → Success then Idle',
      build: buildBloc,
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) => bloc.add(const ReconnectEventSucceeded()),
      expect: () => [const ReconnectStateSuccess(), const ReconnectStateIdle()],
    );
  });

  // ── Failed event ───────────────────────────────────────────────────────

  group('ReconnectBloc — Failed', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'Failed emits ReconnectStateFailed with reason',
      build: buildBloc,
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) => bloc.add(const ReconnectEventFailed('room_closed')),
      expect: () => [const ReconnectStateFailed('room_closed')],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'Failed with max_retries reason',
      build: buildBloc,
      seed: () => const ReconnectStateAttempting(attemptNumber: 3),
      act: (bloc) => bloc.add(const ReconnectEventFailed('max_retries')),
      expect: () => [const ReconnectStateFailed('max_retries')],
    );
  });

  // ── NetworkLost / NetworkRestored ──────────────────────────────────────

  group('ReconnectBloc — Network events', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'NetworkLost → Offline',
      build: buildBloc,
      act: (bloc) => bloc.add(const ReconnectEventNetworkLost()),
      expect: () => [const ReconnectStateOffline()],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'NetworkRestored from Offline → Attempting',
      build: buildBloc,
      seed: () => const ReconnectStateOffline(),
      act: (bloc) => bloc.add(const ReconnectEventNetworkRestored()),
      expect: () => [const ReconnectStateAttempting(attemptNumber: 1)],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'NetworkRestored from Idle is ignored',
      build: buildBloc,
      act: (bloc) => bloc.add(const ReconnectEventNetworkRestored()),
      expect: () => <ReconnectState>[],
    );
  });

  // ── Reset event ────────────────────────────────────────────────────────

  group('ReconnectBloc — Reset', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'Reset → Idle, clears stored credentials',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        return bloc;
      },
      seed: () => const ReconnectStateAttempting(attemptNumber: 2),
      act: (bloc) => bloc.add(const ReconnectEventReset()),
      expect: () => [const ReconnectStateIdle()],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'After Reset, AttemptRejoin fails with no_credentials',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        return bloc;
      },
      act: (bloc) {
        bloc.add(const ReconnectEventReset());
        bloc.add(const ReconnectEventAttemptRejoin());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const ReconnectStateIdle(),
        const ReconnectStateFailed('no_credentials'),
      ],
    );
  });

  // ── startListening — SignalR connection state integration ──────────────

  group('ReconnectBloc — startListening', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'reconnecting state → Disconnected → Attempting',
      build: () {
        final bloc = buildBloc();
        bloc.startListening();
        return bloc;
      },
      act: (bloc) {
        connectionStateController.add(SignalRConnectionState.reconnecting);
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const ReconnectStateAttempting(attemptNumber: 1)],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'reconnecting then connected → Attempting then rejoin attempt',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('XYZ789', 'guest');
        bloc.startListening();
        return bloc;
      },
      act: (bloc) async {
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 30));
        connectionStateController.add(SignalRConnectionState.connected);
      },
      wait: const Duration(milliseconds: 100),
      verify: (_) {
        verify(
          () => mockSignalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: ['XYZ789', 'guest'],
          ),
        ).called(1);
      },
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'disconnected after Attempting → Failed(max_retries)',
      build: () {
        final bloc = buildBloc();
        bloc.startListening();
        return bloc;
      },
      act: (bloc) async {
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 30));
        connectionStateController.add(SignalRConnectionState.disconnected);
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const ReconnectStateAttempting(attemptNumber: 1),
        const ReconnectStateFailed('max_retries'),
      ],
    );
  });

  // ── storeRoomCredentials ───────────────────────────────────────────────

  group('ReconnectBloc — storeRoomCredentials', () {
    test('stores room code and role for rejoin', () async {
      final bloc = buildBloc();
      bloc.storeRoomCredentials('ROOM42', 'host');
      // Trigger rejoin; it should use stored credentials
      bloc.add(const ReconnectEventAttemptRejoin());
      await Future.delayed(const Duration(milliseconds: 50));
      verify(
        () => mockSignalRClient.invoke(
          RoomEvents.hubJoinRoom,
          args: ['ROOM42', 'host'],
        ),
      ).called(1);
      await bloc.close();
    });
  });

  // ── CL-37/CL-38: Room event listening after rejoin ────────────────────

  group('ReconnectBloc — room event listening (CL-37/CL-38)', () {
    blocTest<ReconnectBloc, ReconnectState>(
      'room:joined while Attempting → Succeeded → Idle',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        bloc.startListening();
        return bloc;
      },
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) {
        roomEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const ReconnectStateSuccess(), const ReconnectStateIdle()],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'room:error(room_closed) while Attempting → Failed(room_closed)',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        bloc.startListening();
        return bloc;
      },
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) {
        roomEventsController.add(
          const RoomEventError(
            code: 'room_closed',
            message: 'Room has been closed.',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const ReconnectStateFailed('room_closed')],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'room:error(room_full) while Attempting → Failed(room_full)',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        bloc.startListening();
        return bloc;
      },
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) {
        roomEventsController.add(
          const RoomEventError(
            code: 'room_full',
            message: 'Room is already full.',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const ReconnectStateFailed('room_full')],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'room:joined while Idle is ignored (no state change)',
      build: () {
        final bloc = buildBloc();
        bloc.startListening();
        return bloc;
      },
      act: (bloc) {
        roomEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <ReconnectState>[],
    );

    blocTest<ReconnectBloc, ReconnectState>(
      'non-fatal room:error while Attempting is ignored',
      build: () {
        final bloc = buildBloc();
        bloc.storeRoomCredentials('ABC123', 'guest');
        bloc.startListening();
        return bloc;
      },
      seed: () => const ReconnectStateAttempting(attemptNumber: 1),
      act: (bloc) {
        roomEventsController.add(
          const RoomEventError(
            code: 'stream_url_invalid',
            message: 'Invalid URL.',
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => <ReconnectState>[],
    );
  });
}
