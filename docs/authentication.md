# Authentication

This guide covers authentication patterns for Flutter apps using this template. The template provides an abstract `AuthRepository` interface and `AuthBloc` for state management — you implement the concrete provider (Firebase, Supabase, or custom REST API).

## Architecture Overview

```
┌─────────────────────────────────────────┐
│                  App                     │
│                                          │
│  ┌────────────┐      ┌────────────┐     │
│  │ Login Page │      │ Home Page  │     │
│  │ (public)   │      │ (protected)│     │
│  └─────┬──────┘      └─────┬──────┘     │
│        │                   │             │
│        └────────┬──────────┘             │
│                 │                        │
│          ┌──────▼──────┐                 │
│          │  GoRouter   │                 │
│          │ + authGuard │                 │
│          └──────┬──────┘                 │
│                 │                        │
│          ┌──────▼──────┐                 │
│          │  AuthBloc   │  ← Drives UI    │
│          │             │    decisions    │
│          └──────┬──────┘                 │
│                 │                        │
│  ┌──────────────▼──────────────┐        │
│  │      AuthRepository          │        │
│  │  (Firebase / Supabase / API) │        │
│  └──────────────┬───────────────┘        │
│                 │                        │
│  ┌──────────────▼──────────────┐        │
│  │     AuthTokenManager         │        │
│  │  (flutter_secure_storage)    │        │
│  └──────────────────────────────┘        │
│                                          │
│  ┌──────────────────────────────┐        │
│  │     AuthInterceptor          │        │
│  │  (attaches token, handles 401)│       │
│  └──────────────────────────────┘        │
│                                          │
└──────────────────────────────────────────┘
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `AuthBloc` | `lib/core/auth/` | Manages auth state across the app |
| `AuthRepository` | `lib/core/auth/` | Abstract interface for auth operations |
| `AuthTokenManager` | `lib/core/network/` | Stores/retrieves tokens securely |
| `AuthInterceptor` | `lib/core/network/` | Attaches tokens, handles 401 refresh |
| `authGuard` | `lib/core/routes/` | Protects routes from unauthenticated access |

## Auth State Machine

```
                    ┌─────────────┐
                    │   initial   │
                    └──────┬──────┘
                           │ checkRequested
                           ▼
                    ┌─────────────┐
              ┌─────│   loading   │─────┐
              │     └─────────────┘     │
              │                         │
         user exists              no user
              │                         │
              ▼                         ▼
     ┌────────────────┐      ┌──────────────────┐
     │ authenticated  │      │ unauthenticated  │
     └───────┬────────┘      └────────┬─────────┘
             │                        │
        logoutRequested          loginRequested
             │                        │
             ▼                        ▼
     ┌──────────────────┐      ┌─────────────┐
     │ unauthenticated  │      │   loading   │
     └──────────────────┘      └─────────────┘
```

### Auth States

```dart
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(AuthUser user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}
```

### Auth Events

```dart
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

## Token Storage

Tokens are stored using `flutter_secure_storage`:
- **iOS**: Keychain with `first_unlock` accessibility
- **Android**: EncryptedSharedPreferences

```dart
// AuthTokenManager handles:
await authTokenManager.saveTokens(
  accessToken: token,
  refreshToken: refresh,
  expiry: DateTime.now().add(Duration(hours: 1)),
);

// On logout:
await authTokenManager.clearTokens();
```

### Why Secure Storage?

- Encrypted at rest
- Not included in backups (iOS)
- Cleared on app uninstall
- Protected by device lock

## Protected Routes

Use `authGuard` with go_router to protect routes:

```dart
final appRouter = GoRouter(
  redirect: authGuard(
    authBloc: getIt<AuthBloc>(),
    loginPath: '/login',
    allowedPaths: ['/login', '/signup', '/forgot-password'],
  ),
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
```

### How Auth Guard Works

1. Checks current `AuthBloc` state
2. If path is in `allowedPaths`, allows access (unless authenticated user tries to access login → redirects to home)
3. If unauthenticated and path not allowed, redirects to `loginPath`
4. If authenticated, allows access

## Provider Setup

### Firebase Auth

