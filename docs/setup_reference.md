# Flutter Project Setup & Implementation Reference

**Complete setup guide and critical implementation patterns**

This template provides everything you need to:
1. Set up a Flutter development environment from scratch (5-30 minutes)
2. Understand critical implementation patterns for production apps
3. Avoid common pitfalls with offline/connectivity handling

---

# Part 1: Quick Setup & Environment

## Quick Project Creation (5 Minutes)

```bash
# 1. Ensure Flutter is installed
flutter --version  # Should show 3.24.0 or later

# 2. Create project
cd ~/projects
flutter create --org com.yourcompany yourapp
cd yourapp

# 3. Create architecture docs directory
mkdir plans

# 4. Initialize git
git init
git add .
git commit -m "Initial Flutter project"

# 5. Verify setup
flutter doctor     # Should show no issues
flutter devices    # Should show available devices
```

**That's it!** You now have a working Flutter project.

---

## Prerequisites (One-Time macOS Setup)

### Required Tools
- **Homebrew:** Package manager for macOS
- **Flutter SDK:** Latest stable
- **Xcode:** Latest (for iOS development)
- **Android Studio:** Latest (for Android development)

### Install Everything

```bash
# 1. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install Flutter
brew install --cask flutter

# 3. Verify Flutter installation
flutter --version
flutter doctor

# 4. Install Android Studio
brew install --cask android-studio

# Then:
# - Open Android Studio
# - Complete setup wizard
# - Install Android SDK when prompted
# - Accept licenses: flutter doctor --android-licenses

# 5. Xcode Setup
# - Install from Mac App Store
# - Open Xcode once to accept license
# - Install command line tools: xcode-select --install
# - Open Xcode → Settings → Components → Install iOS Simulator

# 6. Install CocoaPods (iOS dependency manager)
sudo gem install cocoapods

# 7. Final verification
flutter doctor -v  # Should show all checkmarks
```

---

## Run the App

```bash
# List available devices
flutter devices

# Run on iOS Simulator
flutter run -d ios

# Run on Android emulator
flutter run -d android

# Run on macOS desktop
flutter run -d macos

# Run on Chrome
flutter run -d chrome

# Run tests
flutter test
```

---

## Common Commands

```bash
# Clean build artifacts
flutter clean

# Get dependencies
flutter pub get

# Run code generation (when using freezed, json_serializable)
flutter pub run build_runner build --delete-conflicting-outputs

# Update dependencies
flutter pub upgrade

# Analyze code
flutter analyze

# Format code
flutter format .

# Build for release
flutter build ios
flutter build apk
flutter build appbundle
```

---

## Troubleshooting

### Flutter doctor warnings

```bash
# Check detailed output
flutter doctor -v

# Common fixes:
# - Android licenses: flutter doctor --android-licenses
# - Xcode license: sudo xcodebuild -license accept
# - CocoaPods: sudo gem install cocoapods
```

### Android minSdkVersion

For `flutter_secure_storage` support, update `android/app/build.gradle.kts`:

```kotlin
android {
    defaultConfig {
        minSdk = 23  // Required for flutter_secure_storage 9.x
    }
}
```

### Xcode issues

```bash
# Install command line tools
xcode-select --install

# Reset Xcode path
sudo xcode-select --reset
```

### CocoaPods issues

```bash
# Update CocoaPods
sudo gem install cocoapods

# Clear cache
pod cache clean --all

# In ios/ directory:
pod repo update
pod install
```

---

## First Build Notes

**Android:**
- First build: 3-5 minutes (downloads SDK components)
- Subsequent builds: 10-30 seconds
- Hot reload: < 1 second

**iOS:**
- First build: 2-4 minutes
- Subsequent builds: 5-15 seconds
- Hot reload: < 1 second

---

# Part 2: Critical Implementation Details

Design decisions for non-trivial aspects that need explicit solutions before implementation.

---

## 1. Offline Queue Request Serialization

### Problem
`QueuedRequest` needs to be serializable for Hive persistence, but also executable. How do we reconstruct executable requests from serialized data?

### Solution: Command Pattern with Type Registry

