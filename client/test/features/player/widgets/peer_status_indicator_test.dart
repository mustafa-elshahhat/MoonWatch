import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/core/theme/app_colors.dart';
import 'package:watch_party/features/player/widgets/peer_status_indicator.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';

void main() {
  Widget buildTestWidget(PeerStatus status) {
    return MaterialApp(
      home: Scaffold(body: PeerStatusIndicator(status: status)),
    );
  }

  group('PeerStatusIndicator', () {
    testWidgets('renders green dot and "Peer connected" for connected status', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(PeerStatus.connected));

      expect(find.text('Peer connected'), findsOneWidget);
      // Find the dot Container inside PeerStatusIndicator (last Container = dot)
      final dotFinder = find.descendant(
        of: find.byType(PeerStatusIndicator),
        matching: find.byType(Container),
      );
      final dot = tester.widget<Container>(dotFinder.last);
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, AppColors.peerConnected);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('renders spinner and "Peer buffering" for buffering status', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(PeerStatus.buffering));

      expect(find.text('Peer buffering'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders grey dot and "Peer away" for away status', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(PeerStatus.away));

      expect(find.text('Peer away'), findsOneWidget);
      // Find the dot Container inside PeerStatusIndicator (last Container = dot)
      final dotFinder = find.descendant(
        of: find.byType(PeerStatusIndicator),
        matching: find.byType(Container),
      );
      final dot = tester.widget<Container>(dotFinder.last);
      final decoration = dot.decoration as BoxDecoration;
      expect(decoration.color, AppColors.peerAway);
      expect(decoration.shape, BoxShape.circle);
    });
  });
}
