import 'dart:convert';

import 'package:hive/hive.dart';

import '../utils/result.dart';

/// Local cache service using Hive for offline-first data storage.
///
/// Stores documents as JSON maps in collection-specific Hive boxes.
/// Used alongside [DatabaseService] for the offline-first pattern:
///
/// 1. Read from cache first (instant)
/// 2. Fetch from remote in background
/// 3. Update cache with remote data
/// 4. Notify listeners of changes
///
/// Each collection gets its own Hive box (`cache_items`, `cache_users`, etc.),
/// keeping data isolated and manageable.
///
/// Example:
/// ```dart
/// final cache = getIt<LocalCacheService>();
///
/// // Cache a document
/// await cache.put('items', item.id, item.toJson());
///
/// // Read from cache
/// final result = await cache.get('items', itemId);
///
/// // Get all cached items
/// final all = await cache.getAll('items');
/// ```
///
/// See `docs/database.md` for full offline-first patterns.
class LocalCacheService {
  final HiveInterface _hive;

  /// Creates a [LocalCacheService] backed by the given [HiveInterface].
  ///
  /// If [hive] is null, uses the global [Hive] instance.
  LocalCacheService({HiveInterface? hive}) : _hive = hive ?? Hive;

  /// Get a cached document by collection and ID.
  ///
  /// Returns `Result.success(null)` if the document is not cached.
  Future<Result<Map<String, dynamic>?>> get(
    String collection,
    String id,
  ) async {
    try {
      final box = await _openBox(collection);
      final json = box.get(id);
      if (json == null) return const Result.success(null);
      return Result.success(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (e) {
      return Result.failure('Cache read failed: $e');
    }
  }

  /// Get all cached documents in a collection.
  ///
  /// Returns an empty list if no documents are cached.
  Future<Result<List<Map<String, dynamic>>>> getAll(
    String collection,
  ) async {
    try {
      final box = await _openBox(collection);
      final items = box.values
          .map((json) => Map<String, dynamic>.from(jsonDecode(json) as Map))
          .toList();
      return Result.success(items);
    } catch (e) {
      return Result.failure('Cache read failed: $e');
    }
  }

  /// Cache a document.
  ///
  /// Overwrites any existing document with the same [id].
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    final box = await _openBox(collection);
    await box.put(id, jsonEncode(data));
  }

  /// Cache multiple documents at once.
  ///
  /// More efficient than calling [put] in a loop.
  Future<void> putAll(
    String collection,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    final box = await _openBox(collection);
    final encoded = docs.map((k, v) => MapEntry(k, jsonEncode(v)));
    await box.putAll(encoded);
  }

  /// Remove a cached document.
  Future<void> remove(String collection, String id) async {
    final box = await _openBox(collection);
    await box.delete(id);
  }

  /// Clear all documents in a collection cache.
  ///
  /// Useful on logout or when forcing a full refresh.
  Future<void> clear(String collection) async {
    final box = await _openBox(collection);
    await box.clear();
  }

  /// Check if a document exists in cache.
  Future<bool> exists(String collection, String id) async {
    final box = await _openBox(collection);
    return box.containsKey(id);
  }

  /// Get the count of cached documents in a collection.
  Future<int> count(String collection) async {
    final box = await _openBox(collection);
    return box.length;
  }

  /// Open (or return already-open) Hive box for a collection.
  Future<Box<String>> _openBox(String collection) async {
    final boxName = 'cache_$collection';
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<String>(boxName);
    }
    return _hive.openBox<String>(boxName);
  }
}
