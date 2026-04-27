import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/player/player_controller.dart' as pc;
import 'package:watch_party/core/protocol/payloads.dart';
import 'package:watch_party/features/player/widgets/playback_controls.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/player/bloc/player_bloc.dart';
import 'package:watch_party/features/player/bloc/player_event.dart';
import 'package:watch_party/features/player/bloc/player_state.dart';

const _testDescriptor = IptvContentDescriptor(
  contentType: IptvDescriptorType.movie,
  streamId: '12345',
  title: 'Test Movie',
);

/// Minimal fake PlayerController for widget tests.
/// Returns Duration.zero for duration/position so the widget falls back to its
/// 4-hour live-stream fallback — no platform-specific media engine needed.
class _FakePlayerController extends Fake implements pc.PlayerController {
  @override
  Stream<pc.PlayerEvent> get events => const Stream<pc.PlayerEvent>.empty();

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get duration => const Duration(minutes: 90);

  @override
  bool get isPlaying => false;

  @override
  bool get isBuffering => false;

  @override
  bool get isInitialized => false;

  @override
  Widget? get nativeView => null;

  @override
  Future<void> initialize(String streamUrl) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> dispose() async {}
}

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockPlayerBloc extends MockBloc<PlayerEvent, PlayerState>
    implements PlayerBloc {}

void main() {
  late MockRoomBloc mockRoomBloc;
  late MockPlayerBloc mockPlayerBloc;

  setUp(() {
    mockRoomBloc = MockRoomBloc();
    mockPlayerBloc = MockPlayerBloc();
    GetIt.instance.registerSingleton<pc.PlayerController>(
      _FakePlayerController(),
    );
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider<RoomBloc>.value(value: mockRoomBloc),
            BlocProvider<PlayerBloc>.value(value: mockPlayerBloc),
          ],
          child: const PlaybackControls(),
        ),
      ),
    );
  }

  group('PlaybackControls', () {
    testWidgets('host sees play/pause button and seek slider', (tester) async {
      when(() => mockRoomBloc.state).thenReturn(
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
        ),
      );
      when(
        () => mockPlayerBloc.state,
      ).thenReturn(const PlayerStatePaused(Duration.zero));

      await tester.pumpWidget(buildTestWidget());

      // Host sees play button (rounded variant used in widget)
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // Host sees seek slider
      expect(find.byType(Slider), findsOneWidget);
    });

    testWidgets('host sees pause icon when playing', (tester) async {
      when(() => mockRoomBloc.state).thenReturn(
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'host',
          contentDescriptor: _testDescriptor,
        ),
      );
      when(
        () => mockPlayerBloc.state,
      ).thenReturn(const PlayerStatePlaying(Duration(seconds: 42)));

      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('guest sees position display only — no interactive controls', (
      tester,
    ) async {
      when(() => mockRoomBloc.state).thenReturn(
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _testDescriptor,
        ),
      );
      when(
        () => mockPlayerBloc.state,
      ).thenReturn(const PlayerStatePlaying(Duration(minutes: 2, seconds: 30)));

      await tester.pumpWidget(buildTestWidget());

      // Guest sees position text
      expect(find.text('02:30'), findsOneWidget);
      // Guest does not see play/pause button or slider
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('guest sees no interactive controls when paused', (
      tester,
    ) async {
      when(() => mockRoomBloc.state).thenReturn(
        const RoomStateActive(
          roomCode: 'ABC123',
          role: 'guest',
          contentDescriptor: _testDescriptor,
        ),
      );
      when(
        () => mockPlayerBloc.state,
      ).thenReturn(const PlayerStatePaused(Duration(seconds: 90)));

      await tester.pumpWidget(buildTestWidget());

      expect(find.text('01:30'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);
    });

    testWidgets('renders nothing when room state is not Active', (
      tester,
    ) async {
      when(() => mockRoomBloc.state).thenReturn(const RoomStateInitial());
      when(() => mockPlayerBloc.state).thenReturn(const PlayerStateIdle());

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });
  });
}