```dart
// Base request class (Hive TypeAdapter)
@HiveType(typeId: 0)
class QueuedRequest {
  @HiveField(0) final String id;
  @HiveField(1) final RequestType type;
  @HiveField(2) final Map<String, dynamic> params;
  @HiveField(3) final DateTime queuedAt;
  @HiveField(4) final int retryCount;

  const QueuedRequest({
    required this.id,
    required this.type,
    required this.params,
    required this.queuedAt,
    this.retryCount = 0,
  });
}

// Request type enum (Hive TypeAdapter)
@HiveType(typeId: 1)
enum RequestType {
  @HiveField(0) createItem,
  @HiveField(1) updateItem,
  @HiveField(2) deleteItem,
  // Add your domain-specific types
}

// Request executor registry
class RequestExecutor {
  final DioClient _dio;
  final AuthTokenManager _authManager;

  Future<void> execute(QueuedRequest request) async {
    switch (request.type) {
      case RequestType.createItem:
        return _executeCreate(request.params);
      case RequestType.updateItem:
        return _executeUpdate(request.params);
      case RequestType.deleteItem:
        return _executeDelete(request.params);
    }
  }

  Future<void> _executeCreate(Map<String, dynamic> params) async {
    final token = await _getValidAuthToken();
    await _dio.post(
      '/items',
      data: params,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<String> _getValidAuthToken() async {
    if (await _authManager.isTokenExpired()) {
      return await _authManager.refreshAccessToken();
    }
    return await _authManager.getAccessToken() ?? '';
  }
}
```

### Hive Registration
```dart
// In main.dart
await Hive.initFlutter();
Hive.registerAdapter(QueuedRequestAdapter());
Hive.registerAdapter(RequestTypeAdapter());
```

---

## 2. Storage Strategy: Hive vs Simple JSON

### Decision: Use Hive

**Rationale:**
- Already needed for HTTP cache (`dio_cache_interceptor_hive_store`)
- Better performance for concurrent access
- Built-in indexing if needed
- Atomic operations (important for queue consistency)

**Marginal Cost:**
```dart
// Only these additional adapters needed
Hive.registerAdapter(QueuedRequestAdapter());
Hive.registerAdapter(RequestTypeAdapter());
```

**Alternative Considered:**
```dart
// JSON file approach (simpler but less robust)
class SimpleOfflineQueue {
  final File _file;

  Future<void> add(QueuedRequest request) async {
    final requests = await _read();
    requests.add(request.toJson());
    await _file.writeAsString(jsonEncode(requests));
  }

  // Problems:
  // - Race conditions on concurrent writes
  // - Full file rewrite on each operation
  // - No transaction support
  // - Manual locking needed
}
```

---

## 3. ConnectivityState.poor() Definition

### Problem
What triggers "poor" connectivity and how should the app behave differently?

### Definition: Multi-Factor Detection

```dart
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  final Dio _dio;
  Timer? _pingTimer;

  // Configuration
  static const _poorLatencyThreshold = Duration(milliseconds: 2000);
  static const _failureThreshold = 3;

  int _consecutiveFailures = 0;
  Duration? _lastLatency;

  void _startLatencyMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkLatency();
    });
  }

  Future<void> _checkLatency() async {
    final stopwatch = Stopwatch()..start();

    try {
      await _dio.head(
        '/health',  // Lightweight endpoint
        options: Options(
          receiveTimeout: Duration(seconds: 5),
          sendTimeout: Duration(seconds: 5),
        ),
      );

      stopwatch.stop();
      _lastLatency = stopwatch.elapsed;
      _consecutiveFailures = 0;

      if (_lastLatency! > _poorLatencyThreshold) {
        add(const ConnectivityEvent.degraded());
      } else {
        add(const ConnectivityEvent.stable());
      }
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _failureThreshold) {
        add(const ConnectivityEvent.degraded());
      }
    }
  }
}
```

### Triggers for "Poor" State
1. **High Latency:** Ping > 2000ms (configurable)
2. **Consecutive Failures:** 3+ failed health checks

### Behavior Differences

| State | Repository Behavior | UI Behavior |
|-------|-------------------|-------------|
| **Online** | Full API access, normal timeouts | No warnings |
| **Poor** | Shorter timeouts (5s), immediate cache fallback | Warning banner |
| **Offline** | Cache only, queue writes | Error banner |

