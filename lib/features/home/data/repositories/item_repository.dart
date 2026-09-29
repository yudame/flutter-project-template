import 'package:logger/logger.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/database/local_cache_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/offline_queue.dart';
import '../../../../core/network/queued_request.dart';
import '../../../../core/utils/result.dart';
import '../models/item.dart';

class ItemRepository {
  final DioClient _dioClient;
  final ConnectivityService _connectivity;
  final OfflineQueue _offlineQueue;
  final LocalCacheService _localCache;
  final Logger _logger;

  static const _collection = 'items';

  ItemRepository({
    required DioClient dioClient,
    required ConnectivityService connectivity,
    required OfflineQueue offlineQueue,
    required LocalCacheService localCache,
    required Logger logger,
  })  : _dioClient = dioClient,
        _connectivity = connectivity,
        _offlineQueue = offlineQueue,
        _localCache = localCache,
        _logger = logger;

  Future<Result<List<Item>>> getItems() async {
    final state = _connectivity.currentState;

    if (state is ConnectivityOnline) {
      return _fetchFromApi();
    } else if (state is ConnectivityPoor) {
      return _fetchWithFallback();
    } else {
      return _fetchFromCache();
    }
  }

  Future<Result<List<Item>>> _fetchFromApi() async {
    try {
      final response = await _dioClient.get<List<dynamic>>('/items');
      final items = (response.data ?? [])
          .map((json) => Item.fromJson(json as Map<String, dynamic>))
          .toList();

      // Persist to local cache
      await _localCache.putAll(
        _collection,
        {for (final item in items) item.id: item.toJson()},
      );

      _logger.i('Fetched and cached ${items.length} items from API');
      return Result.success(items);
    } catch (e) {
      _logger.e('Failed to fetch items from API: $e, checking cache');
      final cached = await _fetchFromCache();
      if (cached.isSuccess) {
        return cached;
      }
      return Result.failure('Failed to fetch items', e);
    }
  }

  Future<Result<List<Item>>> _fetchWithFallback() async {
    try {
      final response = await _dioClient
          .get<List<dynamic>>('/items')
          .timeout(const Duration(seconds: 5));
      final items = (response.data ?? [])
          .map((json) => Item.fromJson(json as Map<String, dynamic>))
          .toList();

      await _localCache.putAll(
        _collection,
        {for (final item in items) item.id: item.toJson()},
      );

      return Result.success(items);
    } catch (e) {
      _logger.w('API fetch timed out, falling back to cache');
      return _fetchFromCache();
    }
  }

  Future<Result<List<Item>>> _fetchFromCache() async {
    final result = await _localCache.getAll(_collection);
    return switch (result) {
      Success(:final data) when data.isNotEmpty => Result.success(
          data.map((json) => Item.fromJson(json)).toList(),
        ),
      Success() => const Result.failure('No cached data available'),
      Failure(:final message, :final error) => Result.failure(message, error),
      Loading() => const Result.loading(),
    };
  }

  Future<Result<Item>> getItem(String id) async {
    final state = _connectivity.currentState;

    if (state is ConnectivityOffline) {
      return _getCachedItem(id);
    }

    try {
      final response = await _dioClient.get<Map<String, dynamic>>('/items/$id');
      final item = Item.fromJson(response.data!);
      await _localCache.put(_collection, item.id, item.toJson());
      return Result.success(item);
    } catch (e) {
      // Try cache on failure
      final cached = await _getCachedItem(id);
      if (cached.isSuccess) {
        return cached;
      }
      return Result.failure('Failed to fetch item', e);
    }
  }

  Future<Result<Item>> _getCachedItem(String id) async {
    final result = await _localCache.get(_collection, id);
    return switch (result) {
      Success(:final data) when data != null =>
        Result.success(Item.fromJson(data)),
      Success() => const Result.failure('Item not found in cache'),
      Failure(:final message, :final error) => Result.failure(message, error),
      Loading() => const Result.loading(),
    };
  }

  Future<Result<Item>> createItem({
    required String title,
    String? description,
  }) async {
    final params = {
      'title': title,
      'description': description,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (_connectivity.isOffline) {
      await _offlineQueue.add(RequestType.createItem, params);
      // Create optimistic local item and persist to cache
      final optimisticItem = Item(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );
      await _localCache.put(
        _collection,
        optimisticItem.id,
        optimisticItem.toJson(),
      );
      return Result.success(optimisticItem);
    }

    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        '/items',
        data: params,
      );
      final item = Item.fromJson(response.data!);
      await _localCache.put(_collection, item.id, item.toJson());
      return Result.success(item);
    } catch (e) {
      // Queue for later if failed
      await _offlineQueue.add(RequestType.createItem, params);
      final optimisticItem = Item(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );
      await _localCache.put(
        _collection,
        optimisticItem.id,
        optimisticItem.toJson(),
      );
      return Result.failure('Failed to create item, queued for later', e);
    }
  }

  Future<Result<Item>> updateItem(Item item) async {
    final params = item.toJson();

    if (_connectivity.isOffline) {
      await _offlineQueue.add(RequestType.updateItem, params);
      await _localCache.put(_collection, item.id, item.toJson());
      return Result.success(item);
    }

    try {
      final response = await _dioClient.put<Map<String, dynamic>>(
        '/items/${item.id}',
        data: params,
      );
      final updatedItem = Item.fromJson(response.data!);
      await _localCache.put(_collection, updatedItem.id, updatedItem.toJson());
      return Result.success(updatedItem);
    } catch (e) {
      await _offlineQueue.add(RequestType.updateItem, params);
      await _localCache.put(_collection, item.id, item.toJson());
      return Result.failure('Failed to update item, queued for later', e);
    }
  }

  Future<Result<void>> deleteItem(String id) async {
    final params = {'id': id};

    if (_connectivity.isOffline) {
      await _offlineQueue.add(RequestType.deleteItem, params);
      await _localCache.remove(_collection, id);
      return const Result.success(null);
    }

    try {
      await _dioClient.delete('/items/$id');
      await _localCache.remove(_collection, id);
      return const Result.success(null);
    } catch (e) {
      await _offlineQueue.add(RequestType.deleteItem, params);
      await _localCache.remove(_collection, id);
      return Result.failure('Failed to delete item, queued for later', e);
    }
  }

  Future<void> processOfflineQueue() async {
    await _offlineQueue.processQueue();
  }
}
