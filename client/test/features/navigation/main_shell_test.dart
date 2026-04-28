import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/navigation/screens/main_shell.dart';

void main() {
  testWidgets('mobile navigation exposes create room action', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/create': (_) => const Scaffold(body: Text('Create route')),
        },
        home: const MainShell(),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Create Room'), findsOneWidget);

    await tester.tap(find.byTooltip('Create Room'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Create route'), findsOneWidget);
  });
}
