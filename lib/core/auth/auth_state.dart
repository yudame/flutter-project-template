import 'package:meta/meta.dart';

import 'auth_repository.dart';

/// Authentication states for [AuthBloc].
@immutable
sealed class AuthState {
  const AuthState();

  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(AuthUser user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;

  R when<R>({
    required R Function() initial,
    required R Function() loading,
    required R Function(AuthUser user) authenticated,
    required R Function() unauthenticated,
    required R Function(String message) error,
  }) =>
      switch (this) {
        AuthInitial() => initial(),
        AuthLoading() => loading(),
        AuthAuthenticated(:final user) => authenticated(user),
        AuthUnauthenticated() => unauthenticated(),
        AuthError(:final message) => error(message),
      };

  R? whenOrNull<R>({
    R Function()? initial,
    R Function()? loading,
    R Function(AuthUser user)? authenticated,
    R Function()? unauthenticated,
    R Function(String message)? error,
  }) =>
      switch (this) {
        AuthInitial() => initial?.call(),
        AuthLoading() => loading?.call(),
        AuthAuthenticated(:final user) => authenticated?.call(user),
        AuthUnauthenticated() => unauthenticated?.call(),
        AuthError(:final message) => error?.call(message),
      };
}

final class AuthInitial extends AuthState {
  const AuthInitial();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthInitial;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthState.initial()';
}

final class AuthLoading extends AuthState {
  const AuthLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthLoading;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthState.loading()';
}

final class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthAuthenticated && runtimeType == other.runtimeType && user == other.user;

  @override
  int get hashCode => user.hashCode;

  @override
  String toString() => 'AuthState.authenticated($user)';
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthUnauthenticated;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthState.unauthenticated()';
}

final class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthError && runtimeType == other.runtimeType && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'AuthState.error($message)';
}
