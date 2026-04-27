import 'package:dio/dio.dart';
import '../logging/app_logger.dart';
import '../constants/app_constants.dart';

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const NetworkException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => 'NetworkException($statusCode): $message';
}



class HttpClient {
  final Dio _dio;
  final AppLogger _logger;

  HttpClient({AppLogger? logger})
      : _logger = logger ?? AppLogger('HttpClient'),
        _dio = Dio(
          BaseOptions(
            baseUrl: '${AppConstants.kServerBaseUrl}/api/v1',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.d('HTTP ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.d(
            'HTTP ${response.statusCode} ${response.requestOptions.uri}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          _logger.e(
            'HTTP Error ${error.response?.statusCode} ${error.requestOptions.uri}',
          );
          handler.next(error);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> createRoom() async {
    try {
      final response = await _dio.post('/rooms');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> joinRoomPreCheck(String roomCode) async {
    try {
      final response = await _dio.post('/rooms/$roomCode/join');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> getRoomStatus(String roomCode) async {
    try {
      final response = await _dio.get('/rooms/$roomCode/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<List<Map<String, dynamic>>> listRooms() async {
    try {
      final response = await _dio.get('/rooms');
      final data = response.data as Map<String, dynamic>;
      final rooms = data['rooms'] as List<dynamic>;
      return rooms.cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  NetworkException _mapError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    String message = e.message ?? 'Unknown network error';

    if (data is Map<String, dynamic>) {
      message = data['message'] as String? ?? message;
    }

    return NetworkException(message, statusCode: statusCode, originalError: e);
  }
}
