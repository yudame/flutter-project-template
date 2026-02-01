Read and internalize the architecture documentation before proceeding:

1. Read `docs/implemented.md` - documentation for already-built features:
   - Core patterns (Freezed models, Repository, Result type)
   - Dependency injection with get_it
   - Network layer (DioClient, AuthInterceptor)
   - ConnectivityBloc and ConnectivityService
   - Offline queue implementation
   - BLoC patterns with Freezed events/states
   - Testing strategy and examples

2. Read `docs/architecture.md` - reference guidelines + planned features:
   - Philosophy and principles
   - Tech stack with exact package versions
   - Project structure conventions
   - **Planned: Database Layer** (not yet implemented)
   - Code generation commands
   - Naming conventions

3. Read `docs/setup_reference.md` - critical implementation details:
   - Offline queue serialization
   - Auth token refresh flow
   - ConnectivityState.poor() detection logic
   - Retry with exponential backoff
   - Request deduplication with idempotency keys
   - Common pitfalls to avoid

After reading, confirm you understand:
- The two-layer architecture (no domain layer)
- How ConnectivityState (online/poor/offline) affects repository behavior
- The command pattern for offline queue serialization
- BLoC + Freezed event/state patterns
- get_it registration patterns (singletons vs factories)

Then ask what feature I'd like to add or what task I need help with.
