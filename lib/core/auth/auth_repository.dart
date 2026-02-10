import '../utils/result.dart';

/// Abstract authentication repository.
///
/// Implement for your auth provider: Firebase, Supabase, REST API.
/// AuthBloc depends on this interface, not concrete implementations.
///
/// See `docs/authentication.md` for provider setup guides.
///
/// Example (Firebase):
/// ```dart
/// class FirebaseAuthRepository implements AuthRepository {
///   final FirebaseAuth _auth = FirebaseAuth.instance;
///   // ... see docs/authentication.md for full implementation
/// }
/// ```
abstract class AuthRepository {
  /// Get the currently authenticated user (null if not authenticated).
  Future<AuthUser?> getCurrentUser();

  /// Sign in with email and password.
  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Create a new account with email and password.
  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in with OAuth provider (Google, Apple, GitHub, etc.).
  Future<Result<AuthUser>> signInWithOAuth(OAuthProvider provider);

  /// Send password reset email.
  Future<Result<void>> sendPasswordReset(String email);

  /// Sign out the current user.
  Future<Result<void>> signOut();

  /// Stream of auth state changes.
  ///
  /// Emits the current user when auth state changes (login, logout, token refresh).
  /// Emits null when user is signed out.
  Stream<AuthUser?> get authStateChanges;

  /// Refresh the current user's access token.
  ///
  /// Returns the new access token on success.
  Future<Result<String>> refreshToken();
}

/// Minimal user model for auth state.
///
/// Contains only the essential fields needed for auth decisions.
/// Extend or create a separate UserProfile model for additional user data.
class AuthUser {
  /// Unique user identifier from the auth provider.
  final String id;

  /// User's email address.
  final String email;

  /// User's display name (optional).
  final String? displayName;

  /// URL to user's profile photo (optional).
  final String? photoUrl;

  /// Whether the user's email has been verified.
  final bool emailVerified;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  @override
  String toString() => 'AuthUser(id: $id, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          displayName == other.displayName &&
          photoUrl == other.photoUrl &&
          emailVerified == other.emailVerified;

  @override
  int get hashCode => Object.hash(id, email, displayName, photoUrl, emailVerified);
}

/// Supported OAuth providers.
enum OAuthProvider {
  /// Google Sign-In
  google,

  /// Apple Sign-In
  apple,

  /// GitHub OAuth
  github,
}
