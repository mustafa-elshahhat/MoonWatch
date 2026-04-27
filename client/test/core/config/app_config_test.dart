import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/core/config/app_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig', () {
    void mockConfig(Map<String, dynamic> config) {
      const key = 'assets/config/appsettings.local.json';
      
      // Clear cache to ensure the mock is used
      rootBundle.evict(key);
      
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (message) async {
        // The message is the asset path (encoded)
        // But for loadString, it sends the key
        final Uint8List encoded = utf8.encoder.convert(jsonEncode(config));
        return encoded.buffer.asByteData();
      });
    }

    test('loads valid config', () async {
      mockConfig({
        'serverBaseUrl': 'https://api.test/',
        'iptvBaseUrl': 'http://iptv.test'
      });

      final config = await AppConfig.load();

      expect(config.serverBaseUrl, 'https://api.test');
      expect(config.iptvBaseUrl, 'http://iptv.test');
    });

    test('rejects missing serverBaseUrl', () async {
      mockConfig({
        'iptvBaseUrl': 'http://iptv.test'
      });

      expect(AppConfig.load(), throwsA(isA<Exception>()));
    });

    test('rejects invalid URL', () async {
      mockConfig({
        'serverBaseUrl': 'not-a-url',
        'iptvBaseUrl': 'http://iptv.test'
      });

      expect(AppConfig.load(), throwsA(isA<Exception>()));
    });
  });
}