1. **Add dependencies:**
```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  google_sign_in: ^6.0.0  # For Google OAuth
```

2. **Create concrete repository:**
```dart
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthTokenManager _tokenManager;

  FirebaseAuthRepository({required AuthTokenManager tokenManager})
      : _tokenManager = tokenManager;

  @override
  Stream<AuthUser?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      return AuthUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
      );
    });
  }

  @override
  Future<AuthUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
    );
  }

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;

      // Save token for API calls
      final token = await user.getIdToken();
      await _tokenManager.saveTokens(
        accessToken: token!,
        refreshToken: user.refreshToken ?? '',
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );

      return Result.success(AuthUser(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        emailVerified: user.emailVerified,
      ));
    } on FirebaseAuthException catch (e) {
      return Result.failure(_mapFirebaseError(e.code));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _auth.signOut();
      await _tokenManager.clearTokens();
      return const Result.success(null);
    } catch (e) {
      return Result.failure('Sign out failed: $e');
    }
  }

  // ... implement other methods
}
```

3. **Register in DI:**
```dart
getIt.registerLazySingleton<AuthRepository>(
  () => FirebaseAuthRepository(tokenManager: getIt<AuthTokenManager>()),
);

getIt.registerLazySingleton<AuthBloc>(
  () => AuthBloc(authRepository: getIt<AuthRepository>()),
);
```

### Supabase Auth

1. **Add dependency:**
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

2. **Create concrete repository:**
```dart
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  final AuthTokenManager _tokenManager;

  SupabaseAuthRepository({
    required SupabaseClient client,
    required AuthTokenManager tokenManager,
  })  : _client = client,
        _tokenManager = tokenManager;

  @override
  Stream<AuthUser?> get authStateChanges {
    return _client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) return null;
      return AuthUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        photoUrl: user.userMetadata?['avatar_url'],
        emailVerified: user.emailConfirmedAt != null,
      );
    });
  }

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final session = response.session!;
      await _tokenManager.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        expiry: DateTime.fromMillisecondsSinceEpoch(
          session.expiresAt! * 1000,
        ),
      );

      final user = response.user!;
      return Result.success(AuthUser(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'],
        emailVerified: user.emailConfirmedAt != null,
      ));
    } on AuthException catch (e) {
      return Result.failure(e.message);
    }
  }

  // ... implement other methods
}
```

### Custom REST API

```dart
class ApiAuthRepository implements AuthRepository {
  final DioClient _client;
  final AuthTokenManager _tokenManager;
  final _authController = StreamController<AuthUser?>.broadcast();

  ApiAuthRepository({
    required DioClient client,
    required AuthTokenManager tokenManager,
  })  : _client = client,
        _tokenManager = tokenManager;

  @override
  Stream<AuthUser?> get authStateChanges => _authController.stream;

  @override
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      await _tokenManager.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        expiry: DateTime.now().add(
          Duration(seconds: data['expires_in']),
        ),
      );

      final user = AuthUser(
        id: data['user']['id'],
        email: data['user']['email'],
        displayName: data['user']['name'],
      );

      _authController.add(user);
      return Result.success(user);
    } catch (e) {
      return Result.failure('Login failed: $e');
    }
  }

  @override
  Future<Result<String>> refreshToken() async {
    try {
      final refreshToken = await _tokenManager.getRefreshToken();
      if (refreshToken == null) {
        return const Result.failure('No refresh token');
      }

      final response = await _client.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final data = response.data;
      await _tokenManager.saveTokens(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        expiry: DateTime.now().add(
          Duration(seconds: data['expires_in']),
        ),
      );

      return Result.success(data['access_token']);
    } catch (e) {
      return Result.failure('Token refresh failed: $e');
    }
  }

  // ... implement other methods
}
```

## Logout Flow

Proper logout clears all user data:

```dart
Future<void> _onLogoutRequested(
  AuthLogoutRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthState.loading());

  // 1. Sign out from provider
  await _authRepository.signOut();

  // 2. Clear tokens (handled by repository)
  // 3. Clear cached data
  await getIt<LocalCacheService>().clear('items');
  await getIt<LocalCacheService>().clear('user_data');

  // 4. Clear offline queue
  await getIt<OfflineQueue>().clear();

  emit(const AuthState.unauthenticated());

  // Router will redirect to login via authGuard
}
```

