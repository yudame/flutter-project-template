# Plan: Authentication Flow Documentation & Examples

## Goal

Add authentication documentation, an abstract auth repository interface, AuthBloc for state management, and route guard patterns — enabling teams to quickly implement login/signup flows with their chosen provider (Firebase Auth, Supabase Auth, or custom REST API).

## Current State

- **Existing infrastructure**:
  - `AuthTokenManager` — stores/retrieves tokens from flutter_secure_storage
  - `AuthInterceptor` — attaches tokens to requests, handles 401 refresh
  - `AuthException` — auth-related error type
- **Missing**:
  - No auth UI (login/signup pages)
  - No AuthBloc for auth state management
  - No abstract auth repository interface
  - No route guards for protected routes
  - No documentation covering auth patterns

## Approach

Follow the same pattern as the database layer: **abstract interface + documentation + Claude command**. Keep the template backend-agnostic by not adding Firebase Auth or Supabase Auth as committed dependencies.

**Key decisions**:
1. **AuthBloc** is real code — apps always need auth state management
2. **AuthRepository** is an abstract interface — concrete implementations documented, not committed
3. **UI pages** are example code, not committed — too app-specific (branding, design system)
4. **Route guards** are real code — a reusable `redirect` callback pattern for go_router
5. **Provider-specific code** (Firebase, Supabase) goes in documentation and Claude commands

This approach ensures teams get:
- Working auth state management out of the box
- Protected route pattern ready to use
- Clear documentation for setting up their chosen provider
- Claude commands to scaffold the rest

---

## Files to Create

### 1. `docs/authentication.md`

Comprehensive documentation covering:

- **Architecture overview**: Token-based vs session-based, when to use each
- **Auth state machine**: unauthenticated → authenticating → authenticated → (logout) → unauthenticated
- **Token storage**: Why flutter_secure_storage, biometric unlock (optional)
- **AuthBloc pattern**: Events (login, logout, checkStatus), States (initial, loading, authenticated, unauthenticated, error)
- **AuthRepository interface**: Abstract operations each provider must implement
- **Provider setup guides**:
  - Firebase Auth: Setup, email/password, OAuth (Google, Apple), integration with AuthBloc
  - Supabase Auth: Setup, email/password, OAuth, magic links
  - Custom REST API: Login/register endpoints, token refresh
- **Protected routes**: go_router redirect pattern, auth guard usage
- **Logout flow**: Clear tokens, clear cache, reset state, redirect to login
- **Biometric authentication** (optional): When to use, implementation pattern
- **Account linking**: Connecting multiple auth providers
- **Offline auth**: Cached auth state, handling token expiry offline
- **Security considerations**: Secure storage, token rotation, session invalidation

### 2. `lib/core/auth/auth_repository.dart`

Abstract interface for auth operations:

```dart
import '../utils/result.dart';

/// Abstract authentication repository.
///
/// Implement for your auth provider: Firebase, Supabase, REST API.
/// AuthBloc depends on this interface, not concrete implementations.
abstract class AuthRepository {
  /// Get the currently authenticated user (null if not authenticated)
  Future<AuthUser?> getCurrentUser();

  /// Sign in with email and password
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Create a new account with email and password
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in with OAuth provider (Google, Apple, GitHub, etc.)
  Future<Result<AuthUser>> signInWithOAuth(OAuthProvider provider);

  /// Send password reset email
  Future<Result<void>> sendPasswordReset(String email);

  /// Sign out the current user
  Future<Result<void>> signOut();

  /// Stream of auth state changes
  Stream<AuthUser?> get authStateChanges;

  /// Refresh the current user's token
  Future<Result<String>> refreshToken();
}

/// Minimal user model for auth state
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });
}

/// Supported OAuth providers
enum OAuthProvider {
  google,
  apple,
  github,
}
```

### 3. `lib/core/auth/auth_bloc.dart`

Authentication state management:

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_repository.dart';

part 'auth_bloc.freezed.dart';

