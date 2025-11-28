import 'package:logger/logger.dart';

import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/connectivity/connectivity_state.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/offline_queue.dart';
import '../../../../core/network/queued_request.dart';
import '../../../../core/utils/result.dart';
import '../models/item.dart';

class ItemRepository {
  final DioClient _dioClient;
  final ConnectivityService _connectivity;
  final OfflineQueue _offlineQueue;
  final Logger _logger;

  // In-memory cache for demo purposes
  // In production, use Hive or another local database
  final Map<String, Item> _cache = {};

  ItemRepository({
    required DioClient dioClient,
    required ConnectivityService connectivity,
    required OfflineQueue offlineQueue,
    required Logger logger,
  })  : _dioClient = dioClient,
        _connectivity = connectivity,
        _offlineQueue = offlineQueue,
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

      // Update cache
      for (final item in items) {
        _cache[item.id] = item;
      }

      _logger.i('Fetched ${items.length} items from API');
      return Result.success(items);
    } catch (e) {
      _logger.e('Failed to fetch items: $e');
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

      // Update cache
      for (final item in items) {
        _cache[item.id] = item;
      }

      return Result.success(items);
    } catch (e) {
      _logger.w('API fetch timed out, falling back to cache');
      return _fetchFromCache();
    }
  }

  Future<Result<List<Item>>> _fetchFromCache() {
    if (_cache.isEmpty) {
      return Future.value(const Result.failure('No cached data available'));
    }
    return Future.value(Result.success(_cache.values.toList()));
  }

  Future<Result<Item>> getItem(String id) async {
    final state = _connectivity.currentState;

    if (state is ConnectivityOffline) {
      final cached = _cache[id];
      if (cached != null) {
        return Result.success(cached);
      }
      return const Result.failure('Item not found in cache');
    }

    try {
      final response = await _dioClient.get<Map<String, dynamic>>('/items/$id');
      final item = Item.fromJson(response.data!);
      _cache[item.id] = item;
      return Result.success(item);
    } catch (e) {
      // Try cache on failure
      final cached = _cache[id];
      if (cached != null) {
        return Result.success(cached);
      }
      return Result.failure('Failed to fetch item', e);
    }
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
      // Create optimistic local item
      final optimisticItem = Item(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        description: description,
        createdAt: DateTime.now(),
      );
      _cache[optimisticItem.id] = optimisticItem;
      return Result.success(optimisticItem);
    }

    try {
      final response = await _dioClient.post<Map<String, dynamic>>(
        '/items',
        data: params,
      );
      final item = Item.fromJson(response.data!);
      _cache[item.id] = item;
      return Result.success(item);
    } catch (e) {
      // Queue for later if failed
      await _offlineQueue.add(RequestType.createItem, params);
      return Result.failure('Failed to create item, queued for later', e);
    }
  }

  Future<Result<Item>> updateItem(Item item) async {
    final params = item.toJson();

    if (_connectivity.isOffline) {
      await _offlineQueue.add(RequestType.updateItem, params);
      _cache[item.id] = item;
      return Result.success(item);
    }

    try {
      final response = await _dioClient.put<Map<String, dynamic>>(
        '/items/${item.id}',
        data: params,
      );
      final updatedItem = Item.fromJson(response.data!);
      _cache[updatedItem.id] = updatedItem;
      return Result.success(updatedItem);
    } catch (e) {
      await _offlineQueue.add(RequestType.updateItem, params);
      _cache[item.id] = item;
      return Result.failure('Failed to update item, queued for later', e);
    }
  }

  Future<Result<void>> deleteItem(String id) async {
    final params = {'id': id};

    if (_connectivity.isOffline) {
      await _offlineQueue.add(RequestType.deleteItem, params);
      _cache.remove(id);
      return const Result.success(null);
    }

    try {
      await _dioClient.delete('/items/$id');
      _cache.remove(id);
      return const Result.success(null);
    } catch (e) {
      await _offlineQueue.add(RequestType.deleteItem, params);
      _cache.remove(id);
      return Result.failure('Failed to delete item, queued for later', e);
    }
  }

  Future<void> processOfflineQueue() async {
    await _offlineQueue.processQueue();
  }
}
