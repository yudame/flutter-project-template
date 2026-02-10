import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_repository.dart';

part 'auth_state.freezed.dart';

/// Authentication states for [AuthBloc].
@freezed
class AuthState with _$AuthState {
  /// Initial state before auth check.
  const factory AuthState.initial() = AuthInitial;

  /// Auth operation in progress (checking, logging in, etc.).
  const factory AuthState.loading() = AuthLoading;

  /// User is authenticated.
  const factory AuthState.authenticated(AuthUser user) = AuthAuthenticated;

  /// User is not authenticated.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Auth error occurred.
  const factory AuthState.error(String message) = AuthError;
}
