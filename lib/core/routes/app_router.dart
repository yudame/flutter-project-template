import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
// Auth imports (uncomment when using authentication):
// import '../auth/auth_bloc.dart';
// import '../di/injection.dart';
// import 'auth_guard.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  // Auth guard (uncomment when using authentication):
  // redirect: authGuard(
  //   authBloc: getIt<AuthBloc>(),
  //   loginPath: '/login',
  //   allowedPaths: ['/login', '/signup', '/forgot-password'],
  // ),
  routes: [
    // Login route (uncomment when using authentication):
    // GoRoute(
    //   path: '/login',
    //   name: 'login',
    //   builder: (context, state) => const LoginPage(),
    // ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    // Add more routes here as you add features
    // Example:
    // GoRoute(
    //   path: '/items/:id',
    //   name: 'item-detail',
    //   builder: (context, state) {
    //     final id = state.pathParameters['id']!;
    //     return ItemDetailPage(id: id);
    //   },
    // ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(state.uri.toString()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
