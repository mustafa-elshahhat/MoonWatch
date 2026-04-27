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



class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockHttpClient extends Mock implements HttpClient {}


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

  group('guest_reconnect integration ', () {
    test(
      'SignalR drop → reconnect → rejoin invocation → room:joined → Success',
      () async {
        
        reconnectBloc.storeRoomCredentials('ABC123', 'guest');
        reconnectBloc.startListening();

        
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        
        connectionStateController.add(SignalRConnectionState.connected);
        await Future.delayed(const Duration(milliseconds: 100));

        
        verify(
          () => mockSignalRClient.invoke(
            RoomEvents.hubJoinRoom,
            args: ['ABC123', 'guest'],
          ),
        ).called(1);

        
        
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

        
        connectionStateController.add(SignalRConnectionState.reconnecting);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(
          reconnectBloc.state,
          const ReconnectStateAttempting(attemptNumber: 1),
        );

        
        connectionStateController.add(SignalRConnectionState.disconnected);
        await Future.delayed(const Duration(milliseconds: 50));

        expect(reconnectBloc.state, const ReconnectStateFailed('max_retries'));
      },
    );

    test('SignalR drop → reconnect → rejoin error → Failed', () async {
      reconnectBloc.storeRoomCredentials('ABC123', 'guest');
      reconnectBloc.startListening();

      
      connectionStateController.add(SignalRConnectionState.reconnecting);
      await Future.delayed(const Duration(milliseconds: 50));
      connectionStateController.add(SignalRConnectionState.connected);
      await Future.delayed(const Duration(milliseconds: 100));

      
      
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
      
      roomBloc.startListening();

      
      
      
      roomBloc.add(
        const RoomEventRoomJoined(
          roomCode: 'ABC123',
          role: 'guest',
          guestPresent: true,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      
      repoEventsController.add(const RoomEventRoomClosed('host_disconnected'));
      await Future.delayed(const Duration(milliseconds: 100));

      expect(roomBloc.state, const RoomStateClosed('host_disconnected'));
    });
  });
}