## OAuth (Social Login)

### Google Sign-In

```dart
Future<Result<AuthUser>> signInWithOAuth(OAuthProvider provider) async {
  if (provider == OAuthProvider.google) {
    final googleSignIn = GoogleSignIn();
    final account = await googleSignIn.signIn();
    if (account == null) {
      return const Result.failure('Sign in cancelled');
    }

    final auth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    // ... handle result
  }
}
```

### Apple Sign-In

```dart
// Requires sign_in_with_apple package
Future<Result<AuthUser>> signInWithApple() async {
  final appleCredential = await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
  );

  final oauthCredential = OAuthProvider('apple.com').credential(
    idToken: appleCredential.identityToken,
    accessToken: appleCredential.authorizationCode,
  );

  final result = await _auth.signInWithCredential(oauthCredential);
  // ... handle result
}
```

## Offline Auth

Auth state persists across app restarts:

```dart
@override
Future<void> _onCheckRequested(
  AuthCheckRequested event,
  Emitter<AuthState> emit,
) async {
  emit(const AuthState.loading());

  // Check for valid tokens first (works offline)
  final hasTokens = await _tokenManager.hasValidTokens();
  if (!hasTokens) {
    emit(const AuthState.unauthenticated());
    return;
  }

  // Try to get current user (may fail offline)
  final user = await _authRepository.getCurrentUser();
  if (user != null) {
    emit(AuthState.authenticated(user));
  } else {
    // Tokens exist but user fetch failed (offline)
    // Stay authenticated with cached user data
    final cachedUser = await _getCachedUser();
    if (cachedUser != null) {
      emit(AuthState.authenticated(cachedUser));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }
}
```

## Biometric Authentication (Optional)

For apps requiring biometric unlock:

```dart
// Add to pubspec.yaml:
// local_auth: ^2.0.0

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> canUseBiometrics() async {
    return await _auth.canCheckBiometrics &&
           await _auth.isDeviceSupported();
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}
```

Use biometrics to unlock secure storage, not as primary auth:
1. User logs in with email/password
2. Tokens stored in secure storage
3. On app resume, biometric unlocks token access
4. Tokens used for API requests

## Security Considerations

### Token Rotation

Always rotate refresh tokens on use:
```dart
// Server-side: Issue new refresh token with each access token
// Client-side: Store new refresh token from each refresh response
```

### Session Invalidation

When user changes password or admin revokes access:
1. Server invalidates all refresh tokens
2. Next API call returns 401
3. `AuthInterceptor` catches 401, attempts refresh
4. Refresh fails → clear tokens → emit `unauthenticated`

### Secure Storage Options

```dart
const FlutterSecureStorage(
  aOptions: AndroidOptions(
    encryptedSharedPreferences: true,
    // Or use KeyStore for additional security:
    // keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
  ),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    // More restrictive:
    // accessibility: KeychainAccessibility.when_unlocked,
  ),
);
```

## Testing Auth

```dart
void main() {
  late MockAuthRepository mockAuthRepository;
  late AuthBloc authBloc;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    when(() => mockAuthRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
    authBloc = AuthBloc(authRepository: mockAuthRepository);
  });

  blocTest<AuthBloc, AuthState>(
    'emits [loading, authenticated] when login succeeds',
    build: () {
      when(() => mockAuthRepository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      )).thenAnswer((_) async => Result.success(testUser));
      return authBloc;
    },
    act: (bloc) => bloc.add(const AuthEvent.loginRequested(
      email: 'test@example.com',
      password: 'password123',
    )),
    expect: () => [
      const AuthState.loading(),
      AuthState.authenticated(testUser),
    ],
  );
}
```

## Quick Start

1. Choose your auth provider (Firebase, Supabase, or REST API)
2. Create concrete `AuthRepository` implementation
3. Register in DI (`lib/core/di/injection.dart`)
4. Add `authGuard` to your router
5. Create login/signup UI pages
6. Handle auth state in your app

See the provider-specific sections above for implementation details.
