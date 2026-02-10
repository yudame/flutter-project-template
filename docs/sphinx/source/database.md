# Database Layer

This guide covers database patterns for Flutter apps using this template.

## Overview

The template provides a **backend-agnostic database layer** with:

- **Abstract `DatabaseService` interface** — swap Firebase, Supabase, or REST without changing repositories
- **`LocalCacheService`** — Hive-based structured cache for offline-first reads
- **`SyncStatus`** — track whether local data matches remote
- **Existing `OfflineQueue`** — handles queued mutations when offline

These components work together for a complete offline-first architecture.

## Architecture

```
┌─────────────┐
│   BLoC       │  Drives UI, handles events
└──────┬──────┘
       │
┌──────▼──────┐
│ Repository   │  Orchestrates data flow
│              │  - Reads: cache first → remote → update cache
│              │  - Writes: cache + remote (or queue if offline)
└──────┬──────┘
       │
┌──────▼──────────────────────────────┐
│                                      │
│  ┌──────────────┐  ┌──────────────┐  │
│  │ LocalCache   │  │ Database     │  │
│  │ Service      │  │ Service      │  │
│  │ (Hive)       │  │ (Firebase/   │  │
│  │              │  │  Supabase/   │  │
│  │ Always       │  │  REST)       │  │
│  │ available    │  │              │  │
│  └──────────────┘  └──────────────┘  │
│                                      │
│  ┌──────────────┐                    │
│  │ OfflineQueue │  Queues mutations  │
│  │ (Hive)       │  when offline      │
│  └──────────────┘                    │
│                                      │
└──────────────────────────────────────┘
```

### Core Principle

All apps reduce to: **User → owns many → Documents (with optional media)**

This pattern covers:
- Todo apps (User → Tasks)
- Note apps (User → Notes + Attachments)
- E-commerce (User → Orders → Items)
- Social apps (User → Posts + Media)

## DatabaseService Interface

The abstract interface defines CRUD + query + real-time operations:

```dart
abstract class DatabaseService {
  Future<Result<Map<String, dynamic>>> get(String collection, String id);

  Future<Result<List<Map<String, dynamic>>>> query(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending,
    int? limit,
  });

  Future<Result<String>> set(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  });

  Future<Result<void>> delete(String collection, String id);

  Stream<Result<Map<String, dynamic>>> watch(String collection, String id);

  Stream<Result<List<Map<String, dynamic>>>> watchQuery(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending,
    int? limit,
  });
}
```

### Query Filters

```dart
final results = await db.query(
  'items',
  filters: [
    QueryFilter(field: 'userId', operator: QueryOperator.equals, value: userId),
    QueryFilter(field: 'createdAt', operator: QueryOperator.greaterThan, value: lastWeek),
  ],
  orderBy: 'createdAt',
  descending: true,
  limit: 20,
);
```

### Why `Map<String, dynamic>`?

The interface uses raw maps rather than generics because:
- No runtime type information needed at the database layer
- Repositories handle serialization with Freezed models
- Keeps the interface simple and provider-agnostic

Repositories convert:
```dart
// In repository
final result = await _db.get('items', id);
return result.mapSuccess((data) => Item.fromJson(data));
```

## LocalCacheService

Hive-based structured cache for offline-first data access:

```dart
final cache = getIt<LocalCacheService>();

// Cache a document
await cache.put('items', item.id, item.toJson());

// Read from cache
final result = await cache.get('items', itemId);

// Get all cached items
final all = await cache.getAll('items');

// Check existence
final exists = await cache.exists('items', itemId);

// Remove
await cache.remove('items', itemId);

// Clear entire collection cache
await cache.clear('items');
```

Each collection gets its own Hive box (`cache_items`, `cache_users`, etc.), keeping data isolated and manageable.

## Offline-First Patterns

### Cache-First Read

