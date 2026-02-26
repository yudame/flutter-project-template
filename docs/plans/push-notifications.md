# Push Notifications Plan

**Issue:** https://github.com/yudame/flutter-project-template/issues/5

## Goal

Add push notification architecture documentation to the template. Cover the two-party relationship between mobile app and push provider (FCM/APNs), platform-specific setup, notification handling across all app states, deep linking, and permission management. Reference official docs so future developers can check for SDK updates.

This is a **documentation-only deliverable** — architecture guide, patterns, and references. No committed application code beyond example snippets in the docs.

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

**Key principle:** The app registers for push, receives a device token, and sends it to your server. Your server sends push requests to FCM/APNs. The app handles incoming notifications across three states: foreground, background, and terminated.

## Ground Truth & Responsibility

| Concern | Owner | Notes |
|---------|-------|-------|
| Device token | FCM/APNs | Tokens can rotate; app must handle refresh |
| Token-to-user mapping | API Server | Server stores which tokens belong to which user |
| Notification content | API Server | Server decides what to send and when |
| Delivery | FCM/APNs | Platform handles routing, retry, throttling |
| Display (foreground) | Mobile App | App decides how to show in-app notifications |
| Display (background) | OS | System notification tray; app controls payload |
| Tap handling / deep links | Mobile App | App routes user to correct screen |
| Permission state | Mobile App | App requests and tracks permission status |

## Official Documentation References

### Firebase Cloud Messaging (FCM)
- **FlutterFire Messaging plugin**: https://firebase.flutter.dev/docs/messaging/overview
- **FCM setup guide**: https://firebase.google.com/docs/cloud-messaging/flutter/client
- **FCM server guide**: https://firebase.google.com/docs/cloud-messaging/server
- **FCM message types**: https://firebase.google.com/docs/cloud-messaging/concept-options
- **FCM HTTP v1 API**: https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages

### Platform Setup
- **Android setup**: https://firebase.flutter.dev/docs/messaging/android-setup
- **iOS setup (APNs)**: https://firebase.flutter.dev/docs/messaging/apple-integration
- **iOS APNs configuration**: https://developer.apple.com/documentation/usernotifications

### Flutter Packages
- **firebase_messaging**: https://pub.dev/packages/firebase_messaging
- **flutter_local_notifications**: https://pub.dev/packages/flutter_local_notifications
- **firebase_core**: https://pub.dev/packages/firebase_core

### Permissions
- **permission_handler**: https://pub.dev/packages/permission_handler
- **iOS provisional authorization**: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications

### Deep Linking
- **go_router deep linking**: https://pub.dev/documentation/go_router/latest/topics/Deep%20linking-topic.html
- **Firebase Dynamic Links** (deprecated, but reference): https://firebase.google.com/docs/dynamic-links

### Alternative Providers
- **OneSignal Flutter**: https://documentation.onesignal.com/docs/flutter-sdk-setup
- **AWS Pinpoint**: https://docs.amplify.aws/flutter/build-a-backend/push-notifications/
- **Pusher Beams**: https://pusher.com/docs/beams/getting-started/flutter/

## Notification Types to Document

### 1. Notification Messages
- Displayed automatically by OS when app is in background/terminated
- FCM handles display; app handles tap
- Limited customization

### 2. Data Messages
- Always delivered to app code (foreground and background)
- App controls display entirely
- Use `flutter_local_notifications` to show in notification tray
- More flexible but more work

### 3. Combined (Notification + Data)
- OS displays notification part in background
- Data payload available when user taps
- Most common pattern for deep linking

### 4. Silent Push
- Data-only with `content-available: true` (iOS) or priority settings (Android)
- Triggers background processing without user-visible notification
- Use for background data sync, cache invalidation

## App State Handling

| App State | Notification Message | Data Message |
|-----------|---------------------|--------------|
| **Foreground** | Delivered to `onMessage` stream; app must display manually | Delivered to `onMessage` stream |
| **Background** | OS shows notification; tap triggers `onMessageOpenedApp` | Delivered to `onBackgroundMessage` handler |
| **Terminated** | OS shows notification; tap triggers `getInitialMessage()` | Delivered to `onBackgroundMessage` handler |

## Deliverables

### 1. Documentation (`docs/push-notifications.md`)

Comprehensive push notification guide covering:

- Architecture overview (app → server → FCM → device)
- Platform setup checklists (Android + iOS)
  - Android: `google-services.json`, manifest, notification channels
  - iOS: APNs certificate/key, capabilities, entitlements, provisional auth
- Notification types (notification vs data vs combined vs silent)
- App state handling matrix (foreground/background/terminated)
- Permission management patterns
  - When to request (not on first launch — explain why)
  - Handling denied state gracefully
  - iOS provisional notifications
- Token lifecycle
  - Registration, refresh, server sync
  - Handling token rotation
  - Multi-device token management
- Deep linking from notifications
  - Payload structure conventions
  - Integration with go_router
  - Handling terminated-state navigation
- Local notifications
  - Scheduled notifications pattern
  - Android notification channels
  - Badge management
- BLoC patterns (example code, not committed)
  - NotificationPermissionBloc
  - Notification handling in existing BLoCs
- Testing strategy
  - FCM console for manual testing
  - Firebase CLI for scripted sends
  - Platform-specific testing notes
- Alternative providers section (OneSignal, AWS Pinpoint)
- Full reference links to official documentation

### 2. Claude Command (`.claude/commands/add-push-notifications.md`)

Step-by-step scaffolding guide:
- Firebase project setup checklist
- Install `firebase_messaging` + `flutter_local_notifications`
- Platform configuration steps (Android manifest, iOS capabilities)
- Create `lib/core/notifications/` with example files
- Register services in get_it
- Test notification sending via Firebase console
- Reference docs for server-side setup

### 3. Update Sphinx Docs
- Add push-notifications.md to sphinx source
- Update index.rst with Push Notifications under Core Systems
- Update build scripts to copy push-notifications.md

## Example Code Patterns (In Docs Only)

The documentation will include example snippets for:

- `NotificationService` abstract interface
- `FcmNotificationService` implementation with token management
- `NotificationHandler` for tap routing and deep links
- `NotificationPermissionBloc` for permission state
- Background message handler (top-level function requirement)
- go_router integration for notification deep links
- Server-side payload examples (FCM HTTP v1 format)

These are **reference examples** in markdown, not committed lib/ code.

## Key Patterns to Document

### Permission Request Timing

```
First launch → Skip notification permission
              → User completes onboarding
              → User encounters notification-worthy feature
              → Show contextual prompt explaining value
              → Request system permission
```

Never request on first launch. Users deny permissions they don't understand.

### Token Lifecycle

```
App Launch → Get FCM token
           → Compare with last stored token
           → If different → POST to server
           → Listen for token refresh events
           → On refresh → POST new token to server
           → On logout → DELETE token from server
```

### Deep Link Payload Convention

```json
{
  "notification": {
    "title": "New message",
    "body": "You have a new message from Alice"
  },
  "data": {
    "route": "/messages/123",
    "type": "message",
    "id": "123"
  }
}
```

App extracts `data.route` and pushes to go_router.

### Background Handler Constraint

The `onBackgroundMessage` handler **must be a top-level function** (not a method). This is a Firebase requirement because background isolates can't access instance state.

```dart
// This must be top-level, outside any class
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Handle background message...
}
```

## What We're NOT Building

- **No committed app code** — Documentation template only; example code lives in docs
- **No server implementation** — Document the server contract and link to FCM server guides
- **No Firebase project setup** — Document the steps; each project creates its own
- **No rich media notifications** — Basic text notifications only; link to docs for images/actions
- **No in-app messaging** — FCM In-App Messaging is a separate product

## Edge Cases to Document

1. **Token rotation** — Tokens can change at any time; always handle refresh
2. **Multiple devices** — User may have multiple tokens; server must track all
3. **Permission denied** — Show value proposition, link to settings; never spam requests
4. **Background restrictions** — iOS limits background execution time; Android doze mode affects delivery
5. **Notification grouping** — Android channels, iOS thread identifiers
6. **Payload size limits** — FCM: 4KB notification, 4KB data; APNs: 4KB total
7. **Silent push reliability** — iOS throttles silent pushes; not guaranteed delivery

## Implementation Order

1. Write `docs/push-notifications.md` with architecture, patterns, examples, and reference links
2. Create `.claude/commands/add-push-notifications.md`
3. Update Sphinx docs (index.rst, build scripts)
4. Commit and close issue

## Estimated Work

- Documentation: ~3 hours
- Claude command: ~30 min
- Sphinx integration: ~15 min
- **Total: ~4 hours**
