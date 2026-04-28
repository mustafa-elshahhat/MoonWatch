import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/core/theme/app_theme.dart';
import 'package:watch_party/shared/widgets/app_components.dart';

void main() {
  testWidgets('AppConfirmDialog presents clear leave and stay actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => AppConfirmDialog.show(
                  context,
                  title: 'Leave Room?',
                  message: 'Leaving will disconnect you from the room.',
                  confirmLabel: 'Leave',
                  cancelLabel: 'Stay',
                  confirmColor: Colors.red,
                  icon: Icons.exit_to_app_rounded,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Leave Room?'), findsOneWidget);
    expect(
      find.text('Leaving will disconnect you from the room.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Leave'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Stay'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Leave Room?'), findsNothing);
  });
}
