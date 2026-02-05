Add a new database collection with offline-first support.

## Input Required

Ask for:
- **Collection name** (plural, snake_case, e.g., `tasks`, `notes`, `orders`)
- **Document fields** (name, type, required/optional)
- **Query patterns** (how will data be fetched? by userId? by date? by status?)
- **Real-time needed?** (should UI update live when data changes on another device?)

## Steps

### 1. Create Model (if not exists)

Use `/new-model` command or create manually in the feature's `data/models/` directory.

Ensure the model has:
- `id` field (String)
- `userId` field (String) for user-scoped data
- `createdAt` and `updatedAt` fields (DateTime)
- `fromJson` / `toJson` via Freezed + json_serializable

### 2. Update Repository

Add collection methods to the appropriate repository:

```dart
// Cache-first read
Future<Result<List<MyModel>>> getMyModels() async {
  // 1. Check cache
  final cached = await _cache.getAll('my_models');
  if (cached.isSuccess && cached.dataOrNull!.isNotEmpty) {
    _emitCachedData(cached.dataOrNull!);
  }

  // 2. Fetch from remote
  if (!_connectivity.isOffline) {
    final result = await _db.query(
      'my_models',
      filters: [
        QueryFilter(field: 'userId', operator: QueryOperator.equals, value: _userId),
      ],
      orderBy: 'createdAt',
      descending: true,
    );

    if (result.isSuccess) {
      // 3. Update cache
      for (final doc in result.dataOrNull!) {
        await _cache.put('my_models', doc['id'], doc);
      }
    }
  }

  // 4. Fall back to cache
  return cached.mapSuccess(
    (docs) => docs.map((d) => MyModel.fromJson(d)).toList(),
  );
}

// Write-through mutation
Future<Result<MyModel>> createMyModel(Map<String, dynamic> data) async {
  if (_connectivity.isOffline) {
    // Cache locally + queue for sync
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    await _cache.put('my_models', tempId, {...data, 'id': tempId});
    await _offlineQueue.add(RequestType.createMyModel, data);
    return Result.success(MyModel.fromJson({...data, 'id': tempId}));
  }

  // Write to remote + cache
  final result = await _db.set('my_models', data);
  if (result.isSuccess) {
    final id = result.dataOrNull!;
    final doc = {...data, 'id': id};
    await _cache.put('my_models', id, doc);
    return Result.success(MyModel.fromJson(doc));
  }
  return Result.failure(result.errorOrNull ?? 'Failed to create');
}
```

### 3. Add Real-Time Watcher (if needed)

```dart
Stream<Result<List<MyModel>>> watchMyModels() {
  return _db.watchQuery(
    'my_models',
    filters: [
      QueryFilter(field: 'userId', operator: QueryOperator.equals, value: _userId),
    ],
    orderBy: 'createdAt',
    descending: true,
  ).map((result) => result.mapSuccess(
    (docs) => docs.map((d) => MyModel.fromJson(d)).toList(),
  ));
}
```

### 4. Update BLoC

Add events and state handling for the new collection data:
- Load event (triggers cache-first read)
- Create/update/delete events (triggers write-through)
- Watch event (subscribes to real-time stream, if applicable)

### 5. Add Request Types (for offline queue)

If using offline mutations, add entries to `RequestType` enum:

```dart
enum RequestType {
  // ... existing
  createMyModel,
  updateMyModel,
  deleteMyModel,
}
```

And handle in `RequestExecutor`.

### 6. Add Analytics Events (optional)

Use `/add-event` to track CRUD operations:
- `my_model_created`
- `my_model_updated`
- `my_model_deleted`

## Verification

1. Run `flutter test` — all tests pass
2. Test create → read → update → delete cycle
3. Test offline create → come back online → verify sync
4. Verify cache is cleared on logout

## Reference

Full patterns: `docs/database.md`
