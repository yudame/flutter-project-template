import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../utils/result.dart';
import 'auth_event.dart';
import 'auth_repository.dart';
import 'auth_state.dart';

/// Authentication BLoC.
///
/// Manages auth state across the app. Listen to this BLoC
/// for auth state changes and use with [authGuard] for route protection.
///
/// Example usage:
/// ```dart
/// // In app initialization
/// context.read<AuthBloc>().add(const AuthEvent.checkRequested());
///
/// // In login page
/// context.read<AuthBloc>().add(AuthEvent.loginRequested(
///   email: email,
///   password: password,
/// ));
///
/// // In UI
/// BlocBuilder<AuthBloc, AuthState>(
///   builder: (context, state) {
///     return state.when(
///       initial: () => const SplashScreen(),
///       loading: () => const LoadingIndicator(),
///       authenticated: (user) => HomePage(user: user),
///       unauthenticated: () => const LoginPage(),
///       error: (message) => ErrorView(message: message),
///     );
///   },
/// )
/// ```
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.initial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthOAuthRequested>(_onOAuthRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUserChanged>(_onUserChanged);

    // Listen to auth state changes from repository
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) => add(AuthEvent.userChanged(user)),
    );
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    try {
      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthState.authenticated(user));
      } else {
        emit(const AuthState.unauthenticated());
      }
    } catch (e) {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final result = await _authRepository.signInWithEmail(
      email: event.email,
      password: event.password,
    );

    switch (result) {
      case Success(:final data):
        emit(AuthState.authenticated(data));
      case Failure(:final message):
        emit(AuthState.error(message));
      case Loading():
        break;
    }
  }

  Future<void> _onSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final result = await _authRepository.signUpWithEmail(
      email: event.email,
      password: event.password,
      displayName: event.displayName,
    );

    switch (result) {
      case Success(:final data):
        emit(AuthState.authenticated(data));
      case Failure(:final message):
        emit(AuthState.error(message));
      case Loading():
        break;
    }
  }

  Future<void> _onOAuthRequested(
    AuthOAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final result = await _authRepository.signInWithOAuth(event.provider);

    switch (result) {
      case Success(:final data):
        emit(AuthState.authenticated(data));
      case Failure(:final message):
        emit(AuthState.error(message));
      case Loading():
        break;
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.loading());

    final result = await _authRepository.signOut();

    switch (result) {
      case Success():
        emit(const AuthState.unauthenticated());
      case Failure(:final message):
        emit(AuthState.error(message));
      case Loading():
        break;
    }
  }

  void _onUserChanged(
    AuthUserChanged event,
    Emitter<AuthState> emit,
  ) {
    if (event.user != null) {
      emit(AuthState.authenticated(event.user!));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
