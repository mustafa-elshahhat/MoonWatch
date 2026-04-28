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
import 'package:watch_party/features/room/domain/room_repository_event.dart';
import 'package:watch_party/features/room/domain/peer_status.dart';

const _testDescriptor = IptvContentDescriptor(
  contentType: IptvDescriptorType.live,
  streamId: '12345',
  title: 'Test Channel',
);

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockHttpClient extends Mock implements HttpClient {}

void main() {
  late MockSignalRClient mockSignalRClient;
  late MockRoomRepository mockRoomRepository;
  late StreamController<SignalRConnectionState> connectionStateController;
  late StreamController<RoomRepositoryEvent> repoEventsController;
  late ReconnectBloc reconnectBloc;
  late RoomBloc roomBloc;

  setUp(() {
    mockSignalRClient = MockSignalRClient();
    mockRoomRepository = MockRoomRepository();
    connectionStateController =
        StreamController<SignalRConnectionState>.broadcast();
    repoEventsController = StreamController<RoomRepositoryEvent>.broadcast();

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
    when(() => mockRoomRepository.unregisterHandlers()).thenReturn(null);

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

  group('host_disconnect integration ', () {
    test('host disconnects → guest RoomBloc transitions to Closed', () async {
      roomBloc.startListening();

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

      repoEventsController.add(const RepoEventRoomClosed('host_disconnected'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(roomBloc.state, const RoomStateClosed('host_disconnected'));
    });

    test(
      'host disconnects → ReconnectBloc reset prevents reconnection',
      () async {
        reconnectBloc.storeRoomCredentials('ABC123', 'guest');
        reconnectBloc.startListening();

        reconnectBloc.add(const ReconnectEventReset());
        await Future.delayed(const Duration(milliseconds: 50));

        expect(reconnectBloc.state, const ReconnectStateIdle());

        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        connectionStateController.add(SignalRConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(
          reconnectBloc.state,
          const ReconnectStateFailed('no_credentials'),
        );
      },
    );

    test(
      'host disconnect with room:error(room_closed) → RoomBloc Closed',
      () async {
        roomBloc.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        roomBloc.add(
          const RoomEventError(
            code: 'room_closed',
            message: 'Room has been closed',
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        expect(roomBloc.state, const RoomStateClosed('room_closed'));
      },
    );

    test(
      'guest_left from Active → peerStatus.away (host perspective)',
      () async {
        roomBloc.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'host',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

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
   group('host_disconnect integration', () {
      test('guest disconnects with grace period', () async {
        roomBloc.startListening();
        roomBloc.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'host',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 50));

        repoEventsController.add(const RepoEventGuestLeft());
        await Future.delayed(const Duration(milliseconds: 50));

        final state = roomBloc.state as RoomStateActive;
        expect(state.peerStatus, PeerStatus.away);

        repoEventsController.add(const RepoEventGuestReconnected());
        await Future.delayed(const Duration(milliseconds: 50));

        final state2 = roomBloc.state as RoomStateActive;
        expect(state2.peerStatus, PeerStatus.connected);
      });
    });
  });
}
