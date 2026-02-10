import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_repository.dart';

part 'auth_event.freezed.dart';

/// Authentication events for [AuthBloc].
@freezed
class AuthEvent with _$AuthEvent {
  /// Check if user is currently authenticated.
  ///
  /// Dispatched on app startup to restore auth state.
  const factory AuthEvent.checkRequested() = AuthCheckRequested;

  /// Request login with email and password.
  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;

  /// Request account creation with email and password.
  const factory AuthEvent.signUpRequested({
    required String email,
    required String password,
    String? displayName,
  }) = AuthSignUpRequested;

  /// Request OAuth sign-in with a provider.
  const factory AuthEvent.oAuthRequested(OAuthProvider provider) =
      AuthOAuthRequested;

  /// Request logout.
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;

  /// Auth state changed (from auth provider stream).
  ///
  /// This event is dispatched internally by [AuthBloc] when
  /// the auth provider's auth state stream emits.
  const factory AuthEvent.userChanged(AuthUser? user) = AuthUserChanged;
}