```dart
// Repository with poor handling
Future<Result<Data>> fetchData(String id) async {
  return _connectivity.state.when(
    online: () async {
      try {
        return await _api.fetchData(id).timeout(Duration(seconds: 30));
      } catch (e) {
        return _tryCache(id);
      }
    },
    poor: () async {
      try {
        return await _api.fetchData(id).timeout(Duration(seconds: 5));
      } catch (e) {
        return _tryCache(id);
      }
    },
    offline: () => _tryCache(id),
  );
}
```

---

## 4. Auth Token Refresh Flow

### Problem
Apps with authentication need to handle:
- Token expires before request
- Token expires during request
- Refresh token also expired

### Solution: Dio Interceptor + Secure Storage

```dart
class AuthTokenManager {
  final FlutterSecureStorage _storage;
  final Dio _dio;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiryKey = 'token_expiry';

  Future<bool> isTokenExpired() async {
    final expiry = await getExpiry();
    if (expiry == null) return true;

    // Add 60s buffer before actual expiry
    return DateTime.now().isAfter(expiry.subtract(Duration(seconds: 60)));
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _expiryKey, value: expiry.toIso8601String());
  }

  Future<String> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      throw AuthException('No refresh token available');
    }

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final newAccessToken = response.data['access_token'] as String;
      final newRefreshToken = response.data['refresh_token'] as String;
      final expiresIn = response.data['expires_in'] as int;

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
        expiry: DateTime.now().add(Duration(seconds: expiresIn)),
      );

      return newAccessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.deleteAll();
        throw AuthException('Refresh token expired');
      }
      rethrow;
    }
  }
}
```

### Token Expiry Scenarios

| Scenario | Handling |
|----------|----------|
| **Token expires before request** | AuthInterceptor refreshes proactively |
| **Token expires during request** | onError catches 401, retries with refresh |
| **Refresh token expired** | Clear storage, emit AuthExpiredEvent |
| **No network for refresh** | Keep request in queue, retry when online |

---

## 5. BLoC Connectivity Subscription Mixin

### Problem
Feature BLoCs subscribing to ConnectivityBloc must cancel subscriptions in `close()`. Easy to forget.

### Solution: Connectivity-Aware BLoC Mixin

```dart
mixin ConnectivityAwareBlocMixin<Event, State> on Bloc<Event, State> {
  ConnectivityBloc get connectivityBloc;
  StreamSubscription<ConnectivityState>? _connectivitySubscription;

  void onConnectivityChanged(ConnectivityState state) {}

  void initConnectivityListener() {
    _connectivitySubscription = connectivityBloc.stream.listen(
      onConnectivityChanged,
    );
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}

// Usage
class FeatureBloc extends Bloc<FeatureEvent, FeatureState>
    with ConnectivityAwareBlocMixin {

  final FeatureRepository _repository;
  @override
  final ConnectivityBloc connectivityBloc;

  FeatureBloc(this._repository, this.connectivityBloc)
      : super(const FeatureState.initial()) {
    initConnectivityListener();
    on<FeatureEvent>(_onEvent);
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    state.whenOrNull(
      online: () => add(const FeatureEvent.processQueue()),
    );
  }
}
```

---

## 6. Retry and Backoff Strategy

### Problem
Without exponential backoff, the app could hammer the server during poor connectivity.

### Solution: Exponential Backoff with Jitter

```dart
class RequestExecutor {
  static const _maxRetries = 3;
  static const _maxBackoffSeconds = 30;

  Future<void> executeWithRetry(QueuedRequest request) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await execute(request);
        return;
      } catch (e) {
        if (attempt == _maxRetries) rethrow;

        final backoff = _getBackoffDelay(attempt);
        await Future.delayed(backoff);
      }
    }
  }

  Duration _getBackoffDelay(int retryCount) {
    // Exponential: 1s, 2s, 4s, 8s, max 30s
    final seconds = min(pow(2, retryCount).toInt(), _maxBackoffSeconds);

    // Add jitter to avoid thundering herd
    final jitter = Random().nextInt(1000);

    return Duration(seconds: seconds, milliseconds: jitter);
  }
}
```

