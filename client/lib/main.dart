import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'core/di/injection.dart';
import 'core/logging/app_logger.dart';
import 'core/config/app_config.dart';
import 'features/auth/screens/config_missing_screen.dart';
import 'app.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      GoogleFonts.config.allowRuntimeFetching = false;
      await _configureAndroidSystemBars();
      final startTime = DateTime.now();
      debugPrint('[PROFILER] app_start: ${startTime.toIso8601String()}');

      AppConfig? appConfig;
      String? configError;

      try {
        appConfig = await AppConfig.load();
      } catch (e) {
        configError = e.toString();
      }

      if (appConfig != null) {
        await configureDependencies(appConfig: appConfig);
      }

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

      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger('FlutterError').e(
          'Framework error: ${details.exceptionAsString()}',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppLogger(
          'UncaughtError',
        ).e('Unhandled platform error', error: error, stackTrace: stack);
        return true;
      };

      if (appConfig == null) {
        runApp(MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ConfigMissingScreen(error: configError),
        ));
      } else {
        runApp(const WatchPartyApp());
      }
    },
    (Object error, StackTrace stack) {
      AppLogger(
        'ZoneError',
      ).e('Uncaught zone error', error: error, stackTrace: stack);
    },
  );
}

Future<void> _configureAndroidSystemBars() async {
  if (!Platform.isAndroid) return;

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}
