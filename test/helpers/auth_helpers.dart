import 'package:flutter_template/core/network/auth_token_manager.dart';
import 'package:mocktail/mocktail.dart';

/// Mock [AuthTokenManager] so network tests can run the `AuthInterceptor`
/// without touching secure storage.
class MockAuthTokenManager extends Mock implements AuthTokenManager {}
