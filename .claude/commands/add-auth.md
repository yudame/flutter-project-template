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
  sign_in_with_apple: ^6.0.0  # If using Apple Sign-In
```

**Supabase:**
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

Then run: `flutter pub get`

### 2. Create Concrete AuthRepository

Create `lib/core/auth/{provider}_auth_repository.dart` implementing `AuthRepository`.

See `docs/authentication.md` for complete implementation examples for each provider.

Key methods to implement:
- `getCurrentUser` — get current user (null if not authenticated)
- `signInWithEmail` — email/password login
- `signUpWithEmail` — create account
- `signInWithOAuth` — social login
- `sendPasswordReset` — forgot password email
- `signOut` — logout
- `authStateChanges` — stream of auth state
- `refreshToken` — refresh access token

### 3. Register in DI

Update `lib/core/di/injection.dart`:

```dart
import '../auth/auth_bloc.dart';
import '../auth/auth_repository.dart';
import '../auth/{provider}_auth_repository.dart';

// In configureDependencies():
getIt.registerLazySingleton<AuthRepository>(
  () => {Provider}AuthRepository(tokenManager: getIt<AuthTokenManager>()),
);

getIt.registerLazySingleton<AuthBloc>(
  () => AuthBloc(authRepository: getIt<AuthRepository>()),
);
```

### 4. Set Up Route Guard

Update `lib/core/routes/app_router.dart`:

1. Uncomment the auth imports:
```dart
import '../auth/auth_bloc.dart';
import '../di/injection.dart';
import 'auth_guard.dart';
```

2. Uncomment the redirect:
```dart
redirect: authGuard(
  authBloc: getIt<AuthBloc>(),
  loginPath: '/login',
  allowedPaths: ['/login', '/signup', '/forgot-password'],
),
```

3. Add login route:
```dart
GoRoute(
  path: '/login',
  name: 'login',
  builder: (context, state) => const LoginPage(),
),
```

### 5. Create Auth UI

Create in `lib/features/auth/presentation/pages/`:

**login_page.dart:**
```dart
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _login() {
    context.read<AuthBloc>().add(AuthEvent.loginRequested(
      email: _emailController.text,
      password: _passwordController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        state.whenOrNull(
          error: (message) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          ),
        );
      },
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  final isLoading = state is AuthLoading;
                  return ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    child: isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Login'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create similarly:
- `signup_page.dart` — registration form
- `forgot_password_page.dart` — password reset

### 6. Initialize Auth Check

In `main.dart` or app initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // Check initial auth state
  getIt<AuthBloc>().add(const AuthEvent.checkRequested());

  runApp(const MyApp());
}
```

### 7. Wire Up Token Refresh (REST API only)

If using custom REST API, update `AuthTokenManager.refreshAccessToken()`:

```dart
Future<String> refreshAccessToken() async {
  final refreshToken = await getRefreshToken();
  if (refreshToken == null) {
    throw AuthException('No refresh token available');
  }

  final response = await _dio.post(
    '/auth/refresh',
    data: {'refresh_token': refreshToken},
  );

  final data = response.data;
  await saveTokens(
    accessToken: data['access_token'],
    refreshToken: data['refresh_token'],
    expiry: DateTime.now().add(Duration(seconds: data['expires_in'])),
  );

  return data['access_token'];
}
```

## Verification

1. Run `flutter analyze` — no errors
2. Run `flutter test` — all tests pass
3. Test login flow end-to-end
4. Test logout clears state and redirects to login
5. Test protected route redirects unauthenticated users to login
6. Test token refresh on 401 (if using REST API)

## Reference

Full documentation: `docs/authentication.md`
