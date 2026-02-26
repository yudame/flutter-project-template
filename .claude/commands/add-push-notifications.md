# Add Push Notifications

Set up Firebase Cloud Messaging (FCM) push notifications in this Flutter project.

**Before starting:** Read `docs/push-notifications.md` for the full architecture guide, app state handling, and deep linking patterns.

## Steps

1. **Install packages**
   ```bash
   flutter pub add firebase_core firebase_messaging flutter_local_notifications
   ```
   Check for latest versions:
   - https://pub.dev/packages/firebase_messaging
   - https://pub.dev/packages/flutter_local_notifications

2. **Firebase project setup**

   If not already done:
   - Create project at https://console.firebase.google.com/
   - Add Android app → download `google-services.json` → place in `android/app/`
   - Add iOS app → download `GoogleService-Info.plist` → add to Xcode Runner target
   - Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
   - Run: `flutterfire configure`

3. **Android configuration**

   `android/build.gradle`:
   ```groovy
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.4.0'
       }
   }
   ```

   `android/app/build.gradle`:
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   ```

4. **iOS configuration**

   In Xcode:
   - Runner → Signing & Capabilities → + Push Notifications
   - Runner → Signing & Capabilities → + Background Modes → check "Remote notifications"
   - Upload APNs key (.p8) in Firebase Console → Project Settings → Cloud Messaging

5. **Create notification files**

   Create `lib/core/notifications/` directory with:

   - `notification_service.dart` — Abstract interface (see docs/push-notifications.md)
   - `fcm_notification_service.dart` — FCM implementation with token management
   - `notification_handler.dart` — Handle taps, deep links, foreground display
   - `notification_permission_bloc.dart` — Freezed events/states for permission

   Follow the example code in `docs/push-notifications.md` for each file.

6. **Add background handler**

   In `main.dart`, add a **top-level function** (Firebase requirement):
   ```dart
   @pragma('vm:entry-point')
   Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
     await Firebase.initializeApp();
   }

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
     runApp(MyApp());
   }
   ```

7. **Register in dependency injection**

   In `lib/core/di/injection.dart`:
   ```dart
   getIt.registerLazySingleton<NotificationService>(() => FcmNotificationService());
   ```

8. **Create notification channels** (Android)

   At app startup:
   ```dart
   await localNotifications
       .resolvePlatformSpecificImplementation<
           AndroidFlutterLocalNotificationsPlugin>()
       ?.createNotificationChannel(channel);
   ```

9. **Test**

   - Firebase Console → Cloud Messaging → Send test message
   - Target by FCM token (print it at startup for testing)
   - Test all three app states: foreground, background, terminated
   - **iOS requires a physical device** — push does not work on Simulator

## Important Notes

- **Permission timing**: Don't request on first launch. Wait for a contextual moment.
- **Token refresh**: Always listen to `onTokenRefresh` and sync to server.
- **Background handler**: Must be a top-level function, not a class method.
- **iOS Simulator**: Push notifications do NOT work. Use a physical device.
- **Payload limits**: FCM 4KB notification + 4KB data; APNs 4KB total.

## Reference

- Full architecture guide: `docs/push-notifications.md`
- firebase_messaging: https://pub.dev/packages/firebase_messaging
- FlutterFire Messaging: https://firebase.flutter.dev/docs/messaging/overview
- FCM server guide: https://firebase.google.com/docs/cloud-messaging/server
