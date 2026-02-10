import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_template/core/auth/auth_bloc.dart';
import 'package:flutter_template/core/auth/auth_event.dart';
import 'package:flutter_template/core/auth/auth_repository.dart';
import 'package:flutter_template/core/auth/auth_state.dart';
import 'package:flutter_template/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late StreamController<AuthUser?> authStateController;

  const testUser = AuthUser(
    id: 'test-id',
    email: 'test@example.com',
    displayName: 'Test User',
    emailVerified: true,
  );

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authStateController = StreamController<AuthUser?>.broadcast();

    when(() => mockAuthRepository.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
  });

  tearDown(() {
    authStateController.close();
  });

  group('AuthBloc', () {
    test('initial state is AuthInitial', () {
      final bloc = AuthBloc(authRepository: mockAuthRepository);
      expect(bloc.state, equals(const AuthState.initial()));
      bloc.close();
    });

    group('checkRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when user exists',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => testUser);
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.checkRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when no user',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => null);
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.checkRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] on error',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenThrow(Exception('Network error'));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.checkRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );
    });

    group('loginRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when login succeeds',
        build: () {
          when(() => mockAuthRepository.signInWithEmail(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer((_) async => const Result.success(testUser));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.loginRequested(
          email: 'test@example.com',
          password: 'password123',
        )),
        expect: () => [
          const AuthState.loading(),
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when login fails',
        build: () {
          when(() => mockAuthRepository.signInWithEmail(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer(
              (_) async => const Result.failure('Invalid credentials'));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.loginRequested(
          email: 'test@example.com',
          password: 'wrongpassword',
        )),
        expect: () => [
          const AuthState.loading(),
          const AuthState.error('Invalid credentials'),
        ],
      );
    });

    group('signUpRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when signup succeeds',
        build: () {
          when(() => mockAuthRepository.signUpWithEmail(
                email: any(named: 'email'),
                password: any(named: 'password'),
                displayName: any(named: 'displayName'),
              )).thenAnswer((_) async => const Result.success(testUser));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.signUpRequested(
          email: 'test@example.com',
          password: 'password123',
          displayName: 'Test User',
        )),
        expect: () => [
          const AuthState.loading(),
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when signup fails',
        build: () {
          when(() => mockAuthRepository.signUpWithEmail(
                email: any(named: 'email'),
                password: any(named: 'password'),
                displayName: any(named: 'displayName'),
              )).thenAnswer(
              (_) async => const Result.failure('Email already in use'));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.signUpRequested(
          email: 'existing@example.com',
          password: 'password123',
        )),
        expect: () => [
          const AuthState.loading(),
          const AuthState.error('Email already in use'),
        ],
      );
    });

    group('oAuthRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when OAuth succeeds',
        build: () {
          when(() => mockAuthRepository.signInWithOAuth(OAuthProvider.google))
              .thenAnswer((_) async => const Result.success(testUser));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) =>
            bloc.add(const AuthEvent.oAuthRequested(OAuthProvider.google)),
        expect: () => [
          const AuthState.loading(),
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when OAuth fails',
        build: () {
          when(() => mockAuthRepository.signInWithOAuth(OAuthProvider.google))
              .thenAnswer((_) async => const Result.failure('Sign in cancelled'));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) =>
            bloc.add(const AuthEvent.oAuthRequested(OAuthProvider.google)),
        expect: () => [
          const AuthState.loading(),
          const AuthState.error('Sign in cancelled'),
        ],
      );
    });

    group('logoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, unauthenticated] when logout succeeds',
        build: () {
          when(() => mockAuthRepository.signOut())
              .thenAnswer((_) async => const Result.success(null));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.unauthenticated(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when logout fails',
        build: () {
          when(() => mockAuthRepository.signOut())
              .thenAnswer((_) async => const Result.failure('Logout failed'));
          return AuthBloc(authRepository: mockAuthRepository);
        },
        act: (bloc) => bloc.add(const AuthEvent.logoutRequested()),
        expect: () => [
          const AuthState.loading(),
          const AuthState.error('Logout failed'),
        ],
      );
    });

    group('userChanged', () {
      blocTest<AuthBloc, AuthState>(
        'emits authenticated when user is not null',
        build: () => AuthBloc(authRepository: mockAuthRepository),
        act: (bloc) => bloc.add(const AuthEvent.userChanged(testUser)),
        expect: () => [
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits unauthenticated when user is null',
        build: () => AuthBloc(authRepository: mockAuthRepository),
        act: (bloc) => bloc.add(const AuthEvent.userChanged(null)),
        expect: () => [
          const AuthState.unauthenticated(),
        ],
      );
    });

    group('authStateChanges stream', () {
      blocTest<AuthBloc, AuthState>(
        'listens to auth state changes and emits authenticated',
        build: () => AuthBloc(authRepository: mockAuthRepository),
        act: (bloc) async {
          authStateController.add(testUser);
          await Future.delayed(Duration.zero);
        },
        expect: () => [
          const AuthState.authenticated(testUser),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'listens to auth state changes and emits unauthenticated',
        build: () => AuthBloc(authRepository: mockAuthRepository),
        act: (bloc) async {
          authStateController.add(null);
          await Future.delayed(Duration.zero);
        },
        expect: () => [
          const AuthState.unauthenticated(),
        ],
      );
    });
  });
}