---

## 7. Request Deduplication

### Problem
If connectivity drops while a user retries an action, duplicate requests could accumulate.

### Solution: Idempotency Keys

```dart
class OfflineQueue {
  Future<void> add(RequestType type, Map<String, dynamic> params) async {
    // Generate or extract idempotency key
    final idempotencyKey = params['idempotency_key'] as String? ??
        '${type.name}_${params.hashCode}';

    params['idempotency_key'] = idempotencyKey;

    final box = await _hive.openBox<QueuedRequest>('offline_queue');

    // Check for existing request with same idempotency key
    final existing = box.values.any((r) =>
      r.type == type &&
      r.params['idempotency_key'] == idempotencyKey
    );

    if (existing) {
      _logger.i('Duplicate request ignored: $idempotencyKey');
      return;
    }

    final request = QueuedRequest(
      id: const Uuid().v4(),
      type: type,
      params: params,
      queuedAt: DateTime.now(),
    );

    await box.put(request.id, request);
  }
}
```

---

## 8. ConnectivityService Interface

### Problem
Repositories depending on ConnectivityBloc directly makes testing harder.

### Solution: Explicit Interface

```dart
abstract class ConnectivityService {
  Stream<ConnectivityState> get stream;
  ConnectivityState get currentState;
  bool get isOnline;
  bool get isPoor;
  bool get isOffline;
}

class ConnectivityServiceImpl implements ConnectivityService {
  final ConnectivityBloc _bloc;

  ConnectivityServiceImpl(this._bloc);

  @override
  Stream<ConnectivityState> get stream => _bloc.stream;

  @override
  ConnectivityState get currentState => _bloc.state;

  @override
  bool get isOnline => currentState.maybeWhen(
    online: () => true,
    orElse: () => false,
  );

  @override
  bool get isPoor => currentState.maybeWhen(
    poor: () => true,
    orElse: () => false,
  );

  @override
  bool get isOffline => currentState.maybeWhen(
    offline: () => true,
    orElse: () => false,
  );
}

// Mock for testing
class MockConnectivityService extends Mock implements ConnectivityService {}
```

---

## Summary of Critical Decisions

| Issue | Decision | Rationale |
|-------|----------|-----------|
| **Queue Serialization** | Command pattern with RequestType enum | Type-safe, serializable, extensible |
| **Storage Strategy** | Stick with Hive | Already using for cache, robust concurrency |
| **Poor Connectivity** | Latency + failure threshold | Measurable, configurable, actionable |
| **Auth Refresh** | Dio interceptor + token manager | Automatic, handles all edge cases |
| **BLoC Cleanup** | Mixin enforces subscription cleanup | Can't forget, optional when needed |
| **Retry Strategy** | Exponential backoff with jitter | Prevents thundering herd |
| **Deduplication** | Idempotency keys | Prevents duplicate queue entries |
| **Testability** | ConnectivityService interface | Easy to mock, better separation |

---

## Implementation Order

1. **Auth Token Manager** - Foundation for all API calls
2. **Connectivity Detection** - Define poor state clearly
3. **Offline Queue** - With proper serialization
4. **BLoC Mixin** - Enforce patterns early
5. **Integration Testing** - Validate all edge cases

---

## Common Pitfalls to Avoid

❌ **Don't:** Create new `Dio()` instances in interceptors
✅ **Do:** Reuse injected Dio instance

❌ **Don't:** Forget to cancel StreamSubscriptions in BLoC.close()
✅ **Do:** Use ConnectivityAwareBlocMixin

❌ **Don't:** Assume network is always available
✅ **Do:** Explicitly handle online/poor/offline states

❌ **Don't:** Retry failed requests immediately
✅ **Do:** Use exponential backoff with jitter

❌ **Don't:** Allow unlimited queue growth
✅ **Do:** Set max queue size and drop old/low-priority items

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [BLoC Library](https://bloclibrary.dev/)
- [Freezed](https://pub.dev/packages/freezed)
- [Dio](https://pub.dev/packages/dio)
- [Hive](https://pub.dev/packages/hive)

---

**These patterns handle 95% of production mobile app requirements.**
