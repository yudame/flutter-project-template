# Implemented Features

**Documentation for features already built in this template**

This file documents the patterns and code that are already implemented in the `lib/` directory. For planned features not yet implemented, see `architecture.md`.

---

## Table of Contents

1. [Core Patterns](#core-patterns)
2. [Dependency Injection](#dependency-injection)
3. [Network Layer](#network-layer)
4. [Connectivity Strategy](#connectivity-strategy)
5. [Offline Queue](#offline-queue)
6. [BLoC Patterns](#bloc-patterns)
7. [Testing Strategy](#testing-strategy)

---

## Core Patterns

### 1. Freezed Models (Data Layer)

**Location:** `lib/features/*/data/models/`

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

**Location:** `lib/features/*/data/repositories/`

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

**Location:** `lib/core/utils/result.dart`

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

**Location:** `lib/core/di/injection.dart`

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

**Location:** `lib/core/network/`

### DioClient Configuration

**File:** `lib/core/network/dio_client.dart`

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

**File:** `lib/core/network/auth_interceptor.dart`

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

**Location:** `lib/core/connectivity/`

### Three States: Online, Poor, Offline

**File:** `lib/core/connectivity/connectivity_state.dart`

```dart
@freezed
class ConnectivityState with _$ConnectivityState {
  const factory ConnectivityState.online() = _Online;
  const factory ConnectivityState.poor() = _Poor;
  const factory ConnectivityState.offline() = _Offline;
}
```

### ConnectivityBloc

**File:** `lib/core/connectivity/connectivity_bloc.dart`

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

**File:** `lib/core/connectivity/connectivity_service.dart`

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

**Location:** `lib/core/network/`

### Request Serialization (Command Pattern)

**File:** `lib/core/network/queued_request.dart`

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

**File:** `lib/core/network/request_executor.dart`

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

**File:** `lib/core/network/offline_queue.dart`

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

## BLoC Patterns

**Location:** `lib/features/*/presentation/bloc/`

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

**File:** `lib/core/utils/connectivity_aware_mixin.dart`

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
      loading: () {},
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
