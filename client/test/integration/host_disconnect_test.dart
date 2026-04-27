import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/protocol/payloads.dart';
import 'package:watch_party/features/reconnect/reconnect_bloc.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/core/network/http_client.dart';

const _testDescriptor = IptvContentDescriptor(
  contentType: IptvDescriptorType.live,
  streamId: '12345',
  title: 'Test Channel',
);

// ── Mocks ────────────────────────────────────────────────────────────────────

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockHttpClient extends Mock implements HttpClient {}

/// CL-43: Integration test — host_disconnect_test.
/// Host disconnects → guest receives room:closed → RoomBloc → Closed.
/// ReconnectBloc should NOT attempt reconnection (host disconnect = no grace).
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

  group('host_disconnect integration (CL-43)', () {
    test('host disconnects → guest RoomBloc transitions to Closed', () async {
      // Subscribe roomBloc to the mock repo stream before streaming events.
      roomBloc.startListening();

      // 1. Guest is in Active state
      roomBloc.add(
        const RoomEventRoomJoined(
          roomCode: 'ABC123',
          role: 'guest',
          guestPresent: true,
          contentDescriptor: _testDescriptor,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        roomBloc.state,
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _testDescriptor,
        ),
      );

      // 2. Server sends room:closed with reason host_disconnected
      repoEventsController.add(const RoomEventRoomClosed('host_disconnected'));
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Guest RoomBloc transitions to Closed
      expect(roomBloc.state, const RoomStateClosed('host_disconnected'));
    });

    test(
      'host disconnects → ReconnectBloc reset prevents reconnection',
      () async {
        reconnectBloc.storeRoomCredentials('ABC123', 'guest');
        reconnectBloc.startListening();

        // Guest receives room:closed → app should reset ReconnectBloc
        // (In production, this is triggered by the RoomBloc/UI layer.)
        reconnectBloc.add(const ReconnectEventReset());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(reconnectBloc.state, const ReconnectStateIdle());

        // Even if SignalR drops now, ReconnectBloc should NOT have credentials
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        // It enters Attempting, but when SignalR reconnects, AttemptRejoin
        // will fail with no_credentials since Reset cleared them.
        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        connectionStateController.add(SignalRConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 100));

        // Rejoin attempt fails because credentials were cleared by Reset
        expect(
          reconnectBloc.state,
          const ReconnectStateFailed('no_credentials'),
        );
      },
    );

    test(
      'host disconnect with room:error(room_closed) → RoomBloc Closed',
      () async {
        // Guest in Active state
        roomBloc.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Server sends room:error with room_closed code (fatal)
        roomBloc.add(
          const RoomEventError(
            code: 'room_closed',
            message: 'Room has been closed',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Fatal error code → transitions to Closed
        expect(roomBloc.state, const RoomStateClosed('room_closed'));
      },
    );

    test(
      'guest_left from Active → peerStatus.away (host perspective)',
      () async {
        // Host is in Active state
        roomBloc.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'host',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        // Guest disconnects
        roomBloc.add(const RoomEventGuestLeft());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          roomBloc.state,
          const RoomStateActive(
            roomCode: 'ABC123',
            role: 'host',
            contentDescriptor: _testDescriptor,
            peerStatus: PeerStatus.away,
          ),
        );

        // Guest reconnects
        roomBloc.add(const RoomEventGuestReconnected());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          roomBloc.state,
          const RoomStateActive(
            roomCode: 'ABC123',
            role: 'host',
            contentDescriptor: _testDescriptor,
            peerStatus: PeerStatus.connected,
          ),
        );
      },
    );
  });
}
