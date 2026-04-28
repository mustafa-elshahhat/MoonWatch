import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';

void main() {
  group('MockPlayerImpl Volume & Clamping Tests', () {
    late MockPlayerImpl player;

    setUp(() {
      player = MockPlayerImpl();
    });

    test('Initial volume should be 1.0', () {
      expect(player.volume, 1.0);
    });

    test('setVolume should clamp values', () async {
      await player.setVolume(1.5);
      expect(player.volume, 1.0);

      await player.setVolume(-0.5);
      expect(player.volume, 0.0);
    });

    test('setVolume emits clamped values to volume stream', () async {
      final emitted = <double>[];
      final sub = player.volumeStream.listen(emitted.add);

      await player.setVolume(1.5);
      await player.setVolume(-0.5);

      expect(emitted, [1.0, 0.0]);
      await sub.cancel();
    });

    test('Mute behavior should remember last non-zero volume', () async {
      await player.setVolume(0.7);
      expect(player.volume, 0.7);
      expect(player.lastNonZeroVolume, 0.7);

      await player.setVolume(0.0);
      expect(player.volume, 0.0);
      expect(player.lastNonZeroVolume, 0.7);

      // Restore
      await player.setVolume(player.lastNonZeroVolume);
      expect(player.volume, 0.7);
    });

    test('Double mute should not lose last non-zero volume', () async {
      await player.setVolume(0.8);
      await player.setVolume(0.0);
      expect(player.lastNonZeroVolume, 0.8);

      await player.setVolume(0.0);
      expect(player.lastNonZeroVolume, 0.8);
    });
  });
}
