# Analytics

This guide covers analytics patterns for Flutter apps using this template.

## Overview

The template provides an **abstract analytics interface** that allows you to:
- Swap analytics providers without changing business logic
- Use a no-op implementation for tests and debug builds
- Track events with type-safe event names
- Automatically track screen views via route observer

## Architecture

```
lib/core/analytics/
├── analytics_service.dart          # Abstract interface
├── analytics_events.dart           # Type-safe event names
├── noop_analytics_service.dart     # No-op implementation (default)
├── firebase_analytics_service.dart # Firebase implementation (add firebase_analytics)
└── analytics_route_observer.dart   # Automatic screen tracking
```

## Setup

### 1. Choose Your Provider

The template includes a **no-op implementation** by default. To add real analytics:

**Firebase Analytics** (recommended):
```yaml
# pubspec.yaml
dependencies:
  firebase_analytics: ^11.0.0
```

**Other providers** (Mixpanel, Amplitude, PostHog):
- Implement the `AnalyticsService` interface
- Follow the same pattern as `FirebaseAnalyticsService`

### 2. Register in DI

Update `lib/core/di/injection.dart`:

```dart
// For development/testing (no-op):
getIt.registerLazySingleton<AnalyticsService>(
  () => NoopAnalyticsService(),
);

// For production with Firebase:
getIt.registerLazySingleton<AnalyticsService>(
  () => FirebaseAnalyticsService(),
);
```

### 3. Add Route Observer (Optional)

For automatic screen view tracking, update `lib/core/routes/app_router.dart`:

```dart
final router = GoRouter(
  observers: [
    AnalyticsRouteObserver(getIt<AnalyticsService>()),
  ],
  // ... routes
);
```

## Usage

### Logging Events

```dart
import 'package:flutter_template/core/analytics/analytics_service.dart';
import 'package:flutter_template/core/analytics/analytics_events.dart';

final analytics = getIt<AnalyticsService>();

// Simple event
await analytics.logEvent(AnalyticsEvents.buttonTapped, {
  AnalyticsParams.buttonName: 'submit',
  AnalyticsParams.screenName: 'checkout',
});

// Feature usage
await analytics.logEvent(AnalyticsEvents.featureUsed, {
  AnalyticsParams.featureName: 'dark_mode',
});

// Item action
await analytics.logEvent(AnalyticsEvents.itemCreated, {
  AnalyticsParams.itemId: item.id,
  AnalyticsParams.itemType: 'task',
});
```

### In BLoCs

```dart
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final AnalyticsService _analytics;

  HomeBloc({required AnalyticsService analytics})
      : _analytics = analytics,
        super(const HomeState.initial()) {
    on<HomeEvent>((event, emit) async {
      await event.when(
        createItem: (title) => _onCreateItem(title, emit),
        // ...
      );
    });
  }

  Future<void> _onCreateItem(String title, Emitter<HomeState> emit) async {
    // ... create item logic

    // Track analytics
    await _analytics.logEvent(AnalyticsEvents.itemCreated, {
      AnalyticsParams.itemType: 'task',
    });
  }
}
```

### User Identification

```dart
// After user logs in
await analytics.setUserId(user.id);

// Set user properties for segmentation
await analytics.setUserProperty('plan_type', user.planType);
await analytics.setUserProperty('account_created', user.createdAt.toIso8601String());

// On logout
await analytics.setUserId(null);
```

### Screen Views

Screen views are tracked automatically if you add `AnalyticsRouteObserver` to your router. For manual tracking:

```dart
await analytics.logScreenView('profile', 'ProfilePage');
```

## Event Naming Conventions

### Event Names

Use `snake_case` for all event names:

| Category | Event Name | Description |
|----------|-----------|-------------|
| User Actions | `button_tapped` | User tapped a button |
| User Actions | `form_submitted` | User submitted a form |
| User Actions | `search_performed` | User performed a search |
| Feature Usage | `feature_used` | User used a feature |
| CRUD | `item_created` | Item was created |
| CRUD | `item_updated` | Item was updated |
| CRUD | `item_deleted` | Item was deleted |
| Auth | `login_completed` | User logged in |
| Auth | `signup_completed` | User signed up |
| Auth | `logout_completed` | User logged out |
| Errors | `error_occurred` | An error occurred |

### Parameters

Use consistent parameter names across events:

| Parameter | Type | Description |
|-----------|------|-------------|
| `button_name` | String | Name of the button tapped |
| `screen_name` | String | Screen where action occurred |
| `feature_name` | String | Feature that was used |
| `item_id` | String | ID of the item affected |
| `item_type` | String | Type of item (task, note, etc.) |
| `error_type` | String | Type of error |
| `error_message` | String | Error message (sanitized) |
| `method` | String | Method used (email, google, apple) |

### Adding New Events

Add to `lib/core/analytics/analytics_events.dart`:

```dart
class AnalyticsEvents {
  // ... existing events

  // Add your new event
  static const myNewEvent = 'my_new_event';
}

class AnalyticsParams {
  // ... existing params

  // Add any new parameters
  static const myNewParam = 'my_new_param';
}
```

## Privacy Considerations

### GDPR Compliance

1. **Get consent before tracking**:
   ```dart
   // Show consent dialog, then:
   await analytics.setAnalyticsCollectionEnabled(userConsented);
   ```

2. **Honor opt-out requests**:
   ```dart
   // User opts out
   await analytics.setAnalyticsCollectionEnabled(false);
   await analytics.setUserId(null);
   ```

### Data Minimization

- **Don't track PII** (emails, names, phone numbers)
- **Use IDs instead of values** (user_id not email)
- **Sanitize error messages** (remove sensitive data)
- **Consider local-only events** for sensitive features

### What NOT to Track

- Passwords or authentication tokens
- Personal health information
- Financial account numbers
- Location data (without explicit consent)
- Content of user messages/notes

## Testing

### Using NoopAnalyticsService

In tests, the `NoopAnalyticsService` is used automatically:

```dart
void main() {
  late MockAnalyticsService mockAnalytics;

  setUp(() {
    mockAnalytics = MockAnalyticsService();
    getIt.registerSingleton<AnalyticsService>(mockAnalytics);
  });

  test('tracks item creation', () async {
    // ... perform action

    verify(() => mockAnalytics.logEvent(
      AnalyticsEvents.itemCreated,
      any(),
    )).called(1);
  });
}
```

### Firebase DebugView

For Firebase Analytics, enable debug mode:

```bash
# iOS
flutter run --dart-define=FIREBASE_ANALYTICS_DEBUG=true

# Android
adb shell setprop debug.firebase.analytics.app com.yourcompany.yourapp
```

Then view events in real-time in Firebase Console > Analytics > DebugView.

## Provider Implementations

### Firebase Analytics

```dart
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

### Other Providers

To implement for Mixpanel, Amplitude, or other providers:

1. Create `lib/core/analytics/{provider}_analytics_service.dart`
2. Implement the `AnalyticsService` interface
3. Map the interface methods to provider SDK calls
4. Register in DI

## Best Practices

1. **Use type-safe event names** from `AnalyticsEvents`
2. **Keep events focused** - one action = one event
3. **Use consistent parameters** from `AnalyticsParams`
4. **Don't over-track** - focus on actionable insights
5. **Document your events** - maintain an event catalog
6. **Test analytics code** - verify events are logged correctly
7. **Respect user privacy** - follow platform guidelines
