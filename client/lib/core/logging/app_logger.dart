import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';



















class AppLogger {
  
  

  static const String _logFolderName = 'Watch Party Logs';
  static const String _logFileName = 'log.txt';

  
  
  static final RegExp _pathCredentialsRe = RegExp(
    r'(https?://[^/]+)/(live|movie|series)/([^/?#]+)/([^/?#]+)/(.+)',
    caseSensitive: false,
  );

  
  
  static final RegExp _queryUsernameRe = RegExp(
    r'(username=)[^&]+',
    caseSensitive: false,
  );
  static final RegExp _queryPasswordRe = RegExp(
    r'(password=)[^&]+',
    caseSensitive: false,
  );

  
  

  static String? _logFilePath;
  static IOSink? _fileSink;
  static bool _initialized = false;
  static String _platform = 'unknown';

  
  

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

      
      final file = File(_logFilePath!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {
          
          
        }
      }

      _fileSink = file.openWrite(mode: FileMode.write);
      _initialized = true;

      
      final now = _formatTimestamp(DateTime.now());
      const buildMode = kDebugMode
          ? 'debug'
          : kProfileMode
              ? 'profile'
              : 'release';

      _fileSink!.writeln(
        '================================================================',
      );
      _fileSink!.writeln('  WatchParty Client - session start');
      _fileSink!.writeln('  Platform : ${_platform.toUpperCase()}');
      _fileSink!.writeln('  Build    : $buildMode');
      _fileSink!.writeln('  Log file : $_logFilePath');
      _fileSink!.writeln('  Started  : $now');
      _fileSink!.writeln(
        '================================================================',
      );
      _fileSink!.writeln('');
      await _fileSink!.flush();
    } catch (e) {
      
      
      debugPrint('[AppLogger] Failed to initialize file logging: $e');
    }
  }

  
  static Future<void> shutdown() async {
    if (!_initialized) return;
    try {
      final now = _formatTimestamp(DateTime.now());
      _fileSink?.writeln('');
      _fileSink?.writeln(
        '================================================================',
      );
      _fileSink?.writeln('  Session end: $now');
      _fileSink?.writeln(
        '================================================================',
      );
      await _fileSink?.flush();
      await _fileSink?.close();
    } catch (_) {
      
    }
    _fileSink = null;
    _initialized = false;
  }

  
  

  
  
  
  
  
  
  
  
  
  
  
  static String sanitizeUrl(String url) {
    
    String result = url.replaceFirstMapped(_pathCredentialsRe, (m) {
      
      
      
      
      
      return '${m.group(1)}/${m.group(2)}/****/****/${m.group(5)}';
    });

    
    result = result.replaceAll(_queryUsernameRe, r'username=****');
    result = result.replaceAll(_queryPasswordRe, r'password=****');

    return result;
  }

  
  

  
  void d(String message, {String? event, Map<String, dynamic>? data}) {
    _logger.d('[$tag] $message');
    _writeToFile('DEBUG', message, event: event, data: data);
  }

  
  void i(String message, {String? event, Map<String, dynamic>? data}) {
    _logger.i('[$tag] $message');
    _writeToFile('INFO ', message, event: event, data: data);
  }

  
  void w(
    String message, {
    String? event,
    dynamic error,
    Map<String, dynamic>? data,
  }) {
    _logger.w('[$tag] $message', error: error);
    _writeToFile('WARN ', message, event: event, error: error, data: data);
  }

  
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
      
    }
  }

  
  

  static String _detectPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  
  
  
  
  
  
  
  
  static Future<String> _resolveLogDir() async {
    if (Platform.isAndroid) {
      
      
      
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          return '${extDir.path}${Platform.pathSeparator}$_logFolderName';
        }
      } catch (_) {
        
      }
      
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}${Platform.pathSeparator}$_logFolderName';
    }

    if (Platform.isIOS) {
      
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}${Platform.pathSeparator}$_logFolderName';
    }

    
    final appDir = await getApplicationSupportDirectory();
    return '${appDir.path}${Platform.pathSeparator}$_logFolderName';
  }

  
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