```dart
Future<Result<List<Item>>> getItems() async {
  // 1. Return cached data immediately (if available)
  final cached = await _cache.getAll('items');
  if (cached.isSuccess && cached.dataOrNull!.isNotEmpty) {
    _emitCachedItems(cached.dataOrNull!);
  }

  // 2. Fetch from remote in background
  if (!_connectivity.isOffline) {
    try {
      final result = await _db.query('items',
        filters: [QueryFilter(field: 'userId', operator: QueryOperator.equals, value: _userId)],
        orderBy: 'createdAt',
        descending: true,
      );

      if (result.isSuccess) {
        // 3. Update cache with fresh data
        final docs = result.dataOrNull!;
        for (final doc in docs) {
          await _cache.put('items', doc['id'], doc);
        }
        return result.mapSuccess(
          (docs) => docs.map((d) => Item.fromJson(d)).toList(),
        );
      }
    } catch (e) {
      // Network failed — cached data is still showing
    }
  }

  // 4. Fall back to cache
  return cached.mapSuccess(
    (docs) => docs.map((d) => Item.fromJson(d)).toList(),
  );
}
```

### Write-Through with Optimistic Update

```dart
Future<Result<Item>> createItem(String title) async {
  final data = {
    'title': title,
    'createdAt': DateTime.now().toIso8601String(),
    'userId': _userId,
  };

  if (_connectivity.isOffline) {
    // 1. Write to cache immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _cache.put('items', tempId, {...data, 'id': tempId});

    // 2. Queue for remote sync
    await _offlineQueue.add(RequestType.createItem, data);

    return Result.success(Item.fromJson({...data, 'id': tempId}));
  }

  try {
    // 1. Write to remote
    final result = await _db.set('items', data);

    if (result.isSuccess) {
      final id = result.dataOrNull!;
      final doc = {...data, 'id': id};

      // 2. Update cache
      await _cache.put('items', id, doc);

      return Result.success(Item.fromJson(doc));
    }

    return Result.failure(result.errorOrNull ?? 'Failed to create');
  } catch (e) {
    // Queue on failure
    await _offlineQueue.add(RequestType.createItem, data);
    return Result.failure('Queued for later', e);
  }
}
```

## Sync Status

Track whether local documents are synced with remote:

```dart
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus.synced() = SyncStatusSynced;
  const factory SyncStatus.pending() = SyncStatusPending;
  const factory SyncStatus.error(String message) = SyncStatusError;
  const factory SyncStatus.syncing() = SyncStatusSyncing;
}
```

### Using in UI

```dart
BlocBuilder<ItemBloc, ItemState>(
  builder: (context, state) {
    return state.when(
      loaded: (items, syncStatus) {
        return Column(
          children: [
            // Show sync indicator
            syncStatus.when(
              synced: () => const SizedBox.shrink(),
              pending: () => const LinearProgressIndicator(),
              syncing: () => const LinearProgressIndicator(),
              error: (msg) => Text('Sync failed: $msg'),
            ),
            // Show items
            ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => ItemCard(item: items[i]),
            ),
          ],
        );
      },
      // ...
    );
  },
)
```

## Real-Time Listeners

For multi-device sync, use the `watch` and `watchQuery` methods:

```dart
class ItemBloc extends Bloc<ItemEvent, ItemState> {
  StreamSubscription? _itemSubscription;

  void _onStartWatching(Emitter<ItemState> emit) {
    _itemSubscription?.cancel();
    _itemSubscription = _db.watchQuery(
      'items',
      filters: [
        QueryFilter(field: 'userId', operator: QueryOperator.equals, value: _userId),
      ],
      orderBy: 'createdAt',
      descending: true,
    ).listen((result) {
      result.when(
        success: (docs) {
          final items = docs.map((d) => Item.fromJson(d)).toList();
          add(ItemEvent.itemsUpdated(items));
        },
        failure: (msg, _) => add(ItemEvent.error(msg)),
        loading: () {},
      );
    });
  }

  @override
  Future<void> close() {
    _itemSubscription?.cancel();
    return super.close();
  }
}
```

