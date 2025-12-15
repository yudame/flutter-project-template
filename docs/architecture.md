# Flutter Architecture Template

**Pragmatic architecture for small teams with AI-assisted development**

This template provides a production-ready Flutter architecture designed for:
- 2-5 person teams
- Heavy AI code generation (Claude, Copilot, etc.)
- Mobile-first with offline support
- Clean code without over-engineering

---

## Table of Contents

1. [Philosophy](#philosophy)
2. [Tech Stack](#tech-stack)
3. [Project Structure](#project-structure)
4. [Core Patterns](#core-patterns)
5. [Dependency Injection](#dependency-injection)
6. [Network Layer](#network-layer)
7. [Connectivity Strategy](#connectivity-strategy)
8. [Offline Queue](#offline-queue)
9. [Database Layer](#database-layer)
10. [BLoC Patterns](#bloc-patterns)
11. [Testing Strategy](#testing-strategy)
12. [Code Generation](#code-generation)

---

## Philosophy

**Start with official Flutter tooling, add only what you need, establish clear conventions.**

### Core Principles

1. **Two-layer architecture** - Presentation + Data (no premature domain abstraction)
2. **Freezed everywhere** - Models, events, states use sealed unions (AI-friendly)
3. **Connectivity-first** - Explicit handling of online/poor/offline states
4. **BLoC pattern** - Official Flutter recommendation, clear separation
5. **Testing focus** - BLoCs always (90%+), repositories usually (70%+), widgets selectively
6. **Production ready** - Monitoring, secure storage, offline support from day one

### Anti-patterns to Avoid

- ❌ Premature domain layer abstraction
- ❌ Over-complicated repository interfaces
- ❌ Implicit connectivity assumptions
- ❌ Skipping dependency injection
- ❌ Testing only happy paths

---

## Tech Stack

### State Management
```yaml
flutter_bloc: ^8.1.6          # BLoC pattern
hydrated_bloc: ^9.1.5         # Persistent state
freezed_annotation: ^2.4.4    # Immutable models
```

### Navigation
```yaml
go_router: ^14.7.3            # Official Flutter recommendation
```

### Network & Connectivity
```yaml
dio: ^5.8.0                   # HTTP client
connectivity_plus: ^6.1.3     # Network monitoring
dio_cache_interceptor: ^3.5.0 # HTTP caching
dio_cache_interceptor_hive_store: ^3.2.2
```

### Local Storage
```yaml
hive: ^2.2.3                  # Local NoSQL (offline cache, queue)
hive_flutter: ^1.1.0
flutter_secure_storage: ^9.2.2  # Encrypted storage (requires minSdk 23)
shared_preferences: ^2.3.3    # Simple key-value
path_provider: ^2.1.5         # File paths
```

### Remote Database (choose one)
```yaml
# Option A: Firebase (recommended for most apps)
firebase_core: ^3.8.1
firebase_auth: ^5.3.4
cloud_firestore: ^5.6.0
firebase_storage: ^12.4.0

# Option B: Supabase (PostgreSQL-based alternative)
supabase_flutter: ^2.8.3
```

### Dependency Injection
```yaml
get_it: ^8.0.2                # Service locator
```

### Utilities
```yaml
logger: ^2.5.0                # Logging
uuid: ^4.5.1                  # Unique IDs
```

### Monitoring (Production)
```yaml
sentry_flutter: ^8.11.0       # Error tracking
```

### Dev Dependencies
```yaml
freezed: ^2.5.7
json_serializable: ^6.9.2
build_runner: ^2.4.14
hive_generator: ^2.0.1
bloc_test: ^9.1.7
mocktail: ^1.0.4
```

---

## Project Structure

```
lib/
├── core/
│   ├── theme/              # App theme configuration
│   ├── routes/             # go_router setup
│   ├── network/            # DioClient, offline queue
│   ├── connectivity/       # ConnectivityBloc & service
│   ├── di/                 # get_it configuration
│   └── utils/              # Logger, constants, extensions
├── features/
│   └── [feature_name]/
│       ├── data/
│       │   ├── models/     # Freezed models (serve as domain objects)
│       │   ├── repositories/  # Concrete implementations
│       │   └── datasources/   # API/local data sources
│       └── presentation/
│           ├── bloc/       # BLoCs with Freezed events/states
│           ├── pages/      # Screen widgets
│           └── widgets/    # Feature-specific widgets
├── shared/
│   ├── widgets/            # Reusable UI components
│   └── extensions/         # Extension methods
└── main.dart
```

### Why No Domain Layer?

For teams under 5 people:
- **Freezed models** already provide immutability and type safety
- **No business logic complexity** requiring separate entities
- **AI code generation** works better with simpler structure
- **Easy to add later** if complexity grows

---

## Core Patterns

### 1. Freezed Models (Data Layer)

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
    DateTime? lastLogin,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

**Benefits:**
- Immutable by default
- Equality/hashCode/toString for free
- copyWith() for updates
- JSON serialization built-in
- Pattern matching with sealed unions

### 2. Repository Pattern

```dart
class UserRepository {
  final ApiUserDataSource _api;
  final LocalUserDataSource _local;
  final ConnectivityService _connectivity;
  final OfflineQueue _queue;

  Future<Result<User>> getUser(String id) async {
    return _connectivity.currentState.when(
      online: () async {
        final user = await _api.getUser(id);
        await _local.saveUser(user);
        return Result.success(user);
      },
      poor: () async {
        try {
          return await _api.getUser(id).timeout(Duration(seconds: 5));
        } catch (e) {
          return _tryCache(id);
        }
      },
      offline: () => _tryCache(id),
    );
  }

  Future<Result<User>> _tryCache(String id) async {
    final cached = await _local.getUser(id);
    return cached != null
        ? Result.success(cached)
        : Result.failure('No cached data');
  }
}
```

### 3. Result Type Pattern

```dart
@freezed
class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(String message) = Failure<T>;
  const factory Result.loading() = Loading<T>;
}
```

---

## Dependency Injection

### Setup (core/di/injection.dart)

```dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core services
  getIt.registerLazySingleton(() => Logger());
  getIt.registerLazySingleton(() => Dio());

  // Network
  getIt.registerLazySingleton(() => DioClient(
    getIt<Dio>(),
    getIt<Logger>(),
    getIt<AuthTokenManager>(),
  ));

  // Connectivity
  getIt.registerFactory(() => ConnectivityBloc(
    getIt<Connectivity>(),
    getIt<Dio>(),
  ));

  getIt.registerLazySingleton<ConnectivityService>(
    () => ConnectivityServiceImpl(getIt<ConnectivityBloc>()),
  );

  // Repositories
  getIt.registerLazySingleton(() => UserRepository(
    getIt<ApiUserDataSource>(),
    getIt<LocalUserDataSource>(),
    getIt<ConnectivityService>(),
    getIt<OfflineQueue>(),
  ));

  // BLoCs (factories for multiple instances)
  getIt.registerFactory(() => UserBloc(
    getIt<UserRepository>(),
    getIt<ConnectivityBloc>(),
  ));
}
```

### Usage in Widgets

```dart
class UserPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<UserBloc>()..add(const UserEvent.load()),
      child: UserView(),
    );
  }
}
```

---

## Network Layer

### DioClient Configuration

```dart
class DioClient {
  final Dio _dio;
  final Logger _logger;
  final AuthTokenManager _authManager;

  DioClient(this._dio, this._logger, this._authManager) {
    _dio.options.baseUrl = 'https://api.example.com';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    _dio.interceptors.addAll([
      AuthInterceptor(_authManager, _dio),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          error: true,
          compact: false,
        ),
      DioCacheInterceptor(
        options: CacheOptions(
          store: HiveCacheStore(await getApplicationDocumentsDirectory()),
          policy: CachePolicy.request,
          hitCacheOnErrorExcept: [401, 403],
          maxStale: const Duration(days: 7),
        ),
      ),
    ]);
  }

  Dio get dio => _dio;
}
```

### Auth Interceptor

```dart
class AuthInterceptor extends Interceptor {
  final AuthTokenManager _tokenManager;
  final Dio _dio;
  bool _isRefreshing = false;

  AuthInterceptor(this._tokenManager, this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/auth/')) {
      return handler.next(options);
    }

    if (await _tokenManager.isTokenExpired()) {
      if (!_isRefreshing) {
        _isRefreshing = true;
        try {
          final newToken = await _tokenManager.refreshAccessToken();
          options.headers['Authorization'] = 'Bearer $newToken';
          _isRefreshing = false;
        } catch (e) {
          _isRefreshing = false;
          return handler.reject(DioException(
            requestOptions: options,
            error: 'Authentication expired',
          ));
        }
      }
    } else {
      final token = await _tokenManager.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final newToken = await _tokenManager.refreshAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        final response = await _dio.fetch(opts);
        _isRefreshing = false;
        return handler.resolve(response);
      } catch (e) {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}
```

---

## Connectivity Strategy

### Three States: Online, Poor, Offline

```dart
@freezed
class ConnectivityState with _$ConnectivityState {
  const factory ConnectivityState.online() = _Online;
  const factory ConnectivityState.poor() = _Poor;
  const factory ConnectivityState.offline() = _Offline;
}
```

### ConnectivityBloc

```dart
class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  final Dio _dio;
  Timer? _pingTimer;

  static const _poorLatencyThreshold = Duration(milliseconds: 2000);
  static const _failureThreshold = 3;

  int _consecutiveFailures = 0;
  Duration? _lastLatency;

  ConnectivityBloc(this._connectivity, this._dio)
      : super(const ConnectivityState.offline()) {

    on<ConnectivityEvent>((event, emit) async {
      await event.when(
        connected: () async => _onConnected(emit),
        disconnected: () async => emit(const ConnectivityState.offline()),
        stable: () async => emit(const ConnectivityState.online()),
        degraded: () async => emit(const ConnectivityState.poor()),
      );
    });

    _connectivity.onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        add(const ConnectivityEvent.disconnected());
      } else {
        add(const ConnectivityEvent.connected());
        _startLatencyMonitoring();
      }
    });
  }

  void _startLatencyMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _checkLatency();
    });
  }

  Future<void> _checkLatency() async {
    final stopwatch = Stopwatch()..start();
    try {
      await _dio.head('/health', options: Options(
        receiveTimeout: Duration(seconds: 5),
        sendTimeout: Duration(seconds: 5),
      ));
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

  @override
  Future<void> close() {
    _pingTimer?.cancel();
    return super.close();
  }
}
```

### ConnectivityService Interface

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
```

---

## Offline Queue

### Request Serialization (Command Pattern)

```dart
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

@HiveType(typeId: 1)
enum RequestType {
  @HiveField(0) createItem,
  @HiveField(1) updateItem,
  @HiveField(2) deleteItem,
  // Add your request types
}
```

### Request Executor

```dart
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
    await _dio.dio.post(
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

### OfflineQueue

```dart
class OfflineQueue {
  final HiveInterface _hive;
  final RequestExecutor _executor;
  final Logger _logger;

  static const _maxQueueSize = 100;
  static const _maxRetries = 3;

  Future<void> add(RequestType type, Map<String, dynamic> params) async {
    // Idempotency key
    final idempotencyKey = params['idempotency_key'] as String? ??
        '${type.name}_${params.hashCode}';
    params['idempotency_key'] = idempotencyKey;

    final box = await _hive.openBox<QueuedRequest>('offline_queue');

    // Check for duplicates
    final exists = box.values.any((r) =>
      r.type == type &&
      r.params['idempotency_key'] == idempotencyKey
    );

    if (exists) {
      _logger.i('Duplicate request ignored: $idempotencyKey');
      return;
    }

    // Check queue size
    if (box.length >= _maxQueueSize) {
      _logger.w('Queue full, cannot add request');
      throw QueueFullException();
    }

    final request = QueuedRequest(
      id: const Uuid().v4(),
      type: type,
      params: params,
      queuedAt: DateTime.now(),
    );

    await box.put(request.id, request);
    _logger.i('Queued ${type.name} request: ${request.id}');
  }

  Future<void> processQueue() async {
    final box = await _hive.openBox<QueuedRequest>('offline_queue');
    final requests = box.values.toList()
      ..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    for (final request in requests) {
      try {
        await _executeWithRetry(request);
        await box.delete(request.id);
        _logger.i('Processed ${request.type.name}: ${request.id}');
      } on AuthException {
        _logger.e('Auth failed, stopping queue');
        break;
      } catch (e) {
        await _handleFailedRequest(request, box, e);
      }
    }
  }

  Future<void> _executeWithRetry(QueuedRequest request) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        await _executor.execute(request);
        return;
      } catch (e) {
        if (attempt == _maxRetries) rethrow;

        // Exponential backoff with jitter
        final backoff = Duration(
          seconds: min(pow(2, attempt).toInt(), 30),
          milliseconds: Random().nextInt(1000),
        );
        await Future.delayed(backoff);
      }
    }
  }

  Future<void> _handleFailedRequest(
    QueuedRequest request,
    Box<QueuedRequest> box,
    dynamic error,
  ) async {
    if (request.retryCount >= _maxRetries) {
      await Sentry.captureException(error, hint: request.params);
      await box.delete(request.id);
    } else {
      final updated = QueuedRequest(
        id: request.id,
        type: request.type,
        params: request.params,
        queuedAt: request.queuedAt,
        retryCount: request.retryCount + 1,
      );
      await box.put(request.id, updated);
    }
  }
}
```

---

## Database Layer

### Core Principle: User-Owned Documents

Every app—whether it's photo processing, social media, or personal organization—reduces to a common pattern:

```
User → owns many → Documents (with optional media attachments)
```

The database layer is opinionated about this **pattern**, not the **provider**. Use Firebase, Supabase, or your own backend—the integration pattern stays the same.

### What the Database Layer Handles

| Concern | Solution |
|---------|----------|
| Authentication | Provider's auth (Firebase Auth, Supabase Auth) |
| User documents | CRUD on user-owned collections |
| Media storage | Provider's storage (Firebase Storage, Supabase Storage) |
| Offline sync | Local Hive cache + sync on connectivity change |
| Real-time (optional) | Provider's listeners when needed |

### Project Structure

```
lib/core/
├── database/
│   ├── database_service.dart       # Abstract interface
│   ├── firebase/                   # Firebase implementation
│   │   ├── firebase_database_service.dart
│   │   └── firebase_storage_service.dart
│   └── models/
│       └── sync_status.dart        # Sync state tracking
```

### Abstract Database Interface

```dart
/// Provider-agnostic database interface.
/// Repositories depend on this, not concrete implementations.
abstract class DatabaseService {
  /// Authentication
  Stream<String?> get authStateChanges;
  Future<String?> get currentUserId;
  Future<void> signOut();

  /// User documents - the core pattern
  Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  });

  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  });

  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  });

  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  });

  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    Map<String, dynamic>? whereEquals,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  /// Real-time listeners (optional - use when needed)
  Stream<List<Map<String, dynamic>>> watchCollection({
    required String collection,
    Map<String, dynamic>? whereEquals,
    String? orderBy,
    bool descending = false,
  });
}
```

### Firebase Implementation

```dart
class FirebaseDatabaseService implements DatabaseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirebaseDatabaseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<String?> get authStateChanges =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<String?> get currentUserId async => _auth.currentUser?.uid;

  @override
  Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final userId = await currentUserId;
    if (userId == null) throw AuthException('Not authenticated');

    final docRef = await _firestore.collection(collection).add({
      ...data,
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection(collection).doc(documentId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    await _firestore.collection(collection).doc(documentId).delete();
  }

  @override
  Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final doc = await _firestore.collection(collection).doc(documentId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  @override
  Future<List<Map<String, dynamic>>> queryDocuments({
    required String collection,
    Map<String, dynamic>? whereEquals,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) async {
    final userId = await currentUserId;
    if (userId == null) throw AuthException('Not authenticated');

    Query query = _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId);

    if (whereEquals != null) {
      for (final entry in whereEquals.entries) {
        query = query.where(entry.key, isEqualTo: entry.value);
      }
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCollection({
    required String collection,
    Map<String, dynamic>? whereEquals,
    String? orderBy,
    bool descending = false,
  }) {
    // Implementation similar to queryDocuments but returns stream
    // Use for real-time features like chat
  }
}
```

### Storage Service (Media/Files)

```dart
abstract class StorageService {
  /// Upload file and return download URL
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    String? contentType,
  });

  /// Delete file
  Future<void> deleteFile(String path);

  /// Get download URL for existing file
  Future<String> getDownloadUrl(String path);
}

class FirebaseStorageService implements StorageService {
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  FirebaseStorageService({
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List data,
    String? contentType,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw AuthException('Not authenticated');

    // Prefix with userId for security rules
    final fullPath = 'users/$userId/$path';
    final ref = _storage.ref(fullPath);

    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;

    await ref.putData(data, metadata);
    return await ref.getDownloadURL();
  }

  @override
  Future<void> deleteFile(String path) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw AuthException('Not authenticated');

    final fullPath = 'users/$userId/$path';
    await _storage.ref(fullPath).delete();
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw AuthException('Not authenticated');

    final fullPath = 'users/$userId/$path';
    return await _storage.ref(fullPath).getDownloadURL();
  }
}
```

### Repository Integration

Repositories combine local cache (Hive) with remote database:

```dart
class NotesRepository {
  final DatabaseService _db;
  final StorageService _storage;
  final HiveInterface _hive;
  final ConnectivityService _connectivity;

  static const _collection = 'notes';
  static const _cacheBox = 'notes_cache';

  Future<Result<Note>> createNote({
    required String title,
    required String content,
    Uint8List? imageData,
  }) async {
    // Generate local ID for optimistic update
    final localId = const Uuid().v4();
    String? imageUrl;

    // Upload image if provided
    if (imageData != null) {
      try {
        imageUrl = await _storage.uploadFile(
          path: 'notes/$localId/image.jpg',
          data: imageData,
          contentType: 'image/jpeg',
        );
      } catch (e) {
        return Result.failure('Failed to upload image');
      }
    }

    final noteData = {
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
    };

    return _connectivity.currentState.when(
      online: () async {
        try {
          final docId = await _db.createDocument(
            collection: _collection,
            data: noteData,
          );
          final note = Note(id: docId, title: title, content: content, imageUrl: imageUrl);
          await _cacheNote(note);
          return Result.success(note);
        } catch (e) {
          return Result.failure('Failed to create note');
        }
      },
      poor: () async {
        // Try with short timeout, fall back to queue
        try {
          final docId = await _db.createDocument(
            collection: _collection,
            data: noteData,
          ).timeout(const Duration(seconds: 5));
          final note = Note(id: docId, title: title, content: content, imageUrl: imageUrl);
          await _cacheNote(note);
          return Result.success(note);
        } catch (e) {
          return _queueCreate(localId, noteData);
        }
      },
      offline: () => _queueCreate(localId, noteData),
    );
  }

  Future<Result<List<Note>>> getNotes() async {
    return _connectivity.currentState.when(
      online: () async {
        try {
          final docs = await _db.queryDocuments(
            collection: _collection,
            orderBy: 'createdAt',
            descending: true,
          );
          final notes = docs.map((d) => Note.fromJson(d)).toList();
          await _cacheNotes(notes);
          return Result.success(notes);
        } catch (e) {
          return _getCachedNotes();
        }
      },
      poor: () async {
        try {
          final docs = await _db.queryDocuments(
            collection: _collection,
            orderBy: 'createdAt',
            descending: true,
          ).timeout(const Duration(seconds: 5));
          final notes = docs.map((d) => Note.fromJson(d)).toList();
          await _cacheNotes(notes);
          return Result.success(notes);
        } catch (e) {
          return _getCachedNotes();
        }
      },
      offline: () => _getCachedNotes(),
    );
  }

  Future<Result<List<Note>>> _getCachedNotes() async {
    final box = await _hive.openBox<Map>(_cacheBox);
    if (box.isEmpty) {
      return Result.failure('No cached notes available');
    }
    final notes = box.values
        .map((m) => Note.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return Result.success(notes);
  }
}
```

### Dependency Injection Setup

```dart
Future<void> configureDependencies() async {
  // Database services (singletons)
  getIt.registerLazySingleton<DatabaseService>(
    () => FirebaseDatabaseService(),
  );

  getIt.registerLazySingleton<StorageService>(
    () => FirebaseStorageService(),
  );

  // Repositories
  getIt.registerLazySingleton(() => NotesRepository(
    getIt<DatabaseService>(),
    getIt<StorageService>(),
    getIt<HiveInterface>(),
    getIt<ConnectivityService>(),
  ));
}
```

### Sync Status Tracking

```dart
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus.synced() = _Synced;
  const factory SyncStatus.pending() = _Pending;
  const factory SyncStatus.error(String message) = _Error;
}

/// Extend your models to track sync state
@freezed
class Note with _$Note {
  const factory Note({
    required String id,
    required String title,
    required String content,
    String? imageUrl,
    @Default(SyncStatus.synced()) SyncStatus syncStatus,
  }) = _Note;

  factory Note.fromJson(Map<String, dynamic> json) => _$NoteFromJson(json);
}
```

### Firebase Security Rules (Firestore)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own documents
    match /{collection}/{docId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == resource.data.userId;
      allow create: if request.auth != null
                    && request.auth.uid == request.resource.data.userId;
    }
  }
}
```

### Firebase Security Rules (Storage)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can only access their own files
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

### When to Use Real-Time Listeners

| Use Case | Real-Time? | Why |
|----------|-----------|-----|
| Personal notes/logs | ❌ No | Single user, pull-to-refresh sufficient |
| Photo uploads | ❌ No | Async processing, poll for status |
| Chat messages | ✅ Yes | Multi-user, instant updates expected |
| Shared documents | ✅ Yes | Collaboration requires live sync |
| Notifications | ✅ Yes | Time-sensitive |

### Testing Database Layer

```dart
class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  late NotesRepository repository;
  late MockDatabaseService db;
  late MockStorageService storage;
  late MockConnectivityService connectivity;

  setUp(() {
    db = MockDatabaseService();
    storage = MockStorageService();
    connectivity = MockConnectivityService();
    repository = NotesRepository(db, storage, mockHive, connectivity);
  });

  test('creates note in Firestore when online', () async {
    when(() => connectivity.currentState)
        .thenReturn(const ConnectivityState.online());
    when(() => db.createDocument(
      collection: any(named: 'collection'),
      data: any(named: 'data'),
    )).thenAnswer((_) async => 'doc123');

    final result = await repository.createNote(
      title: 'Test',
      content: 'Content',
    );

    expect(result, isA<Success<Note>>());
    verify(() => db.createDocument(
      collection: 'notes',
      data: any(named: 'data'),
    )).called(1);
  });

  test('returns cached notes when offline', () async {
    when(() => connectivity.currentState)
        .thenReturn(const ConnectivityState.offline());
    // Setup mock Hive box with cached data

    final result = await repository.getNotes();

    expect(result, isA<Success<List<Note>>>());
    verifyNever(() => db.queryDocuments(collection: any(named: 'collection')));
  });
}
```

---

## BLoC Patterns

### Events & States with Freezed

```dart
@freezed
class UserEvent with _$UserEvent {
  const factory UserEvent.load(String id) = _Load;
  const factory UserEvent.update(User user) = _Update;
  const factory UserEvent.delete(String id) = _Delete;
  const factory UserEvent.processQueue() = _ProcessQueue;
}

@freezed
class UserState with _$UserState {
  const factory UserState.initial() = _Initial;
  const factory UserState.loading() = _Loading;
  const factory UserState.loaded(User user) = _Loaded;
  const factory UserState.error(String message) = _Error;
}
```

### Connectivity-Aware BLoC Mixin

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
```

### Feature BLoC Example

```dart
class UserBloc extends Bloc<UserEvent, UserState>
    with ConnectivityAwareBlocMixin {

  final UserRepository _repository;
  @override
  final ConnectivityBloc connectivityBloc;

  UserBloc(this._repository, this.connectivityBloc)
      : super(const UserState.initial()) {
    initConnectivityListener();
    on<UserEvent>(_onEvent);
  }

  @override
  void onConnectivityChanged(ConnectivityState state) {
    state.whenOrNull(
      online: () => add(const UserEvent.processQueue()),
    );
  }

  Future<void> _onEvent(UserEvent event, Emitter<UserState> emit) async {
    await event.when(
      load: (id) => _onLoad(id, emit),
      update: (user) => _onUpdate(user, emit),
      delete: (id) => _onDelete(id, emit),
      processQueue: () => _onProcessQueue(emit),
    );
  }

  Future<void> _onLoad(String id, Emitter<UserState> emit) async {
    emit(const UserState.loading());

    final result = await _repository.getUser(id);

    result.when(
      success: (user) => emit(UserState.loaded(user)),
      failure: (msg) => emit(UserState.error(msg)),
      loading: () => {},
    );
  }
}
```

---

## Testing Strategy

### BLoC Testing (90%+ Coverage)

```dart
void main() {
  late UserBloc bloc;
  late MockUserRepository repository;
  late MockConnectivityBloc connectivityBloc;

  setUp(() {
    repository = MockUserRepository();
    connectivityBloc = MockConnectivityBloc();
    bloc = UserBloc(repository, connectivityBloc);
  });

  tearDown(() {
    bloc.close();
  });

  group('UserBloc', () {
    test('initial state is UserState.initial', () {
      expect(bloc.state, const UserState.initial());
    });

    blocTest<UserBloc, UserState>(
      'emits [loading, loaded] when load succeeds',
      build: () {
        when(() => repository.getUser(any()))
            .thenAnswer((_) async => Result.success(mockUser));
        return bloc;
      },
      act: (bloc) => bloc.add(const UserEvent.load('123')),
      expect: () => [
        const UserState.loading(),
        UserState.loaded(mockUser),
      ],
    );

    blocTest<UserBloc, UserState>(
      'emits [loading, error] when load fails',
      build: () {
        when(() => repository.getUser(any()))
            .thenAnswer((_) async => Result.failure('Network error'));
        return bloc;
      },
      act: (bloc) => bloc.add(const UserEvent.load('123')),
      expect: () => [
        const UserState.loading(),
        const UserState.error('Network error'),
      ],
    );

    blocTest<UserBloc, UserState>(
      'processes queue when connectivity changes to online',
      build: () {
        when(() => connectivityBloc.stream)
            .thenAnswer((_) => Stream.value(const ConnectivityState.online()));
        return bloc;
      },
      verify: (_) {
        // Verify queue processing was triggered
      },
    );
  });
}
```

### Repository Testing (70%+ Coverage)

```dart
void main() {
  late UserRepository repository;
  late MockApiDataSource api;
  late MockLocalDataSource local;
  late MockConnectivityService connectivity;

  setUp(() {
    api = MockApiDataSource();
    local = MockLocalDataSource();
    connectivity = MockConnectivityService();
    repository = UserRepository(api, local, connectivity, mockQueue);
  });

  group('UserRepository', () {
    test('fetches from API when online', () async {
      when(() => connectivity.currentState)
          .thenReturn(const ConnectivityState.online());
      when(() => api.getUser(any()))
          .thenAnswer((_) async => mockUser);
      when(() => local.saveUser(any()))
          .thenAnswer((_) async => {});

      final result = await repository.getUser('123');

      expect(result, isA<Success<User>>());
      verify(() => api.getUser('123')).called(1);
      verify(() => local.saveUser(mockUser)).called(1);
    });

    test('falls back to cache when offline', () async {
      when(() => connectivity.currentState)
          .thenReturn(const ConnectivityState.offline());
      when(() => local.getUser(any()))
          .thenAnswer((_) async => mockUser);

      final result = await repository.getUser('123');

      expect(result, isA<Success<User>>());
      verify(() => local.getUser('123')).called(1);
      verifyNever(() => api.getUser(any()));
    });
  });
}
```

---

## Code Generation

### Run Code Generation

```bash
# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode (auto-regenerate on file changes)
flutter pub run build_runner watch --delete-conflicting-outputs

# Clean generated files
flutter pub run build_runner clean
```

### What Gets Generated

- `*.freezed.dart` - Freezed classes (models, events, states)
- `*.g.dart` - JSON serialization
- `*.gr.dart` - Auto-generated routes (if using auto_route)
- `*.config.dart` - Injectable configurations (if using injectable)

---

## Common Conventions

### Naming
- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Variables/Functions:** `camelCase`
- **Constants:** `kConstantName` (k prefix)
- **Private:** `_leadingUnderscore`

### File Organization

**BLoC Files:**
```
feature/presentation/bloc/
├── feature_bloc.dart      # Main BLoC + part declarations
├── feature_event.dart     # Freezed events (part of bloc)
└── feature_state.dart     # Freezed states (part of bloc)
```

**Model Files:**
```
feature/data/models/
└── feature_model.dart     # Freezed model + json_serializable
```

---

## AI Prompt Templates

### Generate Feature
```
Generate a Flutter feature called [FeatureName] with:
- Freezed model for [DataType] with json_serializable
- Repository with connectivity awareness (online/poor/offline handling)
- BLoC with Freezed events/states (initial, loading, loaded, error)
- Simple page displaying the data using BlocBuilder
Use get_it for dependency injection
Follow two-layer architecture pattern
```

### Add Tests
```
Generate tests for [FeatureBloc]:
- Test initial state
- Test loading → loaded flow
- Test error handling
- Test connectivity state changes (offline → online)
Use mocktail for mocking
Target 90%+ coverage
```

---

## Production Checklist

- [ ] Configure Sentry error tracking
- [ ] Set up environment variables (dev/staging/prod)
- [ ] Configure app icons and splash screens
- [ ] Set up CI/CD (GitHub Actions/Codemagic)
- [ ] Add analytics (Firebase/Mixpanel)
- [ ] Configure deep linking
- [ ] Set up push notifications
- [ ] Add app version checking/force update
- [ ] Configure ProGuard rules (Android)
- [ ] Set up App Store/Play Store listings

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [BLoC Library](https://bloclibrary.dev/)
- [Freezed Documentation](https://pub.dev/packages/freezed)
- [go_router Documentation](https://pub.dev/packages/go_router)
- [Dio Documentation](https://pub.dev/packages/dio)

---

**This architecture scales from MVP to production with minimal refactoring.**
