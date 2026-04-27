import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/features/room/screens/join_room_screen.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

void main() {
  late MockRoomBloc mockRoomBloc;

  setUpAll(() {
    // Use a concrete RoomEvent subclass — RoomEvent is sealed and cannot be
    // extended or implemented outside its defining library.
    registerFallbackValue(const RoomEventLeaveRoom());
  });

  setUp(() {
    mockRoomBloc = MockRoomBloc();
    when(() => mockRoomBloc.state).thenReturn(const RoomStateInitial());
  });

  Widget buildTestWidget() {
    return MaterialApp(
      routes: {'/watch': (_) => const Scaffold(body: Text('WatchScreen'))},
      home: BlocProvider<RoomBloc>.value(
        value: mockRoomBloc,
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
      // The JoinRoomScreen has an active-rooms section above the manual entry
      // form, pushing the Join button below the default 800Ã—600 test surface.
      // Expand the surface so the full screen fits without scrolling.
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

      // '0' and '1' are not in the allowed character set [A-Z2-9]
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
      // Use pump() instead of pumpAndSettle() — a valid code triggers
      // _joinRoom() which sets _joining=true and shows a CircularProgressIndicator.
      // That animated widget prevents pumpAndSettle from ever settling.
      // Validation is synchronous so a single pump is enough to render the
      // updated form state and assert that no error text is shown.
      await tester.pump();

      // No validation errors should appear
      expect(find.text('Must be 6 characters'), findsNothing);
      expect(find.text('Invalid code format'), findsNothing);
    });

    testWidgets('input enforces uppercase via textCapitalization', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // The underlying TextField must have textCapitalization.characters.
      // TextFormField doesn't expose this as a getter; inspect the TextField child.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.textCapitalization, TextCapitalization.characters);
    });

    testWidgets('input has maxLength of 6', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // The underlying TextField must have maxLength set to 6.
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 6);
    });
  });
}
