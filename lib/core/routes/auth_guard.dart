import 'package:go_router/go_router.dart';

import '../auth/auth_bloc.dart';
import '../auth/auth_state.dart';

/// Creates a redirect function for protecting routes.
///
/// Use with [GoRouter.redirect] to:
/// - Redirect unauthenticated users to login
/// - Redirect authenticated users away from login page
///
/// Example:
/// ```dart
/// final appRouter = GoRouter(
///   redirect: authGuard(
///     authBloc: getIt<AuthBloc>(),
///     loginPath: '/login',
///     allowedPaths: ['/login', '/signup', '/forgot-password'],
///   ),
///   routes: [
///     GoRoute(
///       path: '/login',
///       name: 'login',
///       builder: (context, state) => const LoginPage(),
///     ),
///     GoRoute(
///       path: '/',
///       name: 'home',
///       builder: (context, state) => const HomePage(),
///     ),
///   ],
/// );
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

    // While checking auth, don't redirect yet
    if (authState is AuthInitial || authState is AuthLoading) {
      return null;
    }

    // Redirect unauthenticated users to login
    if (authState is AuthUnauthenticated || authState is AuthError) {
      return loginPath;
    }

    // Allow authenticated users to proceed
    return null;
  };
}

/// Type alias for go_router redirect function.
typedef GoRouterRedirect = String? Function(
  dynamic context,
  GoRouterState state,
);
