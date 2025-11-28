import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import 'auth_exception.dart';

class AuthTokenManager {
  final FlutterSecureStorage _storage;
  final Logger _logger;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiryKey = 'token_expiry';

  AuthTokenManager({
    required FlutterSecureStorage storage,
    required Logger logger,
  })  : _storage = storage,
        _logger = logger;

  Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<DateTime?> getExpiry() async {
    final expiryStr = await _storage.read(key: _expiryKey);
    if (expiryStr == null) return null;
    return DateTime.tryParse(expiryStr);
  }

  Future<bool> isTokenExpired() async {
    final expiry = await getExpiry();
    if (expiry == null) return true;

    // Add 60s buffer before actual expiry
    return DateTime.now().isAfter(expiry.subtract(const Duration(seconds: 60)));
  }

  Future<bool> hasValidTokens() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
      _storage.write(key: _expiryKey, value: expiry.toIso8601String()),
    ]);
    _logger.i('Tokens saved, expires at: $expiry');
  }

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiryKey),
    ]);
    _logger.i('Tokens cleared');
  }

  /// Refresh the access token using the refresh token.
  /// This method should be overridden or configured with actual API endpoint.
  Future<String> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      throw AuthException('No refresh token available');
    }

    // TODO: Replace with actual API call
    // Example:
    // final response = await _dio.post(
    //   '/auth/refresh',
    //   data: {'refresh_token': refreshToken},
    // );
    //
    // final newAccessToken = response.data['access_token'] as String;
    // final newRefreshToken = response.data['refresh_token'] as String;
    // final expiresIn = response.data['expires_in'] as int;
    //
    // await saveTokens(
    //   accessToken: newAccessToken,
    //   refreshToken: newRefreshToken,
    //   expiry: DateTime.now().add(Duration(seconds: expiresIn)),
    // );
    //
    // return newAccessToken;

    throw UnimplementedError(
      'refreshAccessToken must be implemented with actual API call',
    );
  }
}
