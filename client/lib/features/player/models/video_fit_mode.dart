import 'package:flutter/material.dart';

/// Video viewport fit modes — controls how the video frame maps to the
/// available screen area. Purely a presentation/rendering concern.
enum VideoFitMode {
  /// Video is fully visible with letterbox/pillarbox bars if needed.
  contain,

  /// Video fills the entire area; edges may be cropped to maintain aspect ratio.
  cover,

  /// Video is stretched to fill the area; aspect ratio is not preserved.
  fill,
}

extension VideoFitModeX on VideoFitMode {
  /// Converts to the Flutter [BoxFit] value used by the media_kit Video widget.
  BoxFit get boxFit {
    return switch (this) {
      VideoFitMode.contain => BoxFit.contain,
      VideoFitMode.cover => BoxFit.cover,
      VideoFitMode.fill => BoxFit.fill,
    };
  }

  /// Human-readable display label.
  String get label {
    return switch (this) {
      VideoFitMode.contain => 'Fit',
      VideoFitMode.cover => 'Fill',
      VideoFitMode.fill => 'Stretch',
    };
  }

  /// Icon to represent this mode in the player control bar.
  IconData get icon {
    return switch (this) {
      VideoFitMode.contain => Icons.fit_screen_rounded,
      VideoFitMode.cover => Icons.crop_rounded,
      VideoFitMode.fill => Icons.aspect_ratio_rounded,
    };
  }

  /// The next mode in the cycle: contain → cover → fill → contain.
  VideoFitMode get next {
    return switch (this) {
      VideoFitMode.contain => VideoFitMode.cover,
      VideoFitMode.cover => VideoFitMode.fill,
      VideoFitMode.fill => VideoFitMode.contain,
    };
  }
}
