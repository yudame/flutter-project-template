Set up database integration for this project.

## Input Required

Ask for:
- **Provider**: Firebase Firestore, Supabase, or REST API
- **Collections**: What data the app stores (e.g., tasks, notes, orders)

## Steps

### 1. Add Provider Dependency

**Firebase:**
```yaml
dependencies:
  firebase_core: ^3.0.0
  cloud_firestore: ^5.0.0
```

**Supabase:**
```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

**REST API:** No additional dependencies (uses existing DioClient).

Then run: `flutter pub get`

### 2. Create Concrete DatabaseService Implementation

Create `lib/core/database/{provider}_database_service.dart` implementing `DatabaseService`.

See `docs/database.md` for complete implementation examples for each provider.

Key methods to implement:
- `get` — fetch single document by ID
- `query` — fetch documents with filters, ordering, limits
- `set` — create or update a document
- `delete` — remove a document
- `watch` — real-time single document listener
- `watchQuery` — real-time collection query listener

### 3. Register in DI

Update `lib/core/di/injection.dart`:

```dart
import '../database/database_service.dart';
import '../database/{provider}_database_service.dart';

// In configureDependencies():
getIt.registerLazySingleton<DatabaseService>(
  () => {Provider}DatabaseService(),
);
```

`LocalCacheService` should already be registered. If not:

```dart
import '../database/local_cache_service.dart';

getIt.registerLazySingleton<LocalCacheService>(
  () => LocalCacheService(hive: getIt<HiveInterface>()),
);
```

### 4. Update Repositories

Update repositories to use `DatabaseService` + `LocalCacheService`:

```dart
class ItemRepository {
  final DatabaseService _db;
  final LocalCacheService _cache;
  final ConnectivityService _connectivity;
  final OfflineQueue _offlineQueue;

  // Cache-first read pattern
  Future<Result<List<Item>>> getItems() async {
    // 1. Return cached data immediately
    final cached = await _cache.getAll('items');
    // 2. Fetch from remote in background
    // 3. Update cache with fresh data
    // See docs/database.md for full pattern
  }
}
```

### 5. Set Up Security Rules (if applicable)

**Firebase:** Configure Firestore security rules for user-scoped access.
**Supabase:** Configure Row Level Security (RLS) policies.

See `docs/database.md` for example rules.

## Verification

1. Run `flutter analyze` — no errors
2. Run `flutter test` — all tests pass
3. Test CRUD operations manually
4. Test offline behavior (airplane mode)

## Reference

Full documentation: `docs/database.md`
