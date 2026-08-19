---
status: Ready
type: feature
appetite: Medium
owner: yudame
created: 2026-08-19
tracking: https://github.com/yudame/flutter-project-template/issues/14
last_comment_id:
---

# Plan: Streaming Network Layer (SSE) for AI/Chat Features

## Goal

Add a streaming network layer to the template's network core so AI/chat features can render tokens as they arrive, instead of waiting for a complete response. Provide a documented, reusable pattern with a worked example.

## Current State

- **Existing infrastructure**:
  - `lib/core/network/dio_client.dart` — Dio configured for request/response with an auth interceptor
  - `lib/core/network/offline_queue.dart` — request queuing with retry
  - `lib/core/network/request_executor.dart` — executes queued requests
  - `lib/core/utils/result.dart` — `Result<T>` success/failure/loading pattern
- **Missing**:
  - No streaming/SSE support anywhere in the network core
  - No pattern for consuming a token-by-token response stream
  - No worked example of a streaming feature

## Approach

Add a streaming capability to the network core that composes with the existing `Result<T>` and connectivity-first patterns, without disturbing the request/response path.

**Key decisions**:
1. **Dio's `ResponseType.stream` is the base** — Dio already supports streaming responses natively; no new HTTP client dependency is needed. The stream is exposed as a `Stream<String>` of decoded chunks.
2. **A `StreamingClient` abstraction** — a thin wrapper over Dio that returns a `Stream<Result<String>>` (or a `Stream<String>` of tokens) for a given request. Keeps the network layer testable and swappable.
3. **SSE framing handled in one place** — Server-Sent Events (`data:` lines) are parsed by a small helper so callers get clean tokens, not raw wire format. This is the part most chat/AI backends emit.
4. **Composes with connectivity** — the streaming path respects the same connectivity states: online streams live, poor/offline falls back to a cached or error result.
5. **Worked example** — a `features/chat/` reference feature (mirroring `features/home/`) that streams tokens into a UI, so teams have a copy-paste starting point. This is the first consumer: the kids' chat app in `counsell-home/apps/chat`.

**Out of scope**: the LLM proxy backend, auth, and any provider-specific chat logic. This is the transport layer only.

## Files to Create

### 1. `lib/core/network/streaming_client.dart`
A `StreamingClient` that wraps Dio with `ResponseType.stream`, exposes `Stream<Result<String>>` for a request, and handles SSE `data:` framing. Testable via a mock Dio adapter.

### 2. `lib/core/network/sse_parser.dart`
A small parser that turns a raw byte/string stream into SSE events (`data:`, `event:`, `id:`), yielding clean payload strings. Unit-tested against sample SSE payloads.

### 3. `lib/features/chat/` (reference feature)
A minimal streaming chat feature: a `ChatRepository` that calls `StreamingClient`, a `ChatBloc` that accumulates streamed tokens into a message, and a page/widget that renders them. Mirrors the `features/home/` structure.

### 4. `docs/implemented.md` (update)
Document the streaming pattern: when to use it, how to wire `StreamingClient`, how to parse SSE, and how it composes with connectivity and `Result<T>`.

## Testing

- Unit tests for `sse_parser.dart` against sample SSE payloads (multi-line `data:`, `[DONE]` sentinel, comments, event types).
- Unit tests for `StreamingClient` using a mock Dio adapter that emits a chunked stream.
- A `ChatBloc` test that verifies tokens accumulate into a complete message.
- `flutter test` passes.

## Acceptance Criteria

- [ ] A `StreamingClient` exists in `lib/core/network/` and exposes a `Stream<Result<String>>`.
- [ ] SSE framing is parsed in one place (`sse_parser.dart`) and unit-tested.
- [ ] A `features/chat/` reference feature streams tokens into a UI.
- [ ] The pattern is documented in `docs/implemented.md`.
- [ ] `flutter test` passes.

## Critique Results

