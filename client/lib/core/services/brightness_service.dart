import 'package:screen_brightness/screen_brightness.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class BrightnessService {
  double? _originalBrightness;

  Future<void> initialize() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    try {
      _originalBrightness = await ScreenBrightness().application;
    } catch (_) {
      // Fail silently on unsupported platforms or errors
    }
  }

  Future<void> setBrightness(double value) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    try {
      await ScreenBrightness()
          .setApplicationScreenBrightness(value.clamp(0.0, 1.0));
    } catch (_) {
      // Fail silently
    }
  }

  Future<void> restore() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux) return;
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness()
            .setApplicationScreenBrightness(_originalBrightness!);
      } else {
        await ScreenBrightness().resetApplicationScreenBrightness();
      }
    } catch (_) {
      // Fail silently
    }
  }
}
