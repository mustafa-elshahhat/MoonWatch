import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized logging service for the WatchParty client.
///
/// Writes all log entries to both the console and a text file.
///
/// Android/iOS: logs to app-specific external storage (user-visible in the
///   device Files app) under a folder named "Watch Party Logs".
///   Path example:
///     /storage/emulated/0/Android/data/`package`/files/Watch Party Logs/log.txt
///   Falls back to internal app-documents directory if external storage is
///   unavailable.
///
/// Desktop (Windows/Linux/macOS): logs to `D:\projects\WATCH_PARTY\logs\`.
///
/// The log file (log.txt) is deleted and recreated on every app launch so
/// each session starts with a completely fresh file.
///
/// Usage:
/// ```dart
/// final _log = AppLogger('RoomBloc');
/// _log.i('Room created', event: 'room.created');
/// ```
class AppLogger {
  // —— Constants ————————————————————————————————————————————————————————————

  static const String _desktopLogDir = r'D:\projects\WATCH_PARTY\logs';
  static const String _logFolderName = 'Watch Party Logs';
  static const String _logFileName = 'log.txt';

  // Regex that matches Xtream Codes URL path credentials.
  // Matches: scheme://host/(live|movie|series)/USERNAME/PASSWORD/rest
  static final RegExp _pathCredentialsRe = RegExp(
    r'(https?://[^/]+)/(live|movie|series)/([^/?#]+)/([^/?#]+)/(.+)',
    caseSensitive: false,
  );

  // Regex that matches credential query parameters.
  // Matches: username=VALUE or password=VALUE anywhere in a query string.
  static final RegExp _queryUsernameRe = RegExp(
    r'(username=)[^&]+',
    caseSensitive: false,
  );
  static final RegExp _queryPasswordRe = RegExp(
    r'(password=)[^&]+',
    caseSensitive: false,
  );

  // —— Static state —————————————————————————————————————————————————————————

  static String? _logFilePath;
  static IOSink? _fileSink;
  static bool _initialized = false;
  static String _platform = 'unknown';

  // —— Instance state ———————————————————————————————————————————————————————

  final String tag;
  final Logger _logger;

