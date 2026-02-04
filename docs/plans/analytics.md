# Plan: Analytics Integration Documentation & Patterns

## Goal

Add analytics infrastructure with an abstract interface pattern, allowing projects to swap providers without changing business logic. Provide documentation, starter code, and Claude commands for common analytics workflows.

## Current State

- Sentry configured for error monitoring (in `main.dart`)
- No analytics service abstraction
- No event tracking patterns
- No screen view tracking

## Approach

Follow the same **abstract interface + concrete implementation** pattern used elsewhere in this template (like `DatabaseService` concept). Create:

1. Abstract `AnalyticsService` interface
2. Firebase Analytics implementation (most common)
3. Type-safe event catalog (no magic strings)
4. Route observer for automatic screen tracking
5. Documentation explaining patterns and privacy considerations

---

## Files to Create

### 1. `docs/analytics.md`
Comprehensive documentation covering:
- Analytics architecture overview (abstract interface pattern)
- Supported providers (Firebase Analytics, Mixpanel, Amplitude, PostHog)
- Event naming conventions
  - snake_case for event names
  - Consistent property names across events
  - Maximum 25 custom parameters (Firebase limit)
- Standard events to track
  - Screen views (automatic via RouteObserver)
  - User actions (button_tapped, form_submitted)
  - Errors (error_occurred with type/message)
  - Feature usage (feature_used with feature_name)
  - Conversions (signup_completed, purchase_completed)
- User properties and identification
  - When to call setUserId (after auth)
  - Standard properties (plan_type, account_age, etc.)
- Privacy considerations
  - GDPR: user consent before tracking
  - Data minimization: don't track PII
  - User opt-out mechanism
- Testing analytics (debug mode, DebugView in Firebase)

### 2. `lib/core/analytics/analytics_service.dart`
Abstract interface:
```dart
abstract class AnalyticsService {
  /// Log a custom event with optional parameters
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]);

  /// Set the user ID for attribution (null to clear)
  Future<void> setUserId(String? userId);

  /// Set a user property for segmentation
  Future<void> setUserProperty(String name, String value);

  /// Log a screen view (usually called automatically by RouteObserver)
  Future<void> logScreenView(String screenName, [String? screenClass]);

  /// Enable or disable analytics collection (for user consent)
  Future<void> setAnalyticsCollectionEnabled(bool enabled);
}
```

### 3. `lib/core/analytics/analytics_events.dart`
Type-safe event catalog:
```dart
/// Centralized event names to prevent typos and ensure consistency.
/// Add new events here, not as inline strings.
class AnalyticsEvents {
  AnalyticsEvents._(); // Prevent instantiation

  // Screen views (automatic, but listed for reference)
  static const screenView = 'screen_view';

  // User actions
  static const buttonTapped = 'button_tapped';
  static const formSubmitted = 'form_submitted';
  static const searchPerformed = 'search_performed';

  // Feature usage
  static const featureUsed = 'feature_used';
  static const itemCreated = 'item_created';
  static const itemDeleted = 'item_deleted';
  static const itemUpdated = 'item_updated';

  // Errors
  static const errorOccurred = 'error_occurred';

  // Auth
  static const loginCompleted = 'login_completed';
  static const signupCompleted = 'signup_completed';
  static const logoutCompleted = 'logout_completed';
}

/// Standard parameter names for consistency
class AnalyticsParams {
  AnalyticsParams._();

  static const buttonName = 'button_name';
  static const screenName = 'screen_name';
  static const featureName = 'feature_name';
  static const itemId = 'item_id';
  static const itemType = 'item_type';
  static const errorType = 'error_type';
  static const errorMessage = 'error_message';
  static const method = 'method'; // login method: email, google, apple
}
```

### 4. `lib/core/analytics/firebase_analytics_service.dart`
Firebase Analytics implementation:
```dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'analytics_service.dart';

class FirebaseAnalyticsService implements AnalyticsService {
  final FirebaseAnalytics _analytics;

  FirebaseAnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  @override
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserId(String? userId) async {
    await _analytics.setUserId(id: userId);
  }

  @override
  Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> logScreenView(String screenName, [String? screenClass]) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
  }

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    await _analytics.setAnalyticsCollectionEnabled(enabled);
  }

  /// Get the observer for automatic screen tracking with go_router
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);
}
```

