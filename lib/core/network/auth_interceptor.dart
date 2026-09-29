import 'dart:async';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'auth_exception.dart';
import 'auth_token_manager.dart';

/// Interceptor that attaches authentication tokens to outbound requests
/// and handles concurrency-safe token refreshing on expiry or 401 responses.
class AuthInterceptor extends Interceptor {
  final AuthTokenManager _tokenManager;
  final Dio _dio;
  final Logger _logger;

  Completer<String?>? _refreshCompleter;

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

    // If a refresh is already in flight, await the new token
    if (_refreshCompleter != null) {
      try {
        final token = await _refreshCompleter!.future;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      } catch (_) {
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const AuthException('Authentication expired'),
          ),
        );
      }
    }

    // Check if token needs proactive refresh
    if (await _tokenManager.isTokenExpired()) {
      final completer = Completer<String?>();
      _refreshCompleter = completer;

      try {
        final newToken = await _tokenManager.refreshAccessToken();
        options.headers['Authorization'] = 'Bearer $newToken';
        completer.complete(newToken);
        return handler.next(options);
      } catch (e) {
        completer.completeError(e);
        _logger.e('Token refresh failed: $e');
        return handler.reject(
          DioException(
            requestOptions: options,
            error: const AuthException('Authentication expired'),
          ),
        );
      } finally {
        _refreshCompleter = null;
      }
    } else {
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized
    if (err.response?.statusCode == 401 && !_isAuthEndpoint(err.requestOptions.path)) {
      // If a refresh is already underway, await it and retry
      if (_refreshCompleter != null) {
        try {
          final token = await _refreshCompleter!.future;
          if (token != null) {
            final opts = err.requestOptions;
            opts.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(opts);
            return handler.resolve(response);
          }
        } catch (_) {
          return handler.next(err);
        }
      }

      final completer = Completer<String?>();
      _refreshCompleter = completer;

      try {
        final newToken = await _tokenManager.refreshAccessToken();
        completer.complete(newToken);

        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';

        // Retry the request with the new token
        final response = await _dio.fetch(opts);
        return handler.resolve(response);
      } catch (e) {
        completer.completeError(e);
        _logger.e('Token refresh on 401 failed: $e');
        await _tokenManager.clearTokens();
        return handler.next(err);
      } finally {
        _refreshCompleter = null;
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