  AppLogger(this.tag)
      : _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 100,
            noBoxingByDefault: true,
          ),
          filter: ProductionFilter(),
        );

  // —— Initialization ———————————————————————————————————————————————————————

  /// Initialize the file logging system. Must be called once at app startup
  /// before any logging occurs. Deletes any previous log file and starts fresh.
  static Future<void> init() async {
    if (_initialized) return;

    _platform = _detectPlatform();

    try {
      final logDir = await _resolveLogDir();
      final dir = Directory(logDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      _logFilePath = '${dir.path}${Platform.pathSeparator}$_logFileName';

      // Delete previous session log so each launch starts completely fresh.
      final file = File(_logFilePath!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {
          // File locked by a previous instance — open in write/truncate mode
          // instead; the content will be overwritten on the first write.
        }
      }

      _fileSink = file.openWrite(mode: FileMode.write);
      _initialized = true;

      // Write session header.
      final now = _formatTimestamp(DateTime.now());
      const buildMode = kDebugMode
          ? 'debug'
          : kProfileMode
              ? 'profile'
              : 'release';

      _fileSink!.writeln(
        'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•',
      );
      _fileSink!.writeln('  WatchParty Client — session start');
      _fileSink!.writeln('  Platform : ${_platform.toUpperCase()}');
      _fileSink!.writeln('  Build    : $buildMode');
      _fileSink!.writeln('  Log file : $_logFilePath');
      _fileSink!.writeln('  Started  : $now');
      _fileSink!.writeln(
        'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•',
      );
      _fileSink!.writeln('');
      await _fileSink!.flush();
    } catch (e) {
      // Logging init failure must not crash the app.
      // Fall back to console-only for this session.
      debugPrint('[AppLogger] Failed to initialize file logging: $e');
    }
  }

  /// Flush and close the file sink. Call on app shutdown.
  static Future<void> shutdown() async {
    if (!_initialized) return;
    try {
      final now = _formatTimestamp(DateTime.now());
      _fileSink?.writeln('');
      _fileSink?.writeln(
        'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•',
      );
      _fileSink?.writeln('  Session end: $now');
      _fileSink?.writeln(
        'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•',
      );
      await _fileSink?.flush();
      await _fileSink?.close();
    } catch (_) {
      // Best-effort shutdown.
    }
    _fileSink = null;
    _initialized = false;
  }

  // —— URL sanitization —————————————————————————————————————————————————————

  /// Returns a sanitized copy of [url] safe to write to a log file.
  ///
  /// Masks credentials in both Xtream Codes URL path format and in query
  /// parameters so that no username or password reaches the log file.
  ///
  /// Examples:
  ///   http://host/live/Alice/secret99/123.ts
  ///     → http://host/live/****/****/123.ts
  ///
  ///   http://host/player_api.php?username=Alice&password=secret99&action=get
  ///     → http://host/player_api.php?username=****&password=****&action=get
  static String sanitizeUrl(String url) {
    // 1. Mask path-segment credentials (Xtream Codes stream URLs).
    String result = url.replaceFirstMapped(_pathCredentialsRe, (m) {
      // m.group(1) = scheme://host
      // m.group(2) = live|movie|series
      // m.group(3) = username  (masked)
      // m.group(4) = password  (masked)
      // m.group(5) = rest of path
      return '${m.group(1)}/${m.group(2)}/****/****/${m.group(5)}';
    });

    // 2. Mask query-string credentials (Xtream Codes player API URLs).
    result = result.replaceAll(_queryUsernameRe, r'username=****');
    result = result.replaceAll(_queryPasswordRe, r'password=****');

    return result;
  }

  // —— Logging methods ——————————————————————————————————————————————————————

  /// Debug-level log. For verbose diagnostics (position polls, internal state).
  void d(String message, {String? event, Map<String, dynamic>? data}) {
    _logger.d('[$tag] $message');
    _writeToFile('DEBUG', message, event: event, data: data);
  }

  /// Info-level log. For normal flow events (room joined, playback started).
  void i(String message, {String? event, Map<String, dynamic>? data}) {
    _logger.i('[$tag] $message');
    _writeToFile('INFO ', message, event: event, data: data);
  }

  /// Warning-level log. For expected failures or suspicious conditions.
  void w(
    String message, {
    String? event,
    dynamic error,
    Map<String, dynamic>? data,
  }) {
    _logger.w('[$tag] $message', error: error);
    _writeToFile('WARN ', message, event: event, error: error, data: data);
  }

  /// Error-level log. For unexpected failures requiring investigation.
  void e(
    String message, {
    String? event,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    _logger.e('[$tag] $message', error: error, stackTrace: stackTrace);
    _writeToFile(
      'ERROR',
      message,
      event: event,
      error: error,
      stackTrace: stackTrace,
      data: data,
    );
  }

  // —— File writer ——————————————————————————————————————————————————————————

  void _writeToFile(
    String level,
    String message, {
    String? event,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? data,
  }) {
    if (!_initialized || _fileSink == null) return;

    try {
      final ts = _formatTimestamp(DateTime.now());
      final eventStr = event != null ? ' event=$event' : '';
      final dataStr =
          data != null && data.isNotEmpty ? ' ${_formatData(data)}' : '';

      _fileSink!.writeln('[$ts] [$level] [$tag]$eventStr $message$dataStr');

      if (error != null) {
        _fileSink!.writeln('  error: $error');
      }
      if (stackTrace != null) {
        _fileSink!.writeln('  stackTrace:\n$stackTrace');
      }
    } catch (_) {
      // Logging must never crash the app.
    }
  }

  // —— Helpers ——————————————————————————————————————————————————————————————

  static String _detectPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Returns the absolute path for the "Watch Party Logs" directory.
  ///
  /// Android/iOS: prefers app-specific external storage so the folder is
  /// visible to the user in the device Files app without any extra permissions.
  /// Falls back to the internal app-documents directory if external storage is
  /// not available.
  ///
  /// Desktop: returns the hardcoded development log directory.
  static Future<String> _resolveLogDir() async {
    if (Platform.isAndroid) {
      // getExternalStorageDirectory() resolves to:
      //   /storage/emulated/0/Android/data/<package>/files
      // No READ_EXTERNAL_STORAGE / WRITE_EXTERNAL_STORAGE permission is needed
      // for this app-specific path on any Android version.
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          return '${extDir.path}${Platform.pathSeparator}$_logFolderName';
        }
      } catch (_) {
        // External storage unavailable — fall through to internal.
      }
      // Fallback: internal app-documents directory.
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}${Platform.pathSeparator}$_logFolderName';
    }

    if (Platform.isIOS) {
      // iOS only has app-sandbox storage; use documents directory.
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}${Platform.pathSeparator}$_logFolderName';
    }

    return _desktopLogDir;
  }

  /// Format a [DateTime] as `YYYY-MM-DD HH:mm:ss.SSS` (local time).
  static String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$y-$mo-$d $h:$mi:$s.$ms';
  }

  static String _formatData(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join(' ');
  }
}