<!-- Populated by /do-plan-critique (war room). Leave empty until critique is run. -->
| Severity | Critic | Finding | Addressed By | Implementation Note |
|----------|--------|---------|--------------|---------------------|
| BLOCKER | Risk & Robustness | The plan reuses the globally-configured Dio, which sets `receiveTimeout: 30s` and `Accept: application/json` on every request. A long-lived SSE stream where tokens are >30s apart will be aborted by `receiveTimeout`, and `Accept: application/json` tells SSE backends to buffer the full body (many stream only when the client asks for `text/event-stream`), silently turning streaming into a delayed single blob. | Approach #1/#2; `streaming_client.dart` | Every streaming request must build `Options(receiveTimeout: null, headers: {'Accept': 'text/event-stream'}, responseType: ResponseType.stream)` and merge over the base options so the global 30s receiveTimeout and `Accept: application/json` are overridden. Test that a mock adapter delivering tokens >30s apart does not throw `DioException.receiveTimeout`. |
| CONCERN | Risk & Robustness / History & Consistency | The `Stream<Result<String>>` emission contract is unspecified: whether `loading` is emitted once as a leading item, and whether a mid-stream disconnect/network error or a `[DONE]` terminator surfaces as `Result.failure(...)`, a stream `onError`, or normal `onDone`. The mock-adapter test will encode whatever the implementer guesses. | Approach #2; Testing; `sse_parser.dart` | Pin the contract: emit `[DONE]` as a distinct terminal state (not a token); wrap the Dio stream in a `StreamController` and convert a mid-stream `DioException` into `Result.failure(err.message, err)` (or `addError`) consistently. Add a ChatBloc test asserting an aborted mid-stream does not leave a half-accumulated message marked success. |
| CONCERN | Risk & Robustness | The ChatBloc accumulates streamed tokens with no maximum-input bound, and the plan has no rate-limit / max-token guard or `CancelToken` wiring for user-initiated stop; a runaway/long stream grows memory unboundedly and a user interrupting generation has no defined abort path. | Files to Create #3; `features/chat/` | Guard in the accumulation reducer: `if (message.length >= kMaxMessageChars) { cancelToken?.cancel(); }`. Expose `stream(path, {CancelToken? cancelToken})` on `StreamingClient` and call `cancel()` on the UI stop action; assert in the ChatBloc test that accumulation halts and the stream closes at the bound. |
| CONCERN | History & Consistency | The plan says `StreamingClient` "wraps Dio" directly, but `dio_client.dart` already owns the configured Dio (baseUrl, timeouts, AuthInterceptor, logging). A StreamingClient building its own Dio silently drops base config and the auth header, so streamed chat/LLM requests would fail auth or hit the wrong baseUrl. | Files to Create #1; Approach #2 | Inject the existing `DioClient` (which exposes `Dio get dio`) into `StreamingClient` and call `ResponseType.stream` on that instance, rather than constructing a fresh Dio; keep mock-Dio-adapter unit tests. |
| CONCERN | Scope & Value | Decision #4 claims streaming "composes with connectivity" and "falls back to a cached or error result", but provides no mechanism, file, or test. A token stream cannot be replayed by the Hive-backed OfflineQueue, so "cached" is undefined; no caching/connectivity source appears in Files to Create or Acceptance Criteria. | Approach #4; Testing | Either scope the fallback concretely (when offline, emit `Result.failure` immediately and skip queueing — mirroring `connectivity_aware_mixin.dart`), with a test feeding an offline connectivity state into `StreamingClient`; or downgrade decision #4 to "connectivity is read via the existing `ConnectivityService` for the initial state" and defer any caching. `lib/core/connectivity/connectivity_service.dart` / `connectivity_state.dart` already exist. |
| CONCERN | Scope & Value / History & Consistency | The plan has Goal/Approach/Files-to-Create/Testing/Acceptance but no ordered task breakdown, so buildability and per-step verifiability are left to whoever runs do-build; dependencies between files are only implicit. | Files to Create | Add a short ordered task list (1. `sse_parser.dart` + unit tests, 2. `StreamingClient` + mock-adapter tests, 3. `features/chat/` repository/bloc/page, 4. `docs/implemented.md`, 5. full `flutter test`) so each step is independently buildable and verifiable. The parser must land first and be unit-tested before `StreamingClient`. |
| NIT | Scope & Value | The acceptance criteria are mostly structural ("exists", "unit-tested", "documented"), with only one behavioral item framed as plumbing rather than an observable user outcome. | Acceptance Criteria | Add a user-meaningful acceptance, e.g., "in `features/chat/`, text appears incrementally before the full response completes," giving the ChatBloc test a concrete assertion (tokens emitted across multiple stream events appear in the rendered message before completion). |
| NIT | History & Consistency | The plan frontmatter has `status: Ready` but no `revision_applied`/`revision_applied_at` marker, unlike sibling Ready plans (`docs_auth_reconcile.md`, `android_scaffolding.md`). | Frontmatter | Add `revision_applied: true` and `revision_applied_at` (timestamped) to the frontmatter when finalized, matching sibling plans' exact field names/format. |
