# Push Notifications

This guide covers integrating push notifications into a Flutter app using Firebase Cloud Messaging (FCM). It covers the architecture, platform setup, notification handling across all app states, permission management, token lifecycle, and deep linking.

> **Always check official docs for the latest SDK versions and API changes.** Links are provided throughout and collected in the [Reference Links](#reference-links) section.

## Architecture Overview

```
┌──────────┐       ┌──────────┐       ┌────────────────┐
│  Mobile   │◄─────►│   API    │──────►│  FCM / APNs    │
│   App     │       │  Server  │       │  Push Service   │
└──────────┘       └──────────┘       └────────────────┘
   Receive &        Store tokens       Deliver messages
   display          Trigger sends      Token management
   Handle taps      Payload design     Platform routing
   Permissions      Topic management   Retry/throttling
```

The app registers for push notifications, receives a device token from FCM, and sends it to your server. Your server sends push requests to FCM. The app handles incoming notifications across three states: foreground, background, and terminated.

## Responsibility Matrix

| Concern | Owner | Notes |
|---------|-------|-------|
| Device token | FCM/APNs | Tokens can rotate at any time; app must handle refresh |
| Token-to-user mapping | API Server | Server stores which tokens belong to which user |
| Notification content | API Server | Server decides what to send and when |
| Delivery | FCM/APNs | Platform handles routing, retry, throttling |
| Display (foreground) | Mobile App | App decides how to show in-app notifications |
| Display (background) | OS | System notification tray; app controls payload |
| Tap handling / deep links | Mobile App | App routes user to correct screen |
| Permission state | Mobile App | App requests and tracks permission status |

## Platform Setup

### Android

1. **Firebase project**: Create at [Firebase Console](https://console.firebase.google.com/)

2. **Add `google-services.json`**: Download from Firebase Console → Project Settings → Android app. Place in `android/app/`.

3. **Gradle configuration**:

   `android/build.gradle`:
   ```groovy
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'  // Check latest
       }
   }
   ```

   `android/app/build.gradle`:
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   ```

4. **Notification channels** (Android 8.0+): Required for notification categorization. Create channels at app startup.

   ```dart
   const AndroidNotificationChannel channel = AndroidNotificationChannel(
     'high_importance_channel',
     'High Importance Notifications',
     description: 'Used for important notifications',
     importance: Importance.high,
   );
   ```

See: [FlutterFire Android setup](https://firebase.flutter.dev/docs/messaging/android-setup)

### iOS

1. **Apple Developer account**: Required for push notifications

2. **Enable Push Notifications capability**: In Xcode → Runner → Signing & Capabilities → + Capability → Push Notifications

3. **Enable Background Modes**: In Xcode → Runner → Signing & Capabilities → Background Modes → check "Remote notifications"

4. **APNs authentication**: In Firebase Console → Project Settings → Cloud Messaging → Apple app configuration. Upload either:
   - **APNs Authentication Key** (recommended, doesn't expire): `.p8` file from Apple Developer → Keys
   - **APNs Certificate**: `.p12` file (expires annually, not recommended)

5. **Provisional authorization** (iOS 12+): Allows "quiet" notifications without explicit permission. Useful for onboarding.

See: [FlutterFire iOS setup](https://firebase.flutter.dev/docs/messaging/apple-integration), [APNs documentation](https://developer.apple.com/documentation/usernotifications)

## Flutter Package Setup

```bash
flutter pub add firebase_core firebase_messaging flutter_local_notifications
```

Initialize Firebase before anything else:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// MUST be top-level function (not a method) — Firebase requirement
// Background isolates can't access instance state
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message (keep it short)
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}
```

See: [`firebase_messaging`](https://pub.dev/packages/firebase_messaging), [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)

## Notification Types

### Notification Messages

Sent with a `notification` key. The OS handles display when the app is in background/terminated.

```json
{
  "notification": {
    "title": "New message",
    "body": "Alice sent you a photo"
  }
}
```

- Automatically displayed by OS in background/terminated states
- Delivered to `onMessage` in foreground — **you must display manually**
- Limited customization (title, body, image)

### Data Messages

Sent with a `data` key only. Always delivered to your app code.

```json
{
  "data": {
    "type": "message",
    "sender": "alice",
    "content": "Hello!"
  }
}
```

- Always delivered to app code in all states
- App controls display entirely
- Use `flutter_local_notifications` to show in notification tray
- More flexible but requires more implementation

### Combined (Notification + Data)

Most common pattern. OS displays the notification; data payload is available on tap.

```json
{
  "notification": {
    "title": "New message",
    "body": "Alice sent you a photo"
  },
  "data": {
    "route": "/messages/123",
    "type": "message",
    "id": "123"
  }
}
```

This is the **recommended approach** for most use cases.

### Silent Push

Data-only with priority settings to trigger background processing without user-visible notification.

```json
{
  "data": {
    "type": "sync",
    "collection": "messages"
  },
  "apns": {
    "headers": { "apns-priority": "5" },
    "payload": { "aps": { "content-available": 1 } }
  },
  "android": {
    "priority": "normal"
  }
}
```

Use for background data sync, cache invalidation, or content pre-fetching. **Note:** iOS throttles silent pushes; delivery is not guaranteed.

See: [FCM message types](https://firebase.google.com/docs/cloud-messaging/concept-options)

## App State Handling

| App State | Notification Message | Data Message |
|-----------|---------------------|--------------|
| **Foreground** | `onMessage` stream — app must display manually | `onMessage` stream |
| **Background** | OS shows notification; tap → `onMessageOpenedApp` | `onBackgroundMessage` handler |
| **Terminated** | OS shows notification; tap → `getInitialMessage()` | `onBackgroundMessage` handler |

### Handling All Three States

```dart
class NotificationHandler {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final GoRouter _router;

  Future<void> initialize() async {
    // 1. Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2. Background tap (app was in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 3. Terminated tap (app was killed)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Show in-app notification or local notification
    // The OS does NOT display these automatically
    _showLocalNotification(message);
  }

  void _handleNotificationTap(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null) {
      _router.push(route);
    }
  }
}
```

## Permission Management

### When to Request

**Never request notification permission on first launch.** Users deny permissions they don't understand.

```
First launch → Skip notification permission
             → User completes onboarding
             → User encounters notification-worthy feature
             → Show contextual prompt explaining value
             → Request system permission
```

### Requesting Permission

```dart
Future<bool> requestPermission() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,  // Set true for quiet notifications (iOS 12+)
  );

  switch (settings.authorizationStatus) {
    case AuthorizationStatus.authorized:
      return true;
    case AuthorizationStatus.provisional:
      return true;  // Quiet notifications granted
    case AuthorizationStatus.denied:
      return false;
    case AuthorizationStatus.notDetermined:
      return false;
  }
}
```

### BLoC Pattern for Permission State

```dart
@freezed
class NotificationPermissionEvent with _$NotificationPermissionEvent {
  const factory NotificationPermissionEvent.checkRequested() = CheckRequested;
  const factory NotificationPermissionEvent.permissionRequested() = PermissionRequested;
}

@freezed
class NotificationPermissionState with _$NotificationPermissionState {
  const factory NotificationPermissionState.initial() = _Initial;
  const factory NotificationPermissionState.granted() = _Granted;
  const factory NotificationPermissionState.denied() = _Denied;
  const factory NotificationPermissionState.provisional() = _Provisional;
  const factory NotificationPermissionState.notDetermined() = _NotDetermined;
}
```

### Handling Denied State

If the user denies, don't re-prompt immediately. Instead:
1. Show a subtle banner explaining what they're missing
2. Provide a button that deep links to app settings
3. Check permission state on app resume

```dart
import 'package:app_settings/app_settings.dart';

// Open system settings for this app
AppSettings.openAppSettings(type: AppSettingsType.notification);
```

See: [iOS provisional authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

## Token Lifecycle

### Registration & Refresh

```dart
class TokenManager {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiClient _api;

  Future<void> initialize() async {
    // Get initial token
    final token = await _messaging.getToken();
    if (token != null) {
      await _syncToken(token);
    }

    // Listen for token refresh (can happen at any time)
    _messaging.onTokenRefresh.listen(_syncToken);
  }

  Future<void> _syncToken(String token) async {
    // Store locally to detect changes
    final stored = await _getStoredToken();
    if (token != stored) {
      await _api.post('/devices/token', data: {'token': token});
      await _storeToken(token);
    }
  }

  Future<void> onLogout() async {
    // Remove token from server on logout
    final token = await _messaging.getToken();
    if (token != null) {
      await _api.delete('/devices/token', data: {'token': token});
    }
  }
}
```

### Multi-Device Considerations

Users may have multiple devices. Your server should:
- Store all active tokens per user (not just the latest)
- Send notifications to all tokens
- Handle `messaging/registration-token-not-registered` errors by removing stale tokens
- Clean up tokens on logout

### Server-Side Token Storage

```
users_devices table:
  user_id     (FK → users)
  fcm_token   (string, unique)
  platform    (ios/android)
  created_at  (timestamp)
  last_seen   (timestamp)
```

## Deep Linking from Notifications

### Payload Convention

Include a `route` field in the `data` payload:

```json
{
  "notification": {
    "title": "Order shipped",
    "body": "Your order #456 has been shipped"
  },
  "data": {
    "route": "/orders/456",
    "type": "order_update",
    "id": "456"
  }
}
```

### go_router Integration

```dart
void _handleNotificationTap(RemoteMessage message) {
  final route = message.data['route'];
  if (route != null && route.isNotEmpty) {
    // Use push to add to stack, or go to replace
    router.push(route);
  }
}
```

### Terminated State Navigation

When the app launches from a notification tap, `getInitialMessage()` fires before the widget tree is built. Handle this carefully:

```dart
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    // Small delay to ensure router is ready
    await Future.delayed(const Duration(milliseconds: 500));
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      final route = message.data['route'];
      if (route != null) {
        router.push(route);
      }
    }
  }
}
```

## Local Notifications

Use [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) for:
- Displaying foreground FCM messages in the notification tray
- Scheduling local reminders
- Customizing notification appearance

### Setup

```dart
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);

  await localNotifications.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      // Handle notification tap
      final payload = response.payload;
      if (payload != null) {
        router.push(payload);  // payload = route string
      }
    },
  );
}
```

### Showing Foreground Notifications

```dart
void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: message.data['route'],  // Pass route for tap handling
  );
}
```

### Scheduled Notifications

```dart
await localNotifications.zonedSchedule(
  id,
  'Reminder',
  'Don\'t forget to check your messages',
  tz.TZDateTime.now(tz.local).add(const Duration(hours: 1)),
  notificationDetails,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,  // Daily repeat
);
```

### Android Notification Channels

Create channels at app startup. Users can independently control each channel in system settings.

```dart
Future<void> createNotificationChannels() async {
  final android = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      'messages', 'Messages',
      description: 'New message notifications',
      importance: Importance.high,
    ),
  );

  await android?.createNotificationChannel(
    const AndroidNotificationChannel(
      'updates', 'App Updates',
      description: 'App update notifications',
      importance: Importance.defaultImportance,
    ),
  );
}
```

## Service Interface Pattern

Following the template's abstract interface pattern:

```dart
abstract class NotificationService {
  /// Initialize notification handling
  Future<void> initialize();

  /// Request notification permission
  Future<bool> requestPermission();

  /// Check current permission status
  Future<AuthorizationStatus> getPermissionStatus();

  /// Get current FCM token
  Future<String?> getToken();

  /// Stream of incoming foreground messages
  Stream<RemoteMessage> get onMessage;

  /// Stream of notification taps (background state)
  Stream<RemoteMessage> get onMessageOpenedApp;

  /// Get message that launched the app (terminated state)
  Future<RemoteMessage?> getInitialMessage();

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic);

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic);
}
```

## Server API Contract

Your API server needs these endpoints:

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/devices/token` | Register/update device token |
| DELETE | `/devices/token` | Remove device token (on logout) |
| POST | `/notifications/send` | Send notification (admin/internal) |
| GET | `/notifications/preferences` | Get user notification preferences |
| PUT | `/notifications/preferences` | Update notification preferences |

### FCM Server-Side Sending

Use the [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages):

```python
# Python example using firebase-admin
import firebase_admin
from firebase_admin import messaging

def send_notification(token, title, body, data=None):
    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data=data or {},
        token=token,
    )
    response = messaging.send(message)
    return response
```

See: [FCM server guide](https://firebase.google.com/docs/cloud-messaging/server)

## Testing

### Firebase Console

Quickest way to test: Firebase Console → Cloud Messaging → Send your first message. Target by FCM token for individual testing.

### Firebase CLI

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Send test notification
firebase messaging:send --project your-project-id \
  --token "device_fcm_token" \
  --title "Test" \
  --body "Hello from CLI"
```

### Platform-Specific Notes

**Android:**
- Notifications work on emulators with Google Play Services
- Test notification channels independently in system settings
- Test doze mode behavior: `adb shell dumpsys deviceidle force-idle`

**iOS:**
- Push notifications do NOT work on iOS Simulator — use a physical device
- Test provisional notifications separately from authorized
- Test background fetch restrictions

### App-Side Testing

Mock `NotificationService` in BLoC tests:

```dart
class MockNotificationService extends Mock implements NotificationService {}

blocTest<NotificationPermissionBloc, NotificationPermissionState>(
  'emits [granted] when permission request succeeds',
  build: () {
    when(() => service.requestPermission()).thenAnswer((_) async => true);
    return NotificationPermissionBloc(service: service);
  },
  act: (bloc) => bloc.add(const PermissionRequested()),
  expect: () => [const NotificationPermissionState.granted()],
);
```

## Edge Cases & Failure Modes

| Scenario | How to Handle |
|----------|---------------|
| **Token rotation** | Always listen to `onTokenRefresh`; sync new token to server immediately |
| **Multiple devices** | Server stores all tokens per user; sends to all; cleans stale tokens |
| **Permission denied** | Show value proposition, provide settings link; never spam requests |
| **Background restrictions** | iOS limits background execution (~30s); Android doze mode delays delivery |
| **Notification grouping** | Use Android channels and iOS `threadIdentifier` for grouping |
| **Payload size limits** | FCM: 4KB notification + 4KB data; APNs: 4KB total |
| **Silent push throttling** | iOS throttles silent pushes; not suitable for time-critical sync |
| **Stale tokens** | Handle `messaging/registration-token-not-registered` by removing token |
| **App uninstall** | Token becomes invalid; server discovers on next send attempt |

## Connectivity-Aware Considerations

Following the template's offline-first pattern:

- **Token sync**: Queue token registration if offline; sync when connectivity returns
- **Notification preferences**: Cache user preferences locally; sync changes when online
- **Missed notifications**: After coming back online, fetch latest data from server (don't rely solely on push for state)
- **Offline queue**: If user takes action from a notification while offline, queue the action

## Alternative Providers

While this guide focuses on FCM, other providers follow similar patterns:

| Provider | Package | Docs |
|----------|---------|------|
| OneSignal | [`onesignal_flutter`](https://pub.dev/packages/onesignal_flutter) | [Flutter SDK setup](https://documentation.onesignal.com/docs/flutter-sdk-setup) |
| AWS Pinpoint | [`amplify_push_notifications`](https://pub.dev/packages/amplify_push_notifications) | [Amplify Push](https://docs.amplify.aws/flutter/build-a-backend/push-notifications/) |
| Pusher Beams | [`pusher_beams`](https://pub.dev/packages/pusher_beams) | [Beams Flutter](https://pusher.com/docs/beams/getting-started/flutter/) |

The abstract `NotificationService` interface makes swapping providers straightforward.

## Reference Links

### Firebase Cloud Messaging
- [FlutterFire Messaging overview](https://firebase.flutter.dev/docs/messaging/overview)
- [FCM Flutter client setup](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- [FCM server guide](https://firebase.google.com/docs/cloud-messaging/server)
- [FCM message types](https://firebase.google.com/docs/cloud-messaging/concept-options)
- [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)

### Platform Setup
- [FlutterFire Android setup](https://firebase.flutter.dev/docs/messaging/android-setup)
- [FlutterFire iOS setup](https://firebase.flutter.dev/docs/messaging/apple-integration)
- [APNs documentation](https://developer.apple.com/documentation/usernotifications)

### Flutter Packages
- [`firebase_messaging`](https://pub.dev/packages/firebase_messaging)
- [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications)
- [`firebase_core`](https://pub.dev/packages/firebase_core)

### Permissions
- [`permission_handler`](https://pub.dev/packages/permission_handler)
- [iOS provisional authorization](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)

### Deep Linking
- [go_router deep linking](https://pub.dev/documentation/go_router/latest/topics/Deep%20linking-topic.html)

### Testing
- [Stripe CLI](https://docs.stripe.com/stripe-cli) — wrong link, use Firebase Console
- [Firebase Console → Cloud Messaging](https://console.firebase.google.com/) for manual testing
- [FCM test messages](https://firebase.google.com/docs/cloud-messaging/flutter/first-message)