### 5. `lib/core/analytics/noop_analytics_service.dart`
No-op implementation for testing and when user opts out:
```dart
import 'analytics_service.dart';

/// Analytics service that does nothing.
/// Use for: tests, debug builds, users who opt out.
class NoopAnalyticsService implements AnalyticsService {
  @override
  Future<void> logEvent(String name, [Map<String, dynamic>? parameters]) async {}

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty(String name, String value) async {}

  @override
  Future<void> logScreenView(String screenName, [String? screenClass]) async {}

  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {}
}
```

### 6. `lib/core/analytics/analytics_route_observer.dart`
Route observer for automatic screen tracking:
```dart
import 'package:flutter/material.dart';
import 'analytics_service.dart';

/// Route observer that logs screen views automatically.
/// Add to MaterialApp.navigatorObservers or GoRouter.observers.
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analytics;

  AnalyticsRouteObserver(this._analytics);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _logScreenView(newRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _logScreenView(previousRoute);
  }

  void _logScreenView(Route route) {
    final screenName = route.settings.name;
    if (screenName != null && screenName.isNotEmpty) {
      _analytics.logScreenView(screenName);
    }
  }
}
```

### 7. Update `lib/core/di/injection.dart`
Register analytics service:
```dart
// Add to configureDependencies():
getIt.registerLazySingleton<AnalyticsService>(
  () => FirebaseAnalyticsService(),
);
```

### 8. Update `lib/core/routes/app_router.dart`
Add route observer:
```dart
final analyticsService = getIt<AnalyticsService>();
final router = GoRouter(
  observers: [
    AnalyticsRouteObserver(analyticsService),
    // If using FirebaseAnalyticsService, can also use:
    // (analyticsService as FirebaseAnalyticsService).observer,
  ],
  // ... routes
);
```

### 9. `.claude/commands/add-analytics.md`
```markdown
Set up analytics tracking for this project.

Steps:
1. Confirm Firebase project is configured (google-services.json, GoogleService-Info.plist)
2. Ensure firebase_analytics is in pubspec.yaml
3. Register AnalyticsService in DI container
4. Add AnalyticsRouteObserver to router
5. Show example usage in a BLoC

Usage in BLoC:
```dart
final _analytics = getIt<AnalyticsService>();

Future<void> _onItemCreated(ItemCreated event, Emitter emit) async {
  // ... create item logic
  await _analytics.logEvent(
    AnalyticsEvents.itemCreated,
    {AnalyticsParams.itemId: item.id, AnalyticsParams.itemType: 'task'},
  );
}
```
```

### 10. `.claude/commands/add-event.md`
```markdown
Add a new analytics event to the codebase.

Steps:
1. Ask for: event name, description, parameters needed
2. Add event constant to `AnalyticsEvents` class
3. Add any new parameter names to `AnalyticsParams` class
4. Show usage example
5. Remind to document in analytics event catalog (if maintaining one)
```

### 11. Update `pubspec.yaml`
Ensure dependency is listed:
```yaml
dependencies:
  firebase_analytics: ^11.0.0
```

---

## What We're NOT Doing

- **No Mixpanel/Amplitude implementations** — document the pattern, users implement their provider
- **No consent UI** — that's app-specific
- **No backend event forwarding** — just client-side SDK integration
- **No A/B testing integration** — separate concern

## Structure After Implementation

```
flutter-project-template/
├── lib/
│   └── core/
│       ├── analytics/
│       │   ├── analytics_service.dart          # Abstract interface
│       │   ├── analytics_events.dart           # Event catalog
│       │   ├── firebase_analytics_service.dart # Firebase impl
│       │   ├── noop_analytics_service.dart     # No-op impl
│       │   └── analytics_route_observer.dart   # Screen tracking
│       ├── di/
│       │   └── injection.dart                  # Updated
│       └── routes/
│           └── app_router.dart                 # Updated
├── docs/
│   └── analytics.md
└── .claude/
    └── commands/
        ├── add-analytics.md
        └── add-event.md
```

## Estimated Work

~11 files. Core infrastructure is small; documentation is the bulk. One focused session.
