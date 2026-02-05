Create a connectivity-aware repository.

## Input Required

Ask for:
- **Repository name** (e.g., "User", "Order", "Product")
- **Associated model**
- **Feature location**
- **API endpoints** (optional - can use mock initially)

## Template

```dart
import 'package:get_it/get_it.dart';

import '../../../core/connectivity/connectivity_bloc.dart';
import '../../../core/connectivity/connectivity_state.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/offline_queue.dart';
import '../../../core/utils/result.dart';
import '../models/{model_snake}.dart';

class {Name}Repository {
  final DioClient _client;
  final OfflineQueue _offlineQueue;
  final ConnectivityBloc _connectivityBloc;

  // Local cache
  List<{Model}>? _cachedItems;

  {Name}Repository({
    DioClient? client,
    OfflineQueue? offlineQueue,
    ConnectivityBloc? connectivityBloc,
  })  : _client = client ?? GetIt.I<DioClient>(),
        _offlineQueue = offlineQueue ?? GetIt.I<OfflineQueue>(),
        _connectivityBloc = connectivityBloc ?? GetIt.I<ConnectivityBloc>();

  /// Get all items, with connectivity-aware caching
  Future<Result<List<{Model}>>> getItems() async {
    final connectivity = _connectivityBloc.state;

    // Offline: return cache only
    if (connectivity is ConnectivityOffline) {
      return _cachedItems != null
          ? Result.success(_cachedItems!)
          : const Result.failure('No cached data available');
    }

    try {
      // TODO: Replace with actual API call
      // final response = await _client.get('/{endpoint}');
      // final items = (response.data['data'] as List)
      //     .map((json) => {Model}.fromJson(json))
      //     .toList();
      // _cachedItems = items;
      // return Result.success(items);

      // Mock data for development
      return const Result.failure('Not implemented');
    } catch (e) {
      // Return cache on error if available
      if (_cachedItems != null) {
        return Result.success(_cachedItems!);
      }
      return Result.failure(e.toString());
    }
  }

  /// Get a single item by ID
  Future<Result<{Model}>> getItem(String id) async {
    final connectivity = _connectivityBloc.state;

    if (connectivity is ConnectivityOffline) {
      final cached = _cachedItems?.firstWhere(
        (item) => item.id == id,
        orElse: () => throw Exception('Not found'),
      );
      return cached != null
          ? Result.success(cached)
          : const Result.failure('Item not found in cache');
    }

    try {
      // TODO: Implement API call
      return const Result.failure('Not implemented');
    } catch (e) {
      return Result.failure(e.toString());
    }
  }

  /// Create a new item
  Future<Result<{Model}>> createItem({
    required String title,
    String? description,
  }) async {
    final connectivity = _connectivityBloc.state;

    if (connectivity is ConnectivityOffline) {
      // Queue for later
      await _offlineQueue.enqueue(
        type: RequestType.post,
        endpoint: '/{endpoint}',
        data: {'title': title, 'description': description},
      );
      return const Result.failure('Queued for sync');
    }

    try {
      // TODO: Implement API call
      return const Result.failure('Not implemented');
    } catch (e) {
      // Queue on failure
      await _offlineQueue.enqueue(
        type: RequestType.post,
        endpoint: '/{endpoint}',
        data: {'title': title, 'description': description},
      );
      return Result.failure(e.toString());
    }
  }

  /// Update an existing item
  Future<Result<{Model}>> updateItem({Model} item) async {
    final connectivity = _connectivityBloc.state;

    if (connectivity is ConnectivityOffline) {
      await _offlineQueue.enqueue(
        type: RequestType.put,
        endpoint: '/{endpoint}/${item.id}',
        data: item.toJson(),
      );
      return const Result.failure('Queued for sync');
    }

    try {
      // TODO: Implement API call
      return const Result.failure('Not implemented');
    } catch (e) {
      await _offlineQueue.enqueue(
        type: RequestType.put,
        endpoint: '/{endpoint}/${item.id}',
        data: item.toJson(),
      );
      return Result.failure(e.toString());
    }
  }

  /// Delete an item
  Future<Result<void>> deleteItem(String id) async {
    final connectivity = _connectivityBloc.state;

    if (connectivity is ConnectivityOffline) {
      await _offlineQueue.enqueue(
        type: RequestType.delete,
        endpoint: '/{endpoint}/$id',
      );
      return const Result.failure('Queued for sync');
    }

    try {
      // TODO: Implement API call
      _cachedItems?.removeWhere((item) => item.id == id);
      return const Result.success(null);
    } catch (e) {
      await _offlineQueue.enqueue(
        type: RequestType.delete,
        endpoint: '/{endpoint}/$id',
      );
      return Result.failure(e.toString());
    }
  }

  /// Process queued offline requests
  Future<void> processOfflineQueue() async {
    await _offlineQueue.processQueue();
  }
}
```

## Location

`lib/features/{feature}/data/repositories/{name}_repository.dart`

## After Generation

1. Register in DI (`lib/core/di/injection.dart`):
   ```dart
   getIt.registerLazySingleton<{Name}Repository>(
     () => {Name}Repository(),
   );
   ```

2. Inject into BLoC:
   ```dart
   {Name}Bloc({
     required {Name}Repository repository,
     required this.connectivityBloc,
   }) : _repository = repository,
   ```

3. Create tests in `test/features/{feature}/data/repositories/{name}_repository_test.dart`

4. Replace TODO comments with actual API calls when backend is ready
