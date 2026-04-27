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

/// Low-level HTTP service for Xtream Codes IPTV API.
class IptvApiService {
  final Dio _dio;
  final IptvConfig _config;
  final AppLogger _logger;

  IptvApiService({required IptvConfig config, AppLogger? logger})
      : _config = config,
        _logger = logger ?? AppLogger('IptvApiService'),
        _dio = Dio(
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

  /// Returns a sanitized URI string safe to write to logs.
  /// Masks credentials in both query parameters and Xtream Codes path segments.
  static String _sanitizeUri(Uri uri) {
    // Delegate to the canonical sanitization helper so both code paths
    // apply identical masking rules.
    return AppLogger.sanitizeUrl(uri.toString());
  }

  IptvConfig get config => _config;

  // ── Authentication ───────────────────────────────────────────────

  Future<Map<String, dynamic>> authenticate() async {
    try {
      final response = await _dio.getUri(_config.authUrl);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Live TV ──────────────────────────────────────────────────────

  Future<List<IptvCategory>> getLiveCategories() async {
    return _fetchCategories(_config.liveCategoriesUrl);
  }

  Future<List<LiveStream>> getLiveStreams({String? categoryId}) async {
    try {
      final response = await _dio.getUri(
        _config.liveStreamsUrl(categoryId: categoryId),
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

  // ── Movies / VOD ─────────────────────────────────────────────────

  Future<List<IptvCategory>> getVodCategories() async {
    return _fetchCategories(_config.vodCategoriesUrl);
  }

  Future<List<VodStream>> getVodStreams({String? categoryId}) async {
    try {
      final response = await _dio.getUri(
        _config.vodStreamsUrl(categoryId: categoryId),
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

  // ── Series ───────────────────────────────────────────────────────

  Future<List<IptvCategory>> getSeriesCategories() async {
    return _fetchCategories(_config.seriesCategoriesUrl);
  }

  Future<List<SeriesItem>> getSeriesList({String? categoryId}) async {
    try {
      final response = await _dio.getUri(
        _config.seriesListUrl(categoryId: categoryId),
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
    try {
      final response = await _dio.getUri(_config.seriesInfoUrl(seriesId));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────

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
      message = 'IPTV authentication failed';
    } else {
      message = e.message ?? 'Unknown IPTV API error';
    }

    return IptvApiException(message, statusCode: statusCode);
  }
}
