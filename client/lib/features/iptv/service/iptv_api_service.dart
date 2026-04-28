import '../../../core/security/credential_store.dart';
import '../../../core/config/app_config.dart';
import 'package:dio/dio.dart';
import '../../../core/logging/app_logger.dart';
import '../config/iptv_config.dart';
import '../models/iptv_category.dart';
import '../models/live_stream.dart';
import '../models/vod_stream.dart';
import '../models/series_item.dart';

class IptvApiException implements Exception {
  final String message;
  final int? statusCode;

  const IptvApiException(this.message, {this.statusCode});

  @override
  String toString() => 'IptvApiException($statusCode): $message';
}

class IptvApiService {
  final Dio _dio;
  final AppConfig _appConfig;
  final CredentialStore _credentialStore;
  final AppLogger _logger;
  IptvConfig? _currentConfig;

  IptvApiService({
    required AppConfig appConfig,
    required CredentialStore credentialStore,
    Dio? dio,
    IptvConfig? initialConfig,
    AppLogger? logger,
  })  : _appConfig = appConfig,
        _credentialStore = credentialStore,
        _currentConfig = initialConfig,
        _logger = logger ?? AppLogger('IptvApiService'),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('IPTV ${options.method} ${_sanitizeUri(options.uri)}');
          handler.next(options);
        },
        onError: (error, handler) {
          _logger.e(
            'IPTV Error ${error.response?.statusCode} '
            '${_sanitizeUri(error.requestOptions.uri)}',
          );
          handler.next(error);
        },
      ),
    );
  }

  static String _sanitizeUri(Uri uri) {
    return AppLogger.sanitizeUrl(uri.toString());
  }

  IptvConfig get config {
    if (_currentConfig == null) {
      throw const IptvApiException('IPTV config is not initialized.');
    }
    return _currentConfig!;
  }

  Future<void> _ensureConfigured() async {
    if (_currentConfig != null) return;

    final creds = await _credentialStore.readIptvCredentials();
    if (creds == null) {
      throw const IptvApiException('IPTV credentials missing. Login required.');
    }

    _currentConfig = IptvConfig(
      username: creds.username,
      password: creds.password,
      baseUrl: _appConfig.iptvBaseUrl,
    );
  }

  void clearConfig() {
    _currentConfig = null;
  }

  Future<bool> verifyCredentials(String username, String password) async {
    try {
      final config = IptvConfig(
        username: username.trim(),
        password: password,
        baseUrl: _appConfig.iptvBaseUrl,
      );
      final response = await _dio.getUri(config.authUrl);
      final data = response.data as Map<String, dynamic>;
      final userInfo = data['user_info'] as Map<String, dynamic>?;
      return userInfo?['auth']?.toString() == '1';
    } catch (e) {
      _logger.e('Credential verification failed', error: e);
      return false;
    }
  }

  Future<Map<String, dynamic>> authenticate() async {
    await _ensureConfigured();
    try {
      final response = await _dio.getUri(config.authUrl);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<IptvCategory>> getLiveCategories() async {
    await _ensureConfigured();
    return _fetchCategories(config.liveCategoriesUrl);
  }

  Future<List<LiveStream>> getLiveStreams({String? categoryId}) async {
    await _ensureConfigured();
    try {
      final response = await _dio.getUri(
        config.liveStreamsUrl(categoryId: categoryId),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => LiveStream.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<IptvCategory>> getVodCategories() async {
    await _ensureConfigured();
    return _fetchCategories(config.vodCategoriesUrl);
  }

  Future<List<VodStream>> getVodStreams({String? categoryId}) async {
    await _ensureConfigured();
    try {
      final response = await _dio.getUri(
        config.vodStreamsUrl(categoryId: categoryId),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => VodStream.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<IptvCategory>> getSeriesCategories() async {
    await _ensureConfigured();
    return _fetchCategories(config.seriesCategoriesUrl);
  }

  Future<List<SeriesItem>> getSeriesList({String? categoryId}) async {
    await _ensureConfigured();
    try {
      final response = await _dio.getUri(
        config.seriesListUrl(categoryId: categoryId),
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => SeriesItem.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getSeriesInfo(String seriesId) async {
    await _ensureConfigured();
    try {
      final response = await _dio.getUri(config.seriesInfoUrl(seriesId));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<IptvCategory>> _fetchCategories(Uri url) async {
    try {
      final response = await _dio.getUri(url);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => IptvCategory.fromJson(json))
          .toList();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  IptvApiException _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    String message;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'IPTV server timeout';
    } else if (statusCode == 403) {
      message = 'IPTV authentication failed — check credentials';
    } else {
      message = e.message ?? 'Unknown IPTV API error';
    }

    return IptvApiException(message, statusCode: statusCode);
  }
}
