import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/protocol/room_events.dart';
import 'package:watch_party/features/reconnect/reconnect_bloc.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/core/network/http_client.dart';

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockHttpClient extends Mock implements HttpClient {}

/// CL-42: Integration test — guest_reconnect_test.
/// Simulates: guest connected → SignalR drops → reconnects → rejoin → state_sync.
void main() {
  late MockSignalRClient mockSignalRClient;
  late MockRoomRepository mockRoomRepository;
  late StreamController<SignalRConnectionState> connectionStateController;
  late StreamController<RoomEvent> repoEventsController;
  late ReconnectBloc reconnectBloc;
  late RoomBloc roomBloc;

  setUp(() {
    mockSignalRClient = MockSignalRClient();
    mockRoomRepository = MockRoomRepository();
    connectionStateController =
        StreamController<SignalRConnectionState>.broadcast();
    repoEventsController = StreamController<RoomEvent>.broadcast();

    when(
      () => mockSignalRClient.connectionState,
    ).thenAnswer((_) => connectionStateController.stream);
    when(
      () => mockSignalRClient.invoke(any(), args: any(named: 'args')),
    ).thenAnswer((_) async => null);
    when(() => mockSignalRClient.connect()).thenAnswer((_) async {});
    when(() => mockSignalRClient.disconnect()).thenAnswer((_) async {});
    when(
      () => mockRoomRepository.events,
    ).thenAnswer((_) => repoEventsController.stream);
    when(() => mockRoomRepository.registerHandlers()).thenReturn(null);

    reconnectBloc = ReconnectBloc(
      signalRClient: mockSignalRClient,
      roomRepository: mockRoomRepository,
    );

    roomBloc = RoomBloc(
      roomRepository: mockRoomRepository,
      signalRClient: mockSignalRClient,
    );
  });

  tearDown(() async {
    await reconnectBloc.close();
    await roomBloc.close();
    await connectionStateController.close();
    await repoEventsController.close();
  });

  group('guest_reconnect integration (CL-42)', () {
    test(
      'SignalR drop → reconnect → rejoin invocation → room:joined → Success',
      () async {
        // 1. Setup: guest is connected to room
        reconnectBloc.storeRoomCredentials('ABC123', 'guest');
        reconnectBloc.startListening();

        // 2. SignalR connection drops (reconnecting)
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        // 3. SignalR auto-reconnects
        connectionStateController.add(SignalRConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 100));

        // 4. Verify JoinRoom was invoked for rejoin
        verify(
          () => mockSignalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: ['ABC123', 'guest'],
          ),
        ).called(1);

        // 5. Server responds with room:joined via RoomRepository events
        //    (CL-37: ReconnectBloc listens and auto-dispatches Succeeded)
        repoEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(reconnectBloc.state, const ReconnectStateIdle());
      },
    );

    test(
      'SignalR drop → all retries exhausted → Failed(max_retries)',
      () async {
        reconnectBloc.storeRoomCredentials('ABC123', 'guest');
        reconnectBloc.startListening();

        // SignalR starts reconnecting
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        // SignalR gives up — moves to disconnected
        connectionStateController.add(SignalRConnectionState.disconnected);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(reconnectBloc.state, const ReconnectStateFailed('max_retries'));
      },
    );

    test('SignalR drop → reconnect → rejoin error → Failed', () async {
      reconnectBloc.storeRoomCredentials('ABC123', 'guest');
      reconnectBloc.startListening();

      // SignalR drops and reconnects
      connectionStateController.add(SignalRConnectionState.reconnecting);
      await Future.delayed(const Duration(milliseconds: 50));
      connectionStateController.add(SignalRConnectionState.connected);
      await Future.delayed(const Duration(milliseconds: 100));

      // Server responds with room:error via RoomRepository events
      // (CL-38: ReconnectBloc listens and auto-dispatches Failed)
      repoEventsController.add(
        const RoomEventError(
          code: 'room_closed',
          message: 'Room has been closed.',
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(reconnectBloc.state, const ReconnectStateFailed('room_closed'));
    });

    test('RoomBloc receives room:closed during disconnect', () async {
      // Subscribe the bloc to the mock repo stream before sending events.
      roomBloc.startListening();

      // Guest is joined to room (add event directly since startListening
      // routes from repo stream, but RoomEventRoomJoined may also come via
      // direct dispatch from within _onJoinRoom; use direct add here to set state).
      roomBloc.add(
        const RoomEventRoomJoined(
          roomCode: 'ABC123',
          role: 'guest',
          guestPresent: true,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Room closes (host left or grace period expired) — arrives via repo stream.
      repoEventsController.add(const RoomEventRoomClosed('host_disconnected'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(roomBloc.state, const RoomStateClosed('host_disconnected'));
    });
  });
}
