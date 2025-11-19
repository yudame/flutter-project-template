# Flutter Project Template

**Production-ready Flutter architecture for small teams with AI-assisted development**

This template provides battle-tested architecture patterns and setup guides that you can copy to any Flutter project. Designed for 2-5 person teams leveraging AI code generation tools like Claude, Copilot, and GPT.

---

## 📚 Documentation

### [Architecture Guide](docs/architecture.md)
Complete architecture specification covering:
- Philosophy & principles (two-layer, BLoC, connectivity-first)
- Tech stack with latest package versions
- Project folder structure
- Core patterns (Freezed models, repositories, Result type)
- Dependency injection with get_it
- Network layer with Dio interceptors
- Connectivity strategy (online/poor/offline states)
- Offline queue implementation
- BLoC patterns with Freezed
- Testing strategy with examples
- AI prompt templates for code generation

### [Setup & Reference Guide](docs/setup_reference.md)
Complete setup guide and critical implementation patterns:
- 5-minute quick project creation
- macOS development environment setup
- Offline queue serialization patterns
- Auth token refresh flow
- ConnectivityState detection
- Retry with exponential backoff
- Request deduplication
- Common pitfalls to avoid

---

## 🎯 Philosophy

**Start with official Flutter tooling, add only what you need, establish clear conventions.**

### Key Principles

- ✅ **Two-layer architecture** - Presentation + Data (no premature domain abstraction)
- ✅ **Freezed everywhere** - Models, events, states use sealed unions (AI-friendly)
- ✅ **Connectivity-first** - Explicit handling of online/poor/offline states
- ✅ **BLoC pattern** - Official Flutter recommendation, clear separation
- ✅ **Testing focus** - BLoCs 90%+, repositories 70%+, widgets selectively
- ✅ **Production ready** - Monitoring, secure storage, offline support from day one

---

## 🚀 Quick Start

### 1. Copy Documentation to Your Project

```bash
# In your Flutter project
mkdir -p plans
cp path/to/this/repo/docs/* plans/

# Or just reference this repo
```

### 2. Follow the Setup Guide

See [docs/setup_reference.md](docs/setup_reference.md) for complete setup instructions.

### 3. Customize for Your Domain

Find/replace generic examples with your specifics:
- `Item` → `YourModel`
- `createItem/updateItem/deleteItem` → Your operations
- `/items` → Your API endpoints
- `RequestType` enum → Your actual request types

### 4. Keep the Patterns

The architecture patterns are domain-agnostic and battle-tested!

---

## 📦 Tech Stack

**State Management:**
- `flutter_bloc` + `hydrated_bloc`
- `freezed` for immutable models

**Navigation:**
- `go_router` (official Flutter recommendation)

**Network & Connectivity:**
- `dio` with interceptors
- `connectivity_plus`
- `dio_cache_interceptor`

**Storage:**
- `hive` for offline queue
- `flutter_secure_storage` for auth tokens
- `shared_preferences` for settings

**Dependency Injection:**
- `get_it` service locator

**Monitoring:**
- `sentry_flutter` for production errors

---

## 📁 Recommended Project Structure

```
your-flutter-app/
├── docs/                   # Copy architecture docs here
│   ├── architecture.md
│   └── setup_reference.md
├── lib/
│   ├── core/
│   │   ├── theme/
│   │   ├── routes/
│   │   ├── network/
│   │   ├── connectivity/
│   │   ├── di/
│   │   └── utils/
│   ├── features/
│   │   └── [feature_name]/
│   │       ├── data/
│   │       │   ├── models/
│   │       │   ├── repositories/
│   │       │   └── datasources/
│   │       └── presentation/
│   │           ├── bloc/
│   │           ├── pages/
│   │           └── widgets/
│   └── shared/
└── test/
```

---

## 🎓 Key Patterns

### Connectivity-Aware Repositories

```dart
class DataRepository {
  Future<Result<Data>> fetchData(String id) async {
    return _connectivity.state.when(
      online: () async {
        final data = await _api.fetchData(id);
        await _local.cache(data);
        return Result.success(data);
      },
      poor: () async {
        try {
          return await _api.fetchData(id).timeout(Duration(seconds: 5));
        } catch (e) {
          return _tryCache(id);
        }
      },
      offline: () => _tryCache(id),
    );
  }
}
```

### BLoC with Freezed States

```dart
@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState.initial() = _Initial;
  const factory FeatureState.loading() = _Loading;
  const factory FeatureState.loaded(Data data) = _Loaded;
  const factory FeatureState.error(String message) = _Error;
}
```

### Offline Queue

```dart
// Serialize requests with command pattern
@HiveType(typeId: 0)
class QueuedRequest {
  @HiveField(0) final String id;
  @HiveField(1) final RequestType type;
  @HiveField(2) final Map<String, dynamic> params;
  @HiveField(3) final DateTime queuedAt;
}
```

---

## 🧪 Testing Philosophy

- **BLoCs:** Always test (target 90%+ coverage)
- **Repositories:** Usually test (target 70%+ coverage)
- **Widgets:** Selectively test (complex logic only)

---

## 🤖 AI-Friendly

This architecture is optimized for AI code generation:

- **Simple, predictable patterns** - Easy for AI to replicate
- **Freezed sealed unions** - Clear type-safe patterns
- **Feature-first organization** - Isolated, modular code
- **Comprehensive examples** - AI can learn from templates

### Example AI Prompts

```
Generate a Flutter feature called Users with:
- Freezed model for User with json_serializable
- Repository with connectivity awareness (online/poor/offline handling)
- BLoC with Freezed events/states (initial, loading, loaded, error)
- Simple page displaying users using BlocBuilder
Use get_it for dependency injection
Follow the architecture in docs/architecture.md
```

---

## 🤝 Contributing

This template is based on real-world production apps. If you have suggestions or improvements:

1. Open an issue describing the pattern/problem
2. Submit a PR with updated documentation
3. Share your experience using this template

---

## 📝 License

MIT License - feel free to use this in your projects!

---

## 🙏 Credits

This architecture template synthesizes best practices from:
- Official Flutter documentation
- BLoC library patterns
- Real-world production apps
- Community feedback and AI-assisted development workflows

---

**Built for teams that ship fast without sacrificing quality.** 🚀
