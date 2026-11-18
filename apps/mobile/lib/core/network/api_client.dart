import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nam_cinema/core/config/env_config.dart';
import 'package:nam_cinema/core/errors/app_exception.dart';
import 'package:nam_cinema/core/security/secure_token_storage.dart';

class ApiClient {
  final Dio _dio;
  final SecureTokenStorage _tokenStorage;
  bool _isRefreshing = false;

  ApiClient({
    required Dio dio,
    required SecureTokenStorage tokenStorage,
  })  : _dio = dio,
        _tokenStorage = tokenStorage {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException error, handler) async {
          final statusCode = error.response?.statusCode;
          final isAuthEndpoint = error.requestOptions.path.contains('/auth/login') ||
              error.requestOptions.path.contains('/auth/register') ||
              error.requestOptions.path.contains('/auth/refresh');

          if (statusCode == 401 && !isAuthEndpoint && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final refreshToken = await _tokenStorage.readRefreshToken();
              if (refreshToken != null && refreshToken.isNotEmpty) {
                final refreshDio = Dio(
                  BaseOptions(
                    baseUrl: AppEnvConfig.apiV1BaseUrl,
                    connectTimeout: AppEnvConfig.connectTimeout,
                    receiveTimeout: AppEnvConfig.receiveTimeout,
                  ),
                );
                final refreshResp = await refreshDio.post<Map<String, dynamic>>(
                  '/auth/refresh',
                  data: {'refresh_token': refreshToken},
                );
                final data = refreshResp.data;
                if (data != null &&
                    data['access_token'] is String &&
                    data['refresh_token'] is String) {
                  final newAccess = data['access_token'] as String;
                  final newRefresh = data['refresh_token'] as String;
                  await _tokenStorage.saveTokens(
                    accessToken: newAccess,
                    refreshToken: newRefresh,
                  );

                  final retryOptions = error.requestOptions;
                  retryOptions.headers['Authorization'] = 'Bearer $newAccess';
                  final cloneResponse = await _dio.fetch<dynamic>(retryOptions);
                  _isRefreshing = false;
                  return handler.resolve(cloneResponse);
                }
              }
            } catch (_) {
              await _tokenStorage.clearAll();
            } finally {
              _isRefreshing = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Dio get rawDio => _dio;

  AppException mapDioError(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
        final errObj = data['error'] as Map<String, dynamic>;
        return AppException(
          code: (errObj['code'] as String?) ?? 'API_ERROR',
          message: (errObj['message'] as String?) ?? 'Yêu cầu thất bại.',
          statusCode: statusCode,
        );
      }
      if (statusCode == 401) {
        return const UnauthorizedException();
      }
      return NetworkFailureException(
        error.message ?? 'Không thể kết nối tới máy chủ Nam Cinema.',
      );
    }
    return AppException(code: 'UNKNOWN_ERROR', message: error.toString());
  }
}

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppEnvConfig.apiV1BaseUrl,
      connectTimeout: AppEnvConfig.connectTimeout,
      receiveTimeout: AppEnvConfig.receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  final tokenStorage = ref.watch(secureTokenStorageProvider);
  return ApiClient(dio: dio, tokenStorage: tokenStorage);
});
