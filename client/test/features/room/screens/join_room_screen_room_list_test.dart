import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_list_bloc.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/repository/room_repository.dart';
import 'package:watch_party/features/room/screens/join_room_screen.dart';

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockRoomRepository extends Mock implements RoomRepository {}

void main() {
  late MockRoomBloc mockRoomBloc;
  late MockRoomRepository mockRoomRepository;

  setUpAll(() {
    registerFallbackValue(const RoomEventJoinRoom('ABC123'));
  });

  setUp(() async {
    mockRoomBloc = MockRoomBloc();
    mockRoomRepository = MockRoomRepository();
    when(() => mockRoomBloc.state).thenReturn(const RoomStateInitial());
    when(() => mockRoomRepository.listRooms()).thenAnswer(
      (_) async => [
        {
          'roomCode': 'ABC123',
          'state': 'active',
          'hostConnected': true,
          'hasGuest': false,
          'createdAt': '2026-04-02T12:00:00Z',
        },
      ],
    );
  });

  Widget buildTestWidget() {
    return MaterialApp(
      routes: {
        '/watch': (_) => const Scaffold(body: Text('WatchScreen')),
        '/create': (_) => const Scaffold(body: Text('CreateRoomScreen')),
      },
      home: MultiBlocProvider(
        providers: [
          BlocProvider<RoomBloc>.value(value: mockRoomBloc),
          BlocProvider<RoomListBloc>(
            create: (_) => RoomListBloc(repository: mockRoomRepository),
          ),
        ],
        child: const JoinRoomScreen(),
      ),
    );
  }

  testWidgets('shows active rooms from backend', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('room available'), findsAtLeastNWidgets(1));
    expect(find.text('ABC123'), findsAtLeastNWidgets(1));
    expect(find.text('Waiting for guest'), findsAtLeastNWidgets(1));
  });

  testWidgets('tap room joins directly from the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final joinBtn = find.text('Join');
    expect(joinBtn, findsAtLeastNWidgets(1));
    await tester.tap(joinBtn.first);
    await tester.pump();

    verify(() => mockRoomBloc.add(const RoomEventJoinRoom('ABC123'))).called(1);
  });

  testWidgets('manual code entry still works', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'A3K9PX');
    await tester.pump();

    final connectBtn = find.byType(FilledButton);
    expect(connectBtn, findsOneWidget);
    await tester.tap(connectBtn);
    await tester.pump();

    verify(() => mockRoomBloc.add(const RoomEventJoinRoom('A3K9PX'))).called(1);
  });

  testWidgets('shows empty state when no joinable rooms exist', (tester) async {
    when(() => mockRoomRepository.listRooms()).thenAnswer((_) async => []);
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('No active rooms'), findsOneWidget);
    expect(
      find.text('No active rooms. Start one or join with a code.'),
      findsOneWidget,
    );
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });

  testWidgets('does not poll rooms while inactive, then polls when active', (
    tester,
  ) async {
    when(() => mockRoomRepository.listRooms()).thenAnswer((_) async => []);
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget host({required bool active}) {
      return MaterialApp(
        routes: {
          '/watch': (_) => const Scaffold(body: Text('WatchScreen')),
          '/create': (_) => const Scaffold(body: Text('CreateRoomScreen')),
        },
        home: MultiBlocProvider(
          providers: [
            BlocProvider<RoomBloc>.value(value: mockRoomBloc),
            BlocProvider<RoomListBloc>(
              create: (_) => RoomListBloc(repository: mockRoomRepository),
            ),
          ],
          child: JoinRoomScreen(isActive: active),
        ),
      );
    }

    await tester.pumpWidget(host(active: false));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));

    verifyNever(() => mockRoomRepository.listRooms());

    await tester.pumpWidget(host(active: true));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    verify(() => mockRoomRepository.listRooms())
        .called(greaterThanOrEqualTo(2));
  });

  testWidgets('shows retry on room list failure and can recover', (
    tester,
  ) async {
    var calls = 0;
    when(() => mockRoomRepository.listRooms()).thenAnswer((_) async {
      calls++;
      if (calls == 1) {
        throw Exception('boom');
      }
      return [
        {
          'roomCode': 'REC123',
          'state': 'waiting',
          'hostConnected': true,
          'hasGuest': false,
          'createdAt': '2026-04-02T12:00:00Z',
        },
      ];
    });

    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not load rooms'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('REC123'), findsAtLeastNWidgets(1));
  });
}
