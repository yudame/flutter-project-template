Set up analytics tracking for this project.

## Prerequisites

If using Firebase Analytics:
1. Firebase project is configured
2. `google-services.json` in `android/app/`
3. `GoogleService-Info.plist` in `ios/Runner/`

## Steps

### 1. Add Provider Dependency (if using Firebase)

```yaml
# pubspec.yaml
dependencies:
  firebase_analytics: ^11.0.0
```

Then run: `flutter pub get`

### 2. Create Provider Implementation (if using Firebase)

Create `lib/core/analytics/firebase_analytics_service.dart`:

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
}
```

### 3. Register in DI

Update `lib/core/di/injection.dart`:

```dart
import '../analytics/analytics_service.dart';
import '../analytics/noop_analytics_service.dart';
// Or for Firebase:
// import '../analytics/firebase_analytics_service.dart';

// In configureDependencies():
getIt.registerLazySingleton<AnalyticsService>(
  () => NoopAnalyticsService(),  // For development
  // () => FirebaseAnalyticsService(),  // For production
);
```

### 4. Add Route Observer (Optional)

Update `lib/core/routes/app_router.dart`:

```dart
import '../analytics/analytics_route_observer.dart';
import '../analytics/analytics_service.dart';
import '../di/injection.dart';

final appRouter = GoRouter(
  observers: [
    AnalyticsRouteObserver(getIt<AnalyticsService>()),
  ],
  routes: [...],
);
```

### 5. Use in BLoC/Repository

```dart
import 'package:flutter_template/core/analytics/analytics_service.dart';
import 'package:flutter_template/core/analytics/analytics_events.dart';
import 'package:flutter_template/core/di/injection.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AnalyticsService _analytics = getIt<AnalyticsService>();

  Future<void> _onItemCreated(Item item, Emitter<HomeState> emit) async {
    // ... business logic

    await _analytics.logEvent(AnalyticsEvents.itemCreated, {
      AnalyticsParams.itemId: item.id,
      AnalyticsParams.itemType: 'task',
    });
  }
}
```

## Verify Setup

1. Run app in debug mode
2. Perform tracked actions
3. For Firebase: Check Firebase Console > Analytics > DebugView
4. For NoopAnalyticsService: Add print statements temporarily to verify calls
