class PlaybackUtils {
  static const List<double> supportedSpeeds = [
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
  ];

  /// Normalizes a playback speed to the nearest supported value.
  static double normalizeSpeed(double speed) {
    if (speed <= supportedSpeeds.first) return supportedSpeeds.first;
    if (speed >= supportedSpeeds.last) return supportedSpeeds.last;

    double bestMatch = supportedSpeeds.first;
    double minDiff = (speed - supportedSpeeds.first).abs();

    for (final s in supportedSpeeds) {
      final diff = (speed - s).abs();
      if (diff < minDiff) {
        minDiff = diff;
        bestMatch = s;
      }
    }

    return bestMatch;
  }
}
