import 'package:flutter/material.dart';



enum VideoFitMode {
  
  contain,

  
  cover,

  
  fill,
}

extension VideoFitModeX on VideoFitMode {
  
  BoxFit get boxFit {
    return switch (this) {
      VideoFitMode.contain => BoxFit.contain,
      VideoFitMode.cover => BoxFit.cover,
      VideoFitMode.fill => BoxFit.fill,
    };
  }

  
  String get label {
    return switch (this) {
      VideoFitMode.contain => 'Fit',
      VideoFitMode.cover => 'Fill',
      VideoFitMode.fill => 'Stretch',
    };
  }

  
  IconData get icon {
    return switch (this) {
      VideoFitMode.contain => Icons.fit_screen_rounded,
      VideoFitMode.cover => Icons.crop_rounded,
      VideoFitMode.fill => Icons.aspect_ratio_rounded,
    };
  }

  
  VideoFitMode get next {
    return switch (this) {
      VideoFitMode.contain => VideoFitMode.cover,
      VideoFitMode.cover => VideoFitMode.fill,
      VideoFitMode.fill => VideoFitMode.contain,
    };
  }
}
