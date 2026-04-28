import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import 'package:watch_party/core/player/player_controller.dart';
import 'package:watch_party/core/protocol/payloads.dart';
import 'package:watch_party/features/player/models/player_ui_context.dart';
import 'package:watch_party/features/player/models/video_fit_mode.dart';
import 'package:watch_party/features/player/widgets/player_gesture_layer.dart';
import 'package:watch_party/features/player/widgets/smart_playback_controls.dart';

void main() {
  final getIt = GetIt.instance;
  late MockPlayerImpl player;
  late VideoFitMode fitMode;
  late double brightness;
  late List<Duration> seekCalls;
  late List<double> brightnessCalls;

  PlayerUIContext hostContext() => PlayerUIContext.roomHost(
        contentType: IptvDescriptorType.movie,
        title: 'Movie',
      );

  PlayerUIContext guestContext() => PlayerUIContext.roomGuest(
        contentType: IptvDescriptorType.movie,
        title: 'Movie',
      );

  Widget buildLayer(PlayerUIContext uiContext) {
    return MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            return SizedBox.expand(
              child: PlayerGestureLayer(
                uiContext: uiContext,
                fitMode: fitMode,
                onFitModeChanged: (mode) => setState(() => fitMode = mode),
                onShowOverlays: () {},
                brightness: brightness,
                onBrightnessChanged: (value) {
                  brightnessCalls.add(value);
                  setState(() => brightness = value);
                },
                onSeek: seekCalls.add,
              ),
            );
          },
        ),
      ),
    );
  }

  setUp(() {
    player = MockPlayerImpl()
      ..setDuration(const Duration(minutes: 10))
      ..setPosition(const Duration(minutes: 1));
    fitMode = VideoFitMode.contain;
    brightness = 0.5;
    seekCalls = [];
    brightnessCalls = [];
    getIt.registerSingleton<PlayerController>(player);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('vertical right swipe changes volume and does not seek',
      (tester) async {
    await player.setVolume(0.5);
    await tester.pumpWidget(buildLayer(hostContext()));

    await tester.dragFrom(const Offset(700, 300), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 50));

    expect(player.volume, greaterThan(0.5));
    expect(seekCalls, isEmpty);
    expect(player.seekHistory, isEmpty);
  });

  testWidgets('vertical left swipe changes brightness and does not seek',
      (tester) async {
    await tester.pumpWidget(buildLayer(hostContext()));

    await tester.dragFrom(const Offset(100, 300), const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 50));

    expect(brightnessCalls, isNotEmpty);
    expect(brightness, greaterThan(0.5));
    expect(seekCalls, isEmpty);
    expect(player.seekHistory, isEmpty);
  });

  testWidgets('guest horizontal gesture never seeks', (tester) async {
    await tester.pumpWidget(buildLayer(guestContext()));

    await tester.dragFrom(const Offset(300, 300), const Offset(120, 0));
    await tester.pump(const Duration(milliseconds: 50));

    expect(seekCalls, isEmpty);
    expect(player.seekHistory, isEmpty);
  });

  testWidgets('host horizontal scrub sends only one seek on drag end',
      (tester) async {
    await tester.pumpWidget(buildLayer(hostContext()));

    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(40, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    expect(seekCalls, isEmpty);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));

    expect(seekCalls, hasLength(1));
    expect(seekCalls.single, greaterThan(const Duration(minutes: 1)));
  });

  testWidgets('double tap center toggles fit mode', (tester) async {
    await tester.pumpWidget(buildLayer(hostContext()));

    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(400, 300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(fitMode, VideoFitMode.cover);
    expect(find.text('Fill Screen'), findsOneWidget);
  });

  testWidgets('host double tap left and right seeks by ten seconds',
      (tester) async {
    await tester.pumpWidget(buildLayer(hostContext()));

    await tester.tapAt(const Offset(40, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(40, 300));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tapAt(const Offset(760, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(760, 300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(fitMode, VideoFitMode.contain);
    expect(seekCalls, [
      const Duration(seconds: 50),
      const Duration(minutes: 1, seconds: 10),
    ]);
    expect(find.text('+10s'), findsOneWidget);
  });

  testWidgets('guest double tap edges does not seek', (tester) async {
    await tester.pumpWidget(buildLayer(guestContext()));

    await tester.tapAt(const Offset(760, 300));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(760, 300));
    await tester.pump(const Duration(milliseconds: 50));

    expect(seekCalls, isEmpty);
    expect(player.seekHistory, isEmpty);
  });

  testWidgets('brightness slider uses provided brightness update path',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartPlaybackControls(
            uiContext: guestContext(),
            isPlaying: true,
            isPaused: false,
            canInteract: true,
            brightness: brightness,
            onBrightnessChanged: (value) {
              brightnessCalls.add(value);
              brightness = value;
            },
          ),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(
      find.byIcon(Icons.brightness_medium_rounded),
    ));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0.8);
    await tester.pump();

    expect(brightnessCalls, [0.8]);
  });

  testWidgets('guest local controls work but playback controls are blocked',
      (tester) async {
    final playCalls = <Duration>[];
    final pauseCalls = <Duration>[];
    final seekCalls = <Duration>[];
    final speedCalls = <double>[];
    await player.setVolume(0.5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartPlaybackControls(
            uiContext: guestContext(),
            isPlaying: true,
            isPaused: false,
            canInteract: true,
            onPlay: playCalls.add,
            onPause: pauseCalls.add,
            onSeek: seekCalls.add,
            onSpeedChanged: speedCalls.add,
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(playCalls, isEmpty);
    expect(pauseCalls, isEmpty);
    expect(seekCalls, isEmpty);
    expect(speedCalls, isEmpty);
    expect(player.volume, greaterThan(0.5));
  });

  testWidgets('host timeline tap commits a single seek', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SmartPlaybackControls(
            uiContext: hostContext(),
            isPlaying: true,
            isPaused: false,
            canInteract: true,
            onSeek: seekCalls.add,
          ),
        ),
      ),
    );

    final track = find.byKey(const Key('playback_timeline_track'));
    expect(track, findsOneWidget);

    final rect = tester.getRect(track);
    await tester.tapAt(Offset(rect.left + rect.width * 0.75, rect.center.dy));
    await tester.pump();

    expect(seekCalls, hasLength(1));
    expect(
      seekCalls.single.inMilliseconds,
      closeTo(const Duration(minutes: 7, seconds: 30).inMilliseconds, 500),
    );
  });
}
