import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/shared/widgets/error_overlay.dart';
import 'package:watch_party/features/room/domain/room_error_code.dart';

void main() {
  Widget buildTestWidget(RoomErrorCode code, {String message = ''}) {
    return MaterialApp(
      home: Scaffold(
        body: ErrorOverlay(code: code, message: message),
      ),
    );
  }

  group('ErrorOverlay', () {
    testWidgets('renders roomNotFound with user-facing strings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roomNotFound));

      expect(find.text('Room Not Found'), findsOneWidget);
      expect(
        find.text(
          'The room code you entered does not exist. Check the code and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Go Home'), findsOneWidget);
    });

    testWidgets('renders roomFull with user-facing strings', (tester) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roomFull));

      expect(find.text('Room Full'), findsOneWidget);
      expect(
        find.text(
          'This room already has a guest. Only two participants are allowed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders roomClosed with user-facing strings', (tester) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roomClosed));

      expect(find.text('Room Closed'), findsOneWidget);
      expect(find.text('The host has closed this room.'), findsOneWidget);
    });

    testWidgets('renders roleUnauthorized with user-facing strings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roleUnauthorized));

      expect(find.text('Unauthorized'), findsOneWidget);
      expect(find.text('Only the host can control playback.'), findsOneWidget);
    });

    testWidgets('renders roleInvalid with user-facing strings', (tester) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roleInvalid));

      expect(find.text('Invalid Role'), findsOneWidget);
      expect(find.text('Invalid role specified.'), findsOneWidget);
    });

    testWidgets('renders alreadyJoined with user-facing strings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.alreadyJoined));

      expect(find.text('Already in Room'), findsOneWidget);
      expect(find.text('You are already in a room.'), findsOneWidget);
    });

    testWidgets('renders streamUrlInvalid with user-facing strings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.streamUrlInvalid));

      expect(find.text('Invalid URL'), findsOneWidget);
      expect(
        find.text(
          'The stream URL must start with http://, https://, or rtsp://.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders internalError with user-facing strings', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.internalError));

      expect(find.text('Server Error'), findsOneWidget);
      expect(
        find.text('An unexpected error occurred. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('displays error icon', (tester) async {
      await tester.pumpWidget(buildTestWidget(RoomErrorCode.roomNotFound));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Go Home button navigates home', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorOverlay(code: RoomErrorCode.roomNotFound, message: ''),
          ),
        ),
      );

      expect(find.text('Go Home'), findsOneWidget);
    });

    testWidgets('no error code exposes internal strings', (tester) async {
      for (final code in RoomErrorCode.values) {
        await tester.pumpWidget(buildTestWidget(code));

        expect(find.text('room_not_found'), findsNothing);
        expect(find.text('room_full'), findsNothing);
        expect(find.text('role_unauthorized'), findsNothing);
        expect(find.text('internal_error'), findsNothing);
      }
    });
  });
}
