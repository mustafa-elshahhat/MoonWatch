import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/features/room/screens/join_room_screen.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/bloc/room_list_bloc.dart';

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockRoomListBloc extends MockBloc<RoomListEvent, RoomListState>
    implements RoomListBloc {}

void main() {
  late MockRoomBloc mockRoomBloc;
  late MockRoomListBloc mockRoomListBloc;

  setUpAll(() {
    
    
    registerFallbackValue(const RoomEventLeaveRoom());
    registerFallbackValue(const RoomListFetch());
  });

  setUp(() {
    mockRoomBloc = MockRoomBloc();
    mockRoomListBloc = MockRoomListBloc();
    when(() => mockRoomBloc.state).thenReturn(const RoomStateInitial());
    when(() => mockRoomListBloc.state).thenReturn(RoomListInitial());
  });

  Widget buildTestWidget() {
    return MaterialApp(
      routes: {'/watch': (_) => const Scaffold(body: Text('WatchScreen'))},
      home: MultiBlocProvider(
        providers: [
          BlocProvider<RoomBloc>.value(value: mockRoomBloc),
          BlocProvider<RoomListBloc>.value(value: mockRoomListBloc),
        ],
        child: const JoinRoomScreen(),
      ),
    );
  }

  group('JoinRoomScreen', () {
    testWidgets('renders room code input field and Join button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Connect to Room'), findsOneWidget);
    });

    testWidgets('shows error for empty input', (tester) async {
      
      
      
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect to Room'));
      await tester.pumpAndSettle();

      expect(find.text('Must be 6 characters'), findsOneWidget);
    });

    testWidgets('shows error for less than 6 characters', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'ABC');
      await tester.tap(find.text('Connect to Room'));
      await tester.pumpAndSettle();

      expect(find.text('Must be 6 characters'), findsOneWidget);
    });

    testWidgets('shows error for invalid characters (0, 1, I, O)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      
      await tester.enterText(find.byType(TextFormField), 'A01IOB');
      await tester.tap(find.text('Connect to Room'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid code format'), findsOneWidget);
    });

    testWidgets('valid 6-char code does not show error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'A3K9PX');
      await tester.tap(find.text('Connect to Room'));
      
      
      
      
      
      await tester.pump();

      
      expect(find.text('Must be 6 characters'), findsNothing);
      expect(find.text('Invalid code format'), findsNothing);
    });

    testWidgets('input enforces uppercase via textCapitalization', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      
      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textCapitalization, TextCapitalization.characters);
    });

    testWidgets('input has maxLength of 6', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 6);
    });
  });
}
