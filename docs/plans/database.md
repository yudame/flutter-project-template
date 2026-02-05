# Plan: Database Layer Implementation Guide & Starter Code

## Goal

Add an abstract database layer that lets repositories work with any backend (Firebase, Supabase, or mock) without coupling to a specific provider. Include offline-first caching with Hive and sync status tracking.

## Current State

- Architecture doc (`docs/architecture.md`) defines the database pattern: `User → Documents → Media`
- `ItemRepository` uses in-memory cache + DioClient for API-based data access
- `OfflineQueue` + `RequestExecutor` handle queued mutations when offline
- `Result<T>` type provides type-safe error handling
- `DioCacheInterceptor` provides HTTP-level response caching
- No abstract database interface exists
- No real-time listener patterns
- No sync status tracking

## Approach

Build on what exists rather than replacing it. The current repository pattern (connectivity-aware with cache fallback) is solid. The database layer adds:

1. **Abstract interface** so repositories can swap backends
2. **Local cache service** wrapping Hive for structured offline storage
3. **Sync status tracking** so UI can show sync state
4. **Real-time listener pattern** for multi-device use cases
5. **Documentation** covering all patterns and provider setup

We intentionally keep this **template-level** — provide the interfaces, one concrete implementation pattern, and documentation. Teams choose their backend and fill in the specifics.

**Key decision: Keep the Firebase implementation as documentation only (in docs + Claude command), not as committed code.** This avoids adding `firebase_core`/`cloud_firestore` as dependencies to the template. The abstract interface and local cache are real code.

---

## Files to Create

### 1. `docs/database.md`

Comprehensive documentation covering:

- **Architecture overview**: Abstract interface pattern, why we don't couple to a provider
- **Core principle**: `User → owns many → Documents (with optional media)`
- **DatabaseService interface**: CRUD + query + watch operations
- **LocalCacheService**: Hive-based structured cache for offline-first
- **SyncStatus**: Tracking whether local data matches remote
- **Offline-first strategy**:
  - Read: cache first, then remote, update cache on success
  - Write: write to cache immediately (optimistic), queue remote write
  - Sync: process queue when online, update sync status
- **Real-time listeners**: Stream-based pattern for live updates
- **Provider setup guides**: Firebase Firestore, Supabase, REST API
- **Conflict resolution**: Last-write-wins (simple) vs merge strategies
- **Migration patterns**: Schema versioning in Hive, Firestore document migration
- **Media storage**: Upload/download pattern with progress tracking
- **Security**: User-scoped data access, Firestore rules example

### 2. `lib/core/database/database_service.dart`

Abstract interface:

```dart
import '../utils/result.dart';

/// Abstract database service interface.
///
/// Implement for your backend: Firebase, Supabase, REST API, etc.
/// Repositories depend on this interface, not concrete implementations.
abstract class DatabaseService {
  /// Get a single document by ID
  Future<Result<Map<String, dynamic>>> get(String collection, String id);

  /// Query documents in a collection
  Future<Result<List<Map<String, dynamic>>>> query(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  });

  /// Create or update a document
  /// If [id] is null, auto-generate an ID
  Future<Result<String>> set(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  });

  /// Delete a document
  Future<Result<void>> delete(String collection, String id);

  /// Watch a single document for real-time updates
  Stream<Result<Map<String, dynamic>>> watch(String collection, String id);

  /// Watch a collection query for real-time updates
  Stream<Result<List<Map<String, dynamic>>>> watchQuery(
    String collection, {
    List<QueryFilter>? filters,
    String? orderBy,
    bool descending = false,
    int? limit,
  });
}

/// Filter for database queries
class QueryFilter {
  final String field;
  final QueryOperator operator;
  final dynamic value;

  const QueryFilter({
    required this.field,
    required this.operator,
    required this.value,
  });
}

/// Supported query operators
enum QueryOperator {
  equals,
  notEquals,
  lessThan,
  lessThanOrEquals,
  greaterThan,
  greaterThanOrEquals,
  contains,
  containsAny,
}
```

### 3. `lib/core/database/local_cache_service.dart`

Hive-based structured cache:

```dart
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
class LocalCacheService {
  final HiveInterface _hive;

  LocalCacheService({HiveInterface? hive}) : _hive = hive ?? Hive;

  /// Get a cached document
  Future<Result<Map<String, dynamic>?>> get(String collection, String id) async {
    try {
      final box = await _openBox(collection);
      final json = box.get(id);
      if (json == null) return const Result.success(null);
      return Result.success(jsonDecode(json) as Map<String, dynamic>);
    } catch (e) {
      return Result.failure('Cache read failed: $e');
    }
  }

  /// Get all cached documents in a collection
  Future<Result<List<Map<String, dynamic>>>> getAll(String collection) async {
    try {
      final box = await _openBox(collection);
      final items = box.values
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      return Result.success(items);
    } catch (e) {
      return Result.failure('Cache read failed: $e');
    }
  }

  /// Cache a document
  Future<void> put(String collection, String id, Map<String, dynamic> data) async {
    final box = await _openBox(collection);
    await box.put(id, jsonEncode(data));
  }

  /// Cache multiple documents
  Future<void> putAll(String collection, Map<String, Map<String, dynamic>> docs) async {
    final box = await _openBox(collection);
    final encoded = docs.map((k, v) => MapEntry(k, jsonEncode(v)));
    await box.putAll(encoded);
  }

  /// Remove a cached document
  Future<void> remove(String collection, String id) async {
    final box = await _openBox(collection);
    await box.delete(id);
  }

  /// Clear all documents in a collection
  Future<void> clear(String collection) async {
    final box = await _openBox(collection);
    await box.clear();
  }

  /// Check if a document exists in cache
  Future<bool> exists(String collection, String id) async {
    final box = await _openBox(collection);
    return box.containsKey(id);
  }

  Future<Box<String>> _openBox(String collection) async {
    final boxName = 'cache_$collection';
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<String>(boxName);
    }
    return _hive.openBox<String>(boxName);
  }
}
```

