import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'app.dart';

void main() {
  // runZonedGuarded must wrap ALL initialization including
  // WidgetsFlutterBinding.ensureInitialized() so that both the binding
  // initialization and runApp execute in the same zone.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      GoogleFonts.config.allowRuntimeFetching = false;
      final startTime = DateTime.now();
      debugPrint('[PROFILER] app_start: ${startTime.toIso8601String()}');

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('[PROFILER] first_frame_rendered: ${elapsed}ms');

        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await windowManager.ensureInitialized();
        }
        await AppLogger.init();
        AppLogger(
          'Main',
        ).i('App fully started after first frame ($elapsed ms)');
      });

      configureDependencies();

      // Capture Flutter framework errors (widget build errors, rendering errors).
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger('FlutterError').e(
          'Framework error: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      // Capture uncaught platform-dispatcher errors (belt-and-suspenders alongside
      // the runZonedGuarded error handler below).
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLogger(
          'UncaughtError',
        ).e('Unhandled platform error', error: error, stackTrace: stack);
        return true;
      };

      runApp(const WatchPartyApp());
    },
    (Object error, StackTrace stack) {
      AppLogger(
        'ZoneError',
      ).e('Uncaught zone error', error: error, stackTrace: stack);
    },
  );
}
