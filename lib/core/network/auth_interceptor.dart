import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'auth_exception.dart';
import 'auth_token_manager.dart';

class AuthInterceptor extends Interceptor {
  final AuthTokenManager _tokenManager;
  final Dio _dio;
  final Logger _logger;

  bool _isRefreshing = false;

  AuthInterceptor({
    required AuthTokenManager tokenManager,
    required Dio dio,
    required Logger logger,
  })  : _tokenManager = tokenManager,
        _dio = dio,
        _logger = logger;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for auth endpoints
    if (_isAuthEndpoint(options.path)) {
      return handler.next(options);
    }

    // Check if token needs refresh
    if (await _tokenManager.isTokenExpired() && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final newToken = await _tokenManager.refreshAccessToken();
        options.headers['Authorization'] = 'Bearer $newToken';
        _isRefreshing = false;
      } catch (e) {
        _isRefreshing = false;
        _logger.e('Token refresh failed: $e');
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const AuthException('Authentication expired'),
          ),
        );
      }
    } else {
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final newToken = await _tokenManager.refreshAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';

        // Retry the request with new token
        final response = await _dio.fetch(opts);
        _isRefreshing = false;
        return handler.resolve(response);
      } catch (e) {
        _isRefreshing = false;
        _logger.e('Token refresh on 401 failed: $e');
        // Clear tokens on refresh failure
        await _tokenManager.clearTokens();
      }
    }

    handler.next(err);
  }

  bool _isAuthEndpoint(String path) {
    return path.contains('/auth/') ||
        path.contains('/login') ||
        path.contains('/register');
  }
}
