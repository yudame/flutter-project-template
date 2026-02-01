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
4. [Planned: Database Layer](#planned-database-layer)
5. [Code Generation](#code-generation)
6. [Common Conventions](#common-conventions)
7. [AI Prompt Templates](#ai-prompt-templates)
8. [Production Checklist](#production-checklist)
9. [Resources](#resources)

**For already-implemented features, see [implemented.md](implemented.md)**

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

- No premature domain layer abstraction
- No over-complicated repository interfaces
- No implicit connectivity assumptions
- No skipping dependency injection
- No testing only happy paths

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
│   ├── database/           # DatabaseService, StorageService [PLANNED]
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

## Planned: Database Layer

> **Status: NOT IMPLEMENTED** - This section describes the planned database abstraction layer.

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

### Sync Status Tracking

```dart
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus.synced() = _Synced;
  const factory SyncStatus.pending() = _Pending;
  const factory SyncStatus.error(String message) = _Error;
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
| Personal notes/logs | No | Single user, pull-to-refresh sufficient |
| Photo uploads | No | Async processing, poll for status |
| Chat messages | Yes | Multi-user, instant updates expected |
| Shared documents | Yes | Collaboration requires live sync |
| Notifications | Yes | Time-sensitive |

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
