import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/http_client.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/protocol/payloads.dart';
import 'package:watch_party/core/protocol/room_events.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';

const _testDescriptor = IptvContentDescriptor(
  contentType: IptvDescriptorType.live,
  streamId: '12345',
  title: 'Test Channel',
);

const _nextDescriptor = IptvContentDescriptor(
  contentType: IptvDescriptorType.episode,
  streamId: '67890',
  containerExtension: 'm3u8',
  title: 'Episode 2',
);

class MockHttpClient extends Mock implements HttpClient {}

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late MockSignalRClient mockSignalRClient;
  late MockRoomRepository mockRoomRepository;
  late StreamController<RoomEvent> repoEventsController;

  setUp(() {
    mockSignalRClient = MockSignalRClient();
    mockRoomRepository = MockRoomRepository();
    repoEventsController = StreamController<RoomEvent>.broadcast();

    when(
      () => mockRoomRepository.events,
    ).thenAnswer((_) => repoEventsController.stream);
    when(() => mockRoomRepository.registerHandlers()).thenReturn(null);
    when(() => mockSignalRClient.connect()).thenAnswer((_) async {});
    when(() => mockSignalRClient.ensureConnected()).thenAnswer((_) async {});
    when(() => mockSignalRClient.disconnect()).thenAnswer((_) async {});
    when(
      () => mockSignalRClient.invoke(any(), args: any(named: 'args')),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await repoEventsController.close();
  });

  RoomBloc buildBloc() => RoomBloc(
        roomRepository: mockRoomRepository,
        signalRClient: mockSignalRClient,
      );

  group('RoomBloc - CreateRoom', () {
    blocTest<RoomBloc, RoomState>(
      'emits Connecting, Creating then Waiting when host creates room successfully over SignalR',
      build: () {
        when(
          () => mockSignalRClient.ensureConnected(),
        ).thenAnswer((_) async {});
        when(
          () => mockSignalRClient.invoke(RoomEvents.hubCreateRoom),
        ).thenAnswer((_) async => null);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const RoomEventCreateRoom());
        await Future.delayed(const Duration(milliseconds: 50));
        repoEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'host',
            guestPresent: false,
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateWaiting(roomCode: 'ABC123', role: 'host'),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'emits Connecting then Error when SignalR connect fails during CreateRoom',
      build: () {
        when(
          () => mockSignalRClient.ensureConnected(),
        ).thenThrow(Exception('Connection failed'));
        return buildBloc();
      },
      act: (bloc) {
        bloc.add(const RoomEventCreateRoom());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const RoomStateConnecting(), isA<RoomStateError>()],
    );
  });

  group('RoomBloc - JoinRoom', () {
    blocTest<RoomBloc, RoomState>(
      'emits Connecting, Creating then Joined when guest joins successfully',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const RoomEventJoinRoom('ABC123'));
        await Future.delayed(const Duration(milliseconds: 50));
        repoEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateJoined(roomCode: 'ABC123', role: 'guest'),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'emits Connecting, Creating then Active when guest joins room with content',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const RoomEventJoinRoom('ABC123'));
        await Future.delayed(const Duration(milliseconds: 50));
        repoEventsController.add(
          const RoomEventRoomJoined(
            roomCode: 'ABC123',
            role: 'guest',
            guestPresent: true,
            contentDescriptor: _testDescriptor,
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _testDescriptor,
        ),
      ],
    );
  });

  group('RoomBloc - state transitions', () {
    blocTest<RoomBloc, RoomState>(
      'Waiting -> Joined on GuestJoined',
      build: buildBloc,
      seed: () => const RoomStateWaiting(roomCode: 'ABC123', role: 'host'),
      act: (bloc) {
        bloc.add(const RoomEventGuestJoined());
      },
      expect: () => [const RoomStateJoined(roomCode: 'ABC123', role: 'host')],
    );

    blocTest<RoomBloc, RoomState>(
      'Joined -> Active on ContentSet',
      build: buildBloc,
      seed: () => const RoomStateJoined(roomCode: 'ABC123', role: 'host'),
      act: (bloc) {
        bloc.add(const RoomEventContentSet(_testDescriptor));
      },
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'Waiting -> Active on ContentSet (content_set arrives while waiting - one-step transition)',
      build: buildBloc,
      seed: () => const RoomStateWaiting(roomCode: 'ABC123', role: 'host'),
      act: (bloc) {
        bloc.add(const RoomEventContentSet(_testDescriptor));
      },
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'Waiting -> Active on ContentSet for guest (single content_set is enough)',
      build: buildBloc,
      seed: () => const RoomStateWaiting(roomCode: 'ABC123', role: 'guest'),
      act: (bloc) {
        bloc.add(const RoomEventContentSet(_testDescriptor));
      },
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _testDescriptor,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'content switch resets readiness and completes when both peers ready for the new content',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'host',
        contentDescriptor: _testDescriptor,
        localReady: true,
        peerReady: true,
      ),
      act: (bloc) async {
        bloc.add(const RoomEventSetContent(_nextDescriptor));
        await Future.delayed(const Duration(milliseconds: 10));
        bloc.add(RoomEventLocalReady(_nextDescriptor.contentKey));
        bloc.add(
          RoomEventPlayerReady(
            PlayerReadyPayload(
              bothReady: false,
              readyRole: 'guest',
              serverTimestampMs: 1,
              contentKey: _nextDescriptor.contentKey,
            ),
          ),
        );
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _nextDescriptor,
          localReady: false,
          peerReady: false,
        ),
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _nextDescriptor,
          localReady: true,
          peerReady: false,
        ),
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _nextDescriptor,
          localReady: true,
          peerReady: true,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'ignores stale ready events for a previous content key',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'host',
        contentDescriptor: _nextDescriptor,
      ),
      act: (bloc) {
        bloc.add(RoomEventLocalReady(_testDescriptor.contentKey));
        bloc.add(
          RoomEventPlayerReady(
            PlayerReadyPayload(
              bothReady: true,
              readyRole: 'guest',
              serverTimestampMs: 1,
              contentKey: _testDescriptor.contentKey,
            ),
          ),
        );
      },
      expect: () => <RoomState>[],
    );

    blocTest<RoomBloc, RoomState>(
      'Active -> Active(peerAway) on GuestLeft',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'host',
        contentDescriptor: _testDescriptor,
      ),
      act: (bloc) {
        bloc.add(const RoomEventGuestLeft());
      },
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
          peerStatus: PeerStatus.away,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'Active(peerAway) -> Active(connected) on GuestReconnected',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'host',
        contentDescriptor: _testDescriptor,
        peerStatus: PeerStatus.away,
      ),
      act: (bloc) {
        bloc.add(const RoomEventGuestReconnected());
      },
      expect: () => [
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
          peerStatus: PeerStatus.connected,
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'Joined -> Waiting on GuestLeft',
      build: buildBloc,
      seed: () => const RoomStateJoined(roomCode: 'ABC123', role: 'host'),
      act: (bloc) {
        bloc.add(const RoomEventGuestLeft());
      },
      expect: () => [const RoomStateWaiting(roomCode: 'ABC123', role: 'host')],
    );

    blocTest<RoomBloc, RoomState>(
      'any state -> Closed on RoomClosed',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'guest',
        contentDescriptor: _testDescriptor,
      ),
      act: (bloc) {
        bloc.add(const RoomEventRoomClosed('host_disconnected'));
      },
      expect: () => [const RoomStateClosed('host_disconnected')],
    );

    blocTest<RoomBloc, RoomState>(
      'LeaveRoom disconnects and emits Closed',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'guest',
        contentDescriptor: _testDescriptor,
      ),
      act: (bloc) {
        bloc.add(const RoomEventLeaveRoom());
      },
      wait: const Duration(milliseconds: 50),
      expect: () => [const RoomStateClosed('user_left')],
      verify: (_) {
        verify(() => mockSignalRClient.invoke(any())).called(1);
        verify(() => mockSignalRClient.disconnect()).called(1);
      },
    );
  });

  group('RoomBloc - error paths', () {
    blocTest<RoomBloc, RoomState>(
      'room_not_found error event',
      build: buildBloc,
      seed: () => const RoomStateCreating(),
      act: (bloc) {
        bloc.add(
          const RoomEventError(
            code: 'room_not_found',
            message: 'Room does not exist',
          ),
        );
      },
      expect: () => [
        const RoomStateError(
          code: RoomErrorCode.roomNotFound,
          message: 'Room does not exist',
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'room_full error event',
      build: buildBloc,
      seed: () => const RoomStateCreating(),
      act: (bloc) {
        bloc.add(
          const RoomEventError(code: 'room_full', message: 'Room is full'),
        );
      },
      expect: () => [
        const RoomStateError(
          code: RoomErrorCode.roomFull,
          message: 'Room is full',
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'role_unauthorized error event',
      build: buildBloc,
      seed: () => const RoomStateActive(
        roomCode: 'ABC123',
        role: 'guest',
        contentDescriptor: _testDescriptor,
      ),
      act: (bloc) {
        bloc.add(
          const RoomEventError(
            code: 'role_unauthorized',
            message: 'Only the host can perform this action',
          ),
        );
      },
      expect: () => [
        const RoomStateError(
          code: RoomErrorCode.roleUnauthorized,
          message: 'Only the host can perform this action',
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'room:error during pending create completes the pending operation',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const RoomEventCreateRoom());
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          const RoomEventError(
            code: 'internal_error',
            message: 'Server failed to create room',
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateError(
          code: RoomErrorCode.internalError,
          message: 'Server failed to create room',
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'room:error during pending join emits the real server error and does not later emit timeout/internalError',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const RoomEventJoinRoom('MISSING'));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(
          const RoomEventError(
            code: 'room_not_found',
            message: 'Room does not exist',
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateError(
          code: RoomErrorCode.roomNotFound,
          message: 'Room does not exist',
        ),
      ],
    );

    blocTest<RoomBloc, RoomState>(
      'room:closed during pending join emits RoomStateClosed and does not later emit timeout/internalError',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const RoomEventJoinRoom('CLOSED'));
        await Future.delayed(const Duration(milliseconds: 50));
        bloc.add(const RoomEventRoomClosed('room_closed'));
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [
        const RoomStateConnecting(),
        const RoomStateCreating(),
        const RoomStateClosed('room_closed'),
      ],
    );
  });
}
