Read and internalize the full architecture documentation before proceeding:

1. Read `docs/architecture.md` completely - this contains:
   - Tech stack with exact package versions
   - Project structure conventions
   - Freezed model patterns
   - Repository pattern with connectivity awareness
   - Result type pattern
   - Dependency injection setup with get_it
   - Network layer (DioClient, AuthInterceptor)
   - ConnectivityBloc and ConnectivityService
   - Offline queue implementation
   - BLoC patterns with Freezed events/states
   - Testing strategy and examples
   - Naming conventions

2. Read `docs/setup_reference.md` completely - this contains:
   - Critical implementation details for offline queue serialization
   - Auth token refresh flow
   - ConnectivityState.poor() detection logic
   - Retry with exponential backoff
   - Request deduplication with idempotency keys
   - Common pitfalls to avoid

After reading both files, confirm you understand:
- The two-layer architecture (no domain layer)
- How ConnectivityState (online/poor/offline) affects repository behavior
- The command pattern for offline queue serialization
- BLoC + Freezed event/state patterns
- get_it registration patterns (singletons vs factories)

Then ask what feature I'd like to add or what task I need help with.