### 4. `lib/core/database/sync_status.dart`

Sync state tracking with Freezed:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Tracks the synchronization state of a local document.
///
/// Used to show sync indicators in the UI and manage
/// the offline queue processing.
@freezed
class SyncStatus with _$SyncStatus {
  /// Document is in sync with remote
  const factory SyncStatus.synced() = SyncStatusSynced;

  /// Document has local changes not yet pushed to remote
  const factory SyncStatus.pending() = SyncStatusPending;

  /// Document failed to sync (will retry)
  const factory SyncStatus.error(String message) = SyncStatusError;

  /// Document is currently syncing
  const factory SyncStatus.syncing() = SyncStatusSyncing;
}
```

### 5. `lib/core/database/cached_document.dart`

Wrapper that pairs data with sync status:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'sync_status.dart';

part 'cached_document.freezed.dart';
part 'cached_document.g.dart';

/// A document with its sync status and metadata.
///
/// Wraps raw data with tracking information for the offline-first pattern.
@freezed
class CachedDocument with _$CachedDocument {
  const factory CachedDocument({
    required String id,
    required Map<String, dynamic> data,
    @Default(SyncStatus.synced()) SyncStatus syncStatus,
    required DateTime cachedAt,
    DateTime? syncedAt,
  }) = _CachedDocument;
}
```

### 6. Update `lib/core/di/injection.dart`

Register the local cache service:

```dart
// Database
getIt.registerLazySingleton<LocalCacheService>(
  () => LocalCacheService(),
);

// When using a concrete database service:
// getIt.registerLazySingleton<DatabaseService>(
//   () => FirebaseDatabaseService(),
// );
```

### 7. Update `lib/features/home/data/repositories/item_repository.dart`

Show how to integrate `LocalCacheService` alongside existing API pattern:

```dart
// Add to existing repository:
// - Use LocalCacheService for structured cache instead of in-memory Map
// - Show cache-first read pattern
// - Show write-through pattern (cache + queue)
```

Note: This is a minimal update to demonstrate the pattern, not a full rewrite.

### 8. `.claude/commands/add-database.md`

Claude command to integrate database into a project:

```markdown
Set up database integration for this project.

Steps:
1. Choose provider (Firebase, Supabase, REST API)
2. If Firebase: add firebase_core + cloud_firestore deps, set up project
3. If Supabase: add supabase_flutter dep, configure URL + anon key
4. Create concrete DatabaseService implementation
5. Register in DI
6. Update repositories to use DatabaseService + LocalCacheService
7. Show cache-first read pattern
8. Show write-through mutation pattern
```

### 9. `.claude/commands/add-collection.md`

Claude command to add a new collection/table:

```markdown
Add a new database collection with offline-first support.

Steps:
1. Ask for: collection name, document fields, query patterns
2. Ensure model exists (or create with /new-model)
3. Update repository to use DatabaseService for this collection
4. Set up LocalCacheService for this collection
5. Add real-time watcher if needed
6. Show usage in BLoC
```

### 10. `test/core/database/local_cache_service_test.dart`

Tests for the cache service:

```dart
// Test:
// - put and get a document
// - getAll returns all documents
// - get returns null for missing document
// - remove deletes document
// - clear removes all documents
// - exists checks correctly
// - handles JSON serialization
```

---

## What We're NOT Doing

- **No Firebase/Supabase as committed dependencies** — the template stays backend-agnostic. Concrete implementations are in documentation and Claude commands, not in the dependency tree.
- **No complex conflict resolution** — document last-write-wins. Advanced merge strategies are app-specific.
- **No media storage implementation** — document the pattern, let teams implement for their provider.
- **No full migration framework** — document versioning patterns, don't build a migration runner.
- **No replacing the existing OfflineQueue** — the queue handles mutations. The database layer handles reads and structured caching. They complement each other.

## How It Fits Together

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

## Structure After Implementation

```
flutter-project-template/
├── lib/
│   └── core/
│       └── database/
│           ├── database_service.dart       # Abstract interface
│           ├── local_cache_service.dart     # Hive-based cache
│           ├── sync_status.dart            # Sync state (Freezed)
│           └── cached_document.dart        # Document + sync wrapper
├── test/
│   └── core/
│       └── database/
│           └── local_cache_service_test.dart
├── docs/
│   └── database.md
└── .claude/
    └── commands/
        ├── add-database.md
        └── add-collection.md
```

## Estimated Work

~10 files. Abstract interface + local cache are real code. Firebase/Supabase implementations are documentation only. One focused session.