## Provider Setup

### Firebase Firestore

1. Add dependencies:
   ```yaml
   dependencies:
     firebase_core: ^3.0.0
     cloud_firestore: ^5.0.0
   ```

2. Create implementation:
   ```dart
   class FirebaseDatabaseService implements DatabaseService {
     final FirebaseFirestore _firestore;

     FirebaseDatabaseService({FirebaseFirestore? firestore})
         : _firestore = firestore ?? FirebaseFirestore.instance;

     @override
     Future<Result<Map<String, dynamic>>> get(String collection, String id) async {
       try {
         final doc = await _firestore.collection(collection).doc(id).get();
         if (!doc.exists) return const Result.failure('Document not found');
         return Result.success({...doc.data()!, 'id': doc.id});
       } catch (e) {
         return Result.failure('Failed to get document: $e');
       }
     }

     @override
     Future<Result<List<Map<String, dynamic>>>> query(
       String collection, {
       List<QueryFilter>? filters,
       String? orderBy,
       bool descending = false,
       int? limit,
     }) async {
       try {
         Query query = _firestore.collection(collection);

         for (final filter in filters ?? []) {
           query = _applyFilter(query, filter);
         }
         if (orderBy != null) {
           query = query.orderBy(orderBy, descending: descending);
         }
         if (limit != null) {
           query = query.limit(limit);
         }

         final snapshot = await query.get();
         final docs = snapshot.docs
             .map((doc) => {...doc.data() as Map<String, dynamic>, 'id': doc.id})
             .toList();
         return Result.success(docs);
       } catch (e) {
         return Result.failure('Query failed: $e');
       }
     }

     @override
     Stream<Result<Map<String, dynamic>>> watch(String collection, String id) {
       return _firestore.collection(collection).doc(id).snapshots().map((doc) {
         if (!doc.exists) return const Result.failure('Document not found');
         return Result.success({...doc.data()!, 'id': doc.id});
       });
     }

     // ... remaining methods follow same pattern
   }
   ```

3. Register in DI:
   ```dart
   getIt.registerLazySingleton<DatabaseService>(
     () => FirebaseDatabaseService(),
   );
   ```

4. Security rules (example):
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /items/{itemId} {
         allow read, write: if request.auth != null
           && request.auth.uid == resource.data.userId;
       }
     }
   }
   ```

### Supabase

1. Add dependency:
   ```yaml
   dependencies:
     supabase_flutter: ^2.0.0
   ```

2. Create implementation:
   ```dart
   class SupabaseDatabaseService implements DatabaseService {
     final SupabaseClient _client;

     SupabaseDatabaseService({SupabaseClient? client})
         : _client = client ?? Supabase.instance.client;

     @override
     Future<Result<Map<String, dynamic>>> get(String collection, String id) async {
       try {
         final data = await _client
             .from(collection)
             .select()
             .eq('id', id)
             .single();
         return Result.success(data);
       } catch (e) {
         return Result.failure('Failed to get record: $e');
       }
     }

     @override
     Stream<Result<List<Map<String, dynamic>>>> watchQuery(
       String collection, {
       List<QueryFilter>? filters,
       String? orderBy,
       bool descending = false,
       int? limit,
     }) {
       return _client
           .from(collection)
           .stream(primaryKey: ['id'])
           .map((data) => Result.success(data));
     }

     // ... remaining methods
   }
   ```

### REST API (Default Template Pattern)

The existing `DioClient` + repository pattern effectively serves as a REST implementation. To formalize:

```dart
class RestDatabaseService implements DatabaseService {
  final DioClient _client;

  RestDatabaseService({required DioClient client}) : _client = client;

