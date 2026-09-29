import 'package:dio/dio.dart';
import 'package:flutter_template/core/network/auth_interceptor.dart';
import 'package:flutter_template/core/network/auth_token_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthTokenManager extends Mock implements AuthTokenManager {}

class MockDio extends Mock implements Dio {}

class MockLogger extends Mock implements Logger {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

void main() {
  late AuthInterceptor interceptor;
  late MockAuthTokenManager mockTokenManager;
  late MockDio mockDio;
  late MockLogger mockLogger;

  setUp(() {
    mockTokenManager = MockAuthTokenManager();
    mockDio = MockDio();
    mockLogger = MockLogger();

    interceptor = AuthInterceptor(
      tokenManager: mockTokenManager,
      dio: mockDio,
      logger: mockLogger,
    );
  });

  group('AuthInterceptor', () {
    test('skips auth for login endpoints', () async {
      final options = RequestOptions(path: '/api/v1/auth/login');
      final handler = MockRequestInterceptorHandler();

      when(() => handler.next(options)).thenReturn(null);

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], isNull);
      verify(() => handler.next(options)).called(1);
      verifyNever(() => mockTokenManager.getAccessToken());
    });

    test('attaches valid access token to headers', () async {
      final options = RequestOptions(path: '/api/v1/items');
      final handler = MockRequestInterceptorHandler();

      when(() => mockTokenManager.isTokenExpired())
          .thenAnswer((_) async => false);
      when(() => mockTokenManager.getAccessToken())
          .thenAnswer((_) async => 'valid_token_123');
      when(() => handler.next(options)).thenReturn(null);

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], equals('Bearer valid_token_123'));
      verify(() => handler.next(options)).called(1);
    });

    test('refreshes token when expired before sending request', () async {
      final options = RequestOptions(path: '/api/v1/items');
      final handler = MockRequestInterceptorHandler();

      when(() => mockTokenManager.isTokenExpired())
          .thenAnswer((_) async => true);
      when(() => mockTokenManager.refreshAccessToken())
          .thenAnswer((_) async => 'refreshed_token_456');
      when(() => handler.next(options)).thenReturn(null);

      await interceptor.onRequest(options, handler);

      expect(
        options.headers['Authorization'],
        equals('Bearer refreshed_token_456'),
      );
      verify(() => mockTokenManager.refreshAccessToken()).called(1);
      verify(() => handler.next(options)).called(1);
    });
  });
}
