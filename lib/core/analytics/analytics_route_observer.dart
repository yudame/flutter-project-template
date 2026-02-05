import 'package:flutter/material.dart';

import 'analytics_service.dart';

/// Route observer that automatically logs screen views.
///
/// Add to your router to track screen views without manual calls:
///
/// ```dart
/// final router = GoRouter(
///   observers: [
///     AnalyticsRouteObserver(getIt<AnalyticsService>()),
///   ],
///   routes: [...],
/// );
/// ```
///
/// Screen names are taken from [RouteSettings.name].
/// Make sure your routes have names defined:
///
/// ```dart
/// GoRoute(
///   path: '/profile',
///   name: 'profile',  // This becomes the screen name
///   builder: (context, state) => const ProfilePage(),
/// ),
/// ```
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analytics;

  /// Creates a route observer that logs screen views.
  ///
  /// [analytics] - The analytics service to use for logging.
  AnalyticsRouteObserver(this._analytics);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Log the screen we're returning to
    if (previousRoute != null) {
      _logScreenView(previousRoute);
    }
  }

  void _logScreenView(Route<dynamic> route) {
    final screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      _analytics.logScreenView(
        screenName,
        route.runtimeType.toString(),
      );
    }
  }
}
