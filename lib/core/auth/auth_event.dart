import 'package:meta/meta.dart';

import 'auth_repository.dart';

/// Authentication events for [AuthBloc].
@immutable
sealed class AuthEvent {
  const AuthEvent();

  const factory AuthEvent.checkRequested() = AuthCheckRequested;
  const factory AuthEvent.loginRequested({
    required String email,
    required String password,
  }) = AuthLoginRequested;
  const factory AuthEvent.signUpRequested({
    required String email,
    required String password,
    String? displayName,
  }) = AuthSignUpRequested;
  const factory AuthEvent.oAuthRequested(OAuthProvider provider) = AuthOAuthRequested;
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;
  const factory AuthEvent.userChanged(AuthUser? user) = AuthUserChanged;
}

final class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthCheckRequested;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthEvent.checkRequested()';
}

final class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthLoginRequested &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          password == other.password;

  @override
  int get hashCode => Object.hash(email, password);

  @override
  String toString() => 'AuthEvent.loginRequested(email: $email)';
}

final class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    this.displayName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSignUpRequested &&
          runtimeType == other.runtimeType &&
          email == other.email &&
          password == other.password &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(email, password, displayName);

  @override
  String toString() => 'AuthEvent.signUpRequested(email: $email, displayName: $displayName)';
}

final class AuthOAuthRequested extends AuthEvent {
  final OAuthProvider provider;

  const AuthOAuthRequested(this.provider);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthOAuthRequested &&
          runtimeType == other.runtimeType &&
          provider == other.provider;

  @override
  int get hashCode => provider.hashCode;

  @override
  String toString() => 'AuthEvent.oAuthRequested($provider)';
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AuthLogoutRequested;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'AuthEvent.logoutRequested()';
}

final class AuthUserChanged extends AuthEvent {
  final AuthUser? user;

  const AuthUserChanged(this.user);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUserChanged && runtimeType == other.runtimeType && user == other.user;

  @override
  int get hashCode => user.hashCode;

  @override
  String toString() => 'AuthEvent.userChanged($user)';
}
