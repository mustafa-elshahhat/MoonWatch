// Basic smoke test: verify the app renders the home screen without crashing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/app.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const WatchPartyApp());
    // App renders at least one widget
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
