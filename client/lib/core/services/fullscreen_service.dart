import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Platform-aware fullscreen manager.
/// - Mobile: immersive mode + landscape orientation.
/// - Desktop: window_manager fullscreen.
class FullscreenService extends ChangeNotifier {
  bool _isFullscreen = false;
  bool _wasMaximized = false;
  bool get isFullscreen => _isFullscreen;

  static final FullscreenService _instance = FullscreenService._();
  factory FullscreenService() => _instance;
  FullscreenService._();

  Future<void> enterFullscreen() async {
    if (_isFullscreen) return;
    _isFullscreen = true;
    notifyListeners();

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        // Remove all padding and overlays for true fullscreen.
        // systemNavigationBarContrastEnforced: false prevents Android 12+
        // from adding an automatic scrim behind the navigation bar.
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarBrightness: Brightness.dark,
          ),
        );
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        _wasMaximized = await windowManager.isMaximized();
        if (_wasMaximized) {
          await windowManager.unmaximize();
          // Small delay to let the OS apply the unmaximize bounds before going fullscreen
          await Future.delayed(const Duration(milliseconds: 50));
        }
        await windowManager.setFullScreen(true);
      }
    } catch (_) {
      _isFullscreen = false;
      notifyListeners();
    }
  }

  Future<void> exitFullscreen() async {
    if (!_isFullscreen) return;
    _isFullscreen = false;
    notifyListeners();

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await windowManager.setFullScreen(false);
        if (_wasMaximized) {
          await Future.delayed(const Duration(milliseconds: 50));
          await windowManager.maximize();
        }
      }
    } catch (_) {
      _isFullscreen = true;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_isFullscreen) {
      await exitFullscreen();
    } else {
      await enterFullscreen();
    }
  }
}
