import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/player/player_controller.dart' as pc;
import 'package:watch_party/core/protocol/payloads.dart';
import 'package:watch_party/features/iptv/repository/iptv_repository.dart';
import 'package:watch_party/features/player/bloc/player_bloc.dart';
import 'package:watch_party/features/player/bloc/player_event.dart';
import 'package:watch_party/features/player/bloc/player_state.dart';
import 'package:watch_party/features/player/screens/watch_screen.dart';
import 'package:watch_party/features/reconnect/reconnect_bloc.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/features/sync/latency_estimator.dart';
import 'package:watch_party/features/sync/sync_engine.dart';

const _contentA = IptvContentDescriptor(
  contentType: IptvDescriptorType.episode,
  streamId: '197312',
  containerExtension: 'm3u8',
  title: 'Episode A',
);

const _contentB = IptvContentDescriptor(
  contentType: IptvDescriptorType.episode,
  streamId: '928875',
  containerExtension: 'm3u8',
  title: 'Episode B',
);

class _FakePlayerController extends Fake implements pc.PlayerController {
  @override
  Stream<pc.PlayerEvent> get events => const Stream<pc.PlayerEvent>.empty();

  @override
  Stream<Duration> get durationStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get duration => Duration.zero;

  @override
  bool get isPlaying => false;

  @override
  bool get isBuffering => false;

  @override
  bool get isInitialized => false;

  @override
  Widget? get nativeView => null;

  @override
  Widget? buildVideoView({BoxFit fit = BoxFit.contain}) => null;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize(String streamUrl) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}
}

class _FakeLatencyEstimator extends LatencyEstimator {
  _FakeLatencyEstimator() : super(signalRClient: MockSignalRClient());

  @override
  void start() {}

  @override
  void stop() {}
}

class MockSignalRClient extends Mock implements SignalRClient {}

class MockRoomRepository extends Mock implements RoomRepository {}

class MockIptvRepository extends Mock implements IptvRepository {}

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

class MockSyncBloc extends MockBloc<SyncEvent, SyncState> implements SyncBloc {}