/// Authentication BLoC
///
/// Manages auth state across the app. Listen to this BLoC
/// for auth state changes and use for route guards.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<AuthUser?>? _authSubscription;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.initial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignUpRequested>(_onSignUpRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUserChanged>(_onUserChanged);

    // Listen to auth state changes from repository
    _authSubscription = _authRepository.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
    );
  }

  // Event handlers...

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}

/// Auth events
@freezed
class AuthEvent with _$AuthEvent {
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
  const factory AuthEvent.logoutRequested() = AuthLogoutRequested;
  const factory AuthEvent.userChanged(AuthUser? user) = AuthUserChanged;
}

/// Auth states
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(AuthUser user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}
```

### 4. `lib/core/auth/auth_event.dart`

Freezed events (separate file per template convention):

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_repository.dart';

part 'auth_event.freezed.dart';

@freezed
class AuthEvent with _$AuthEvent {
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
```

### 5. `lib/core/auth/auth_state.dart`

Freezed states (separate file):

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_repository.dart';

part 'auth_state.freezed.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(AuthUser user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}
```

### 6. `lib/core/routes/auth_guard.dart`

Route guard using go_router redirect:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';

/// Creates a redirect function for protecting routes.
///
/// Usage in GoRouter:
/// ```dart
/// GoRouter(
///   redirect: authGuard(
///     authBloc: getIt<AuthBloc>(),
///     loginPath: '/login',
///     allowedPaths: ['/login', '/signup', '/forgot-password'],
///   ),
///   routes: [...],
/// )
/// ```
GoRouterRedirect authGuard({
  required AuthBloc authBloc,
  required String loginPath,
  List<String> allowedPaths = const [],
}) {
  return (context, state) {
    final authState = authBloc.state;
    final currentPath = state.uri.path;

    // Allow access to public paths
    if (allowedPaths.contains(currentPath)) {
      // If authenticated and trying to access login, redirect to home
      if (authState is AuthAuthenticated && currentPath == loginPath) {
        return '/';
      }
      return null;
    }

    // Redirect unauthenticated users to login
    if (authState is AuthUnauthenticated || authState is AuthInitial) {
      return loginPath;
    }

    // Allow authenticated users to proceed
    return null;
  };
}
```

### 7. Update `lib/core/routes/app_router.dart`

Add example protected route setup (commented):

```dart
// Example of router with auth guard:
//
// final appRouter = GoRouter(
//   redirect: authGuard(
//     authBloc: getIt<AuthBloc>(),
//     loginPath: '/login',
//     allowedPaths: ['/login', '/signup', '/forgot-password'],
//   ),
//   routes: [
//     GoRoute(
//       path: '/login',
//       name: 'login',
//       builder: (context, state) => const LoginPage(),
//     ),
//     GoRoute(
//       path: '/',
//       name: 'home',
//       builder: (context, state) => const HomePage(),
//     ),
//   ],
// );
```

### 8. Update `lib/core/di/injection.dart`

Add AuthBloc registration (commented until concrete repo exists):

```dart
// Auth (uncomment after implementing AuthRepository)
// getIt.registerLazySingleton<AuthRepository>(
//   () => FirebaseAuthRepository(),  // or SupabaseAuthRepository
// );
//
// getIt.registerLazySingleton<AuthBloc>(
//   () => AuthBloc(authRepository: getIt<AuthRepository>()),
// );
```

### 9. `.claude/commands/add-auth.md`

Claude command to add authentication:

```markdown
Add authentication to this project.

## Input Required

Ask for:
- **Provider**: Firebase Auth, Supabase Auth, or custom REST API
- **Auth methods**: Email/password, OAuth (Google, Apple, GitHub), magic link
- **Biometric unlock**: Optional secure storage unlock with Face ID / Touch ID

## Steps

### 1. Add Provider Dependency

