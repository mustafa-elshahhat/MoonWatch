import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/core/logging/app_logger.dart';

void main() {
  group('AppLogger URL sanitizing', () {
    test('redacts movie, series, live, generic live, and API credentials', () {
      final cases = {
        'http://iptv.test/movie/user/pass/42.m3u8':
            'http://iptv.test/movie/****/****/42.m3u8',
        'http://iptv.test/series/user/pass/42.mkv':
            'http://iptv.test/series/****/****/42.mkv',
        'http://iptv.test/live/user/pass/42.ts':
            'http://iptv.test/live/****/****/42.ts',
        'http://iptv.test/user/pass/42': 'http://iptv.test/****/****/42',
        'http://iptv.test/player_api.php?username=user&password=pass&action=get_live_streams':
            'http://iptv.test/player_api.php?username=****&password=****&action=get_live_streams',
      };

      for (final entry in cases.entries) {
        expect(AppLogger.sanitizeUrl(entry.key), entry.value);
      }
    });

    test('redacts base-path Xtream credentials', () {
      expect(
        AppLogger.sanitizeUrl('http://iptv.test/base/movie/user/pass/42.m3u8'),
        'http://iptv.test/base/movie/****/****/42.m3u8',
      );
      expect(
        AppLogger.sanitizeUrl('http://iptv.test/base/user/pass/42'),
        'http://iptv.test/base/****/****/42',
      );
    });

    test('media log sanitizing redacts HLS query strings', () {
      final sanitized = AppLogger.sanitizeMediaLog(
        'Failed to open segment http://cdn.test/hls/user/pass/seg.ts?token=abc&expires=123',
      );

      expect(sanitized, isNot(contains('user')));
      expect(sanitized, isNot(contains('pass')));
      expect(sanitized, isNot(contains('abc')));
      expect(sanitized, contains('token=****'));
      expect(sanitized, contains('expires=****'));
    });
  });
}