class MockReconnectBloc extends MockBloc<ReconnectEvent, ReconnectState>
    implements ReconnectBloc {}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(const RoomEventLeaveRoom());
    registerFallbackValue(const PlayerEventDispose());
    registerFallbackValue(const SyncEventPlayerReady());
    registerFallbackValue(const ReconnectEventReset());
    registerFallbackValue(_contentA);
  });

  late MockRoomBloc roomBloc;
  late MockPlayerBloc playerBloc;
  late MockSyncBloc syncBloc;
  late MockReconnectBloc reconnectBloc;
  late MockRoomRepository roomRepository;
  late MockIptvRepository iptvRepository;

  setUp(() {
    roomBloc = MockRoomBloc();
    playerBloc = MockPlayerBloc();
    syncBloc = MockSyncBloc();
    reconnectBloc = MockReconnectBloc();
    roomRepository = MockRoomRepository();
    iptvRepository = MockIptvRepository();

    when(
      () => roomRepository.invokePlay(any(), any()),
    ).thenAnswer((_) async {});
    when(() => roomRepository.invokePause(any())).thenAnswer((_) async {});
    when(() => roomRepository.invokeSeek(any())).thenAnswer((_) async {});
    when(() => roomRepository.events).thenAnswer((_) => const Stream.empty());

    when(() => iptvRepository.resolvePlaybackUrl(any())).thenAnswer((
      invocation,
    ) {
      final descriptor =
          invocation.positionalArguments.first as IptvContentDescriptor;
      return 'https://example.com/${descriptor.streamId}.m3u8';
    });

    when(() => playerBloc.state).thenReturn(const PlayerStateIdle());
    when(() => playerBloc.setRoomMode(any())).thenReturn(null);
    when(() => playerBloc.clearDedupState()).thenReturn(null);

    when(() => syncBloc.state).thenReturn(const SyncStateIdle());
    when(() => syncBloc.setRole(any())).thenReturn(null);
    when(() => syncBloc.updateGuestRtt(any())).thenReturn(null);
    when(() => syncBloc.updateClockOffset(any())).thenReturn(null);
    when(
      () =>
          syncBloc.setPlayerReady(any(), contentKey: any(named: 'contentKey')),
    ).thenReturn(null);

    when(() => reconnectBloc.state).thenReturn(const ReconnectStateIdle());
    when(
      () => reconnectBloc.storeRoomCredentials(any(), any()),
    ).thenReturn(null);
    when(() => reconnectBloc.startListening()).thenReturn(null);

    getIt.registerSingleton<pc.PlayerController>(_FakePlayerController());
    getIt.registerSingleton<RoomRepository>(roomRepository);
    getIt.registerSingleton<LatencyEstimator>(_FakeLatencyEstimator());
    getIt.registerSingleton<IptvRepository>(iptvRepository);
    getIt.registerFactory<PlayerBloc>(() => playerBloc);
    getIt.registerFactory<SyncBloc>(() => syncBloc);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<RoomBloc>.value(value: roomBloc),
          BlocProvider<ReconnectBloc>.value(value: reconnectBloc),
        ],
        child: const WatchScreen(),
      ),
    );
  }

  testWidgets('initial active room state initializes content once', (
    tester,
  ) async {
    const active = RoomStateActive(
      roomCode: 'ABC123',
      role: 'guest',
      contentDescriptor: _contentA,
    );

    when(() => roomBloc.state).thenReturn(active);
    whenListen(roomBloc, const Stream<RoomState>.empty(), initialState: active);
    whenListen(
      playerBloc,
      const Stream<PlayerState>.empty(),
      initialState: const PlayerStateIdle(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncStateIdle(),
    );
    whenListen(
      reconnectBloc,
      const Stream<ReconnectState>.empty(),
      initialState: const ReconnectStateIdle(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pump();

    final captured = verify(() => playerBloc.add(captureAny())).captured;
    final initializeEvents = captured
        .whereType<PlayerEventInitialize>()
        .toList();
    expect(initializeEvents, hasLength(1));
    expect(initializeEvents.single.contentKey, _contentA.contentKey);
  });

  testWidgets(
    'repeated identical active states do not dispatch a duplicate initialize',
    (tester) async {
      when(
        () => roomBloc.state,
      ).thenReturn(const RoomStateJoined(roomCode: 'ABC123', role: 'guest'));
      whenListen(
        roomBloc,
        Stream<RoomState>.fromIterable([
          const RoomStateActive(
            roomCode: 'ABC123',
            role: 'guest',
            contentDescriptor: _contentA,
          ),
          const RoomStateActive(
            roomCode: 'ABC123',
            role: 'guest',
            contentDescriptor: _contentA,
            localReady: true,
          ),
        ]),
        initialState: const RoomStateJoined(roomCode: 'ABC123', role: 'guest'),
      );
      whenListen(
        playerBloc,
        const Stream<PlayerState>.empty(),
        initialState: const PlayerStateIdle(),
      );
      whenListen(
        syncBloc,
        const Stream<SyncState>.empty(),
        initialState: const SyncStateIdle(),
      );
      whenListen(
        reconnectBloc,
        const Stream<ReconnectState>.empty(),
        initialState: const ReconnectStateIdle(),
      );

      await tester.pumpWidget(buildWidget());
      await tester.pump();
      await tester.pump();

      final captured = verify(() => playerBloc.add(captureAny())).captured;
      final initializeEvents = captured
          .whereType<PlayerEventInitialize>()
          .toList();
      expect(initializeEvents, hasLength(1));
      expect(initializeEvents.single.contentKey, _contentA.contentKey);
    },
  );

  testWidgets('different content keys each dispatch exactly one initialize', (
    tester,
  ) async {
    when(() => roomBloc.state).thenReturn(const RoomStateInitial());
    whenListen(
      roomBloc,
      Stream<RoomState>.fromIterable([
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _contentA,
        ),
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _contentA,
          peerReady: true,
        ),
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _contentB,
        ),
      ]),
      initialState: const RoomStateInitial(),
    );
    whenListen(
      playerBloc,
      const Stream<PlayerState>.empty(),
      initialState: const PlayerStateIdle(),
    );
    whenListen(
      syncBloc,
      const Stream<SyncState>.empty(),
      initialState: const SyncStateIdle(),
    );
    whenListen(
      reconnectBloc,
      const Stream<ReconnectState>.empty(),
      initialState: const ReconnectStateIdle(),
    );

    await tester.pumpWidget(buildWidget());
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final captured = verify(() => playerBloc.add(captureAny())).captured;
    final initializeEvents = captured
        .whereType<PlayerEventInitialize>()
        .toList();
    expect(initializeEvents.map((event) => event.contentKey).toList(), [
      _contentA.contentKey,
      _contentB.contentKey,
    ]);
  });
}