**Firebase:**
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  google_sign_in: ^6.0.0  # If using Google OAuth
```

**Supabase:**
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

### 2. Create Concrete AuthRepository

Create `lib/core/auth/{provider}_auth_repository.dart` implementing `AuthRepository`.

See `docs/authentication.md` for complete implementation examples.

### 3. Register in DI

Update `lib/core/di/injection.dart`:
- Register AuthRepository
- Register AuthBloc

### 4. Set Up Route Guard

Update `lib/core/routes/app_router.dart`:
- Add redirect using authGuard
- Define public paths (login, signup)

### 5. Create Auth UI

Create in `lib/features/auth/presentation/`:
- `login_page.dart`
- `signup_page.dart`
- `forgot_password_page.dart`

### 6. Wire Up Token Refresh

Connect AuthRepository.refreshToken to existing AuthTokenManager.

## Verification

1. Run `flutter test` — all tests pass
2. Test login flow end-to-end
3. Test logout clears state and redirects
4. Test protected route redirects to login
5. Test token refresh on 401
```

### 10. `test/core/auth/auth_bloc_test.dart`

Tests for AuthBloc:

```dart
// Test:
// - initial state is AuthInitial
// - checkRequested emits authenticated when user exists
// - checkRequested emits unauthenticated when no user
// - loginRequested emits loading then authenticated on success
// - loginRequested emits loading then error on failure
// - logoutRequested emits unauthenticated
// - userChanged updates state
// - listens to authStateChanges stream
```

---

## What We're NOT Doing

- **No Firebase Auth/Supabase Auth as committed dependencies** — template stays backend-agnostic
- **No login/signup UI committed** — too app-specific (branding, design system). Document patterns only.
- **No social login button widgets** — depend on provider SDKs. Show examples in docs.
- **No biometric implementation** — optional feature, document the pattern
- **No email verification flow** — provider-specific, document only
- **No account linking** — advanced pattern, document only

## How It Fits Together

```
┌─────────────────────────────────────────┐
│                  App                      │
│                                           │
│  ┌────────────┐      ┌────────────┐      │
│  │ Login Page │      │ Home Page  │      │
│  │ (public)   │      │ (protected)│      │
│  └─────┬──────┘      └─────┬──────┘      │
│        │                   │              │
│        └────────┬──────────┘              │
│                 │                         │
│          ┌──────▼──────┐                  │
│          │  GoRouter   │                  │
│          │ + authGuard │                  │
│          └──────┬──────┘                  │
│                 │                         │
│          ┌──────▼──────┐                  │
│          │  AuthBloc   │  ← Drives UI     │
│          │             │    decisions     │
│          └──────┬──────┘                  │
│                 │                         │
│  ┌──────────────▼──────────────┐         │
│  │      AuthRepository          │         │
│  │  (Firebase / Supabase / API) │         │
│  └──────────────┬───────────────┘         │
│                 │                         │
│  ┌──────────────▼──────────────┐         │
│  │     AuthTokenManager         │         │
│  │  (flutter_secure_storage)    │         │
│  └──────────────────────────────┘         │
│                                           │
│  ┌──────────────────────────────┐         │
│  │     AuthInterceptor          │         │
│  │  (attaches token, handles 401)│        │
│  └──────────────────────────────┘         │
│                                           │
└───────────────────────────────────────────┘
```

## Structure After Implementation

```
flutter-project-template/
├── lib/
│   └── core/
│       ├── auth/
│       │   ├── auth_repository.dart    # Abstract interface + AuthUser
│       │   ├── auth_bloc.dart          # Auth state management
│       │   ├── auth_event.dart         # Freezed events
│       │   └── auth_state.dart         # Freezed states
│       └── routes/
│           ├── app_router.dart         # Updated with auth guard example
│           └── auth_guard.dart         # Route protection
├── test/
│   └── core/
│       └── auth/
│           └── auth_bloc_test.dart
├── docs/
│   └── authentication.md
└── .claude/
    └── commands/
        └── add-auth.md
```

## Dependencies on Issue #2 (Database)

Auth does **not** depend on database — they're orthogonal:
- Auth manages identity (who is the user)
- Database manages data (what the user owns)

However, they integrate at the repository level:
- After auth, repositories use `authBloc.state.user.id` to scope queries
- Logout should clear cache (`LocalCacheService.clear`)

The auth guard and auth BLoC work independently of the database layer.

## Estimated Work

~10 files. AuthBloc and auth guard are real code. Provider implementations are documentation only. One focused session.
