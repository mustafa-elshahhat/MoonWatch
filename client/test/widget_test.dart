import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/app.dart';
import 'package:watch_party/core/di/injection.dart';
import 'package:watch_party/core/config/app_config.dart';

void main() {
  testWidgets('App can be pumped with mock config', (WidgetTester tester) async {
    final mockConfig = AppConfig(
      serverBaseUrl: 'http://localhost',
      iptvBaseUrl: 'http://iptv',
    );
    
    await configureDependencies(appConfig: mockConfig);

    await tester.pumpWidget(const WatchPartyApp());

    expect(find.byType(WatchPartyApp), findsOneWidget);
  });
}