  @override
  Future<Result<Map<String, dynamic>>> get(String collection, String id) async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/$collection/$id');
      return Result.success(response.data!);
    } catch (e) {
      return Result.failure('Request failed: $e');
    }
  }

  @override
  Stream<Result<Map<String, dynamic>>> watch(String collection, String id) {
    // REST doesn't natively support real-time
    // Options: polling, WebSocket, or SSE
    throw UnsupportedError('REST API does not support real-time listeners');
  }

  // ... remaining methods
}
```

## Conflict Resolution

### Last-Write-Wins (Simple)

The simplest strategy. Each document has an `updatedAt` timestamp. The latest write wins:

```dart
Future<Result<void>> set(String collection, Map<String, dynamic> data, {String? id}) async {
  // Always include updatedAt
  final withTimestamp = {
    ...data,
    'updatedAt': DateTime.now().toIso8601String(),
  };
  // Write to remote — last write wins
  return _db.set(collection, withTimestamp, id: id);
}
```

This works well for most apps. Consider more complex strategies only if:
- Multiple users edit the same document simultaneously
- Edits are to specific fields, not the whole document
- Data loss from overwriting is unacceptable

### Field-Level Merge

For collaborative editing, merge at the field level:

```dart
Future<void> mergeUpdate(String collection, String id, Map<String, dynamic> changes) async {
  final current = await _db.get(collection, id);
  if (current.isSuccess) {
    final merged = {...current.dataOrNull!, ...changes, 'updatedAt': DateTime.now().toIso8601String()};
    await _db.set(collection, merged, id: id);
  }
}
```

## Migration Patterns

### Hive Cache Versioning

```dart
class LocalCacheService {
  static const int _cacheVersion = 1;

  Future<void> initialize() async {
    final versionBox = await Hive.openBox('cache_meta');
    final storedVersion = versionBox.get('version', defaultValue: 0);

    if (storedVersion < _cacheVersion) {
      // Clear old cache format
      await _clearAllCaches();
      await versionBox.put('version', _cacheVersion);
    }
  }
}
```

### Document Schema Migration

```dart
// In repository, handle old document formats:
Item _parseItem(Map<String, dynamic> json) {
  // Handle v1 format (no 'updatedAt' field)
  if (!json.containsKey('updatedAt')) {
    json['updatedAt'] = json['createdAt'];
  }
  return Item.fromJson(json);
}
```

## Media Storage

### Pattern

```dart
abstract class StorageService {
  /// Upload a file, returns the download URL
  Future<Result<String>> upload(String path, Uint8List data, {String? contentType});

  /// Download a file
  Future<Result<Uint8List>> download(String path);

  /// Delete a file
  Future<Result<void>> delete(String path);

  /// Get a download URL (for display in Image widgets)
  Future<Result<String>> getDownloadUrl(String path);
}
```

### User-Scoped Storage

```dart
// Always namespace storage paths by user
final storagePath = 'users/$userId/items/$itemId/photo.jpg';
final url = await _storage.upload(storagePath, imageBytes);
```

### Image Upload with Progress

```dart
Future<Result<String>> uploadImage(String itemId, Uint8List imageData) async {
  final path = 'users/$userId/items/$itemId/photo.jpg';

  if (_connectivity.isOffline) {
    // Save locally, queue upload
    await _cache.put('pending_uploads', itemId, {
      'path': path,
      'localPath': await _saveLocally(imageData),
    });
    return const Result.failure('Queued for upload');
  }

  return _storage.upload(path, imageData, contentType: 'image/jpeg');
}
```

## Best Practices

1. **Always use `LocalCacheService` alongside `DatabaseService`** — never rely solely on remote
2. **Cache writes are synchronous** from the user's perspective (optimistic)
3. **Queue failures, don't throw** — use `OfflineQueue` for retryable mutations
4. **Scope data by user** — `userId` field on all documents, security rules enforce access
5. **Keep cache fresh** — clear on logout, refresh on app resume
6. **Don't cache sensitive data** — use `flutter_secure_storage` for tokens, not Hive
7. **Handle schema evolution** — version your cache, handle missing fields gracefully

## Make Commands

```bash
make gen    # Regenerate Freezed files (after modifying SyncStatus, etc.)
make test   # Run all tests including cache service tests
```
