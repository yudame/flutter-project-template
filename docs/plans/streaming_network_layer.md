---
status: Ready
type: feature
appetite: Medium
owner: yudame
created: 2026-08-19
tracking: https://github.com/yudame/flutter-project-template/issues/14
last_comment_id:
revision_applied: true
revision_applied_at: 2026-08-20T09:54:35Z
---

# Plan: Streaming Network Layer (SSE) for AI/Chat Features

## Goal

Add a streaming network layer to the template's network core so AI/chat features can render tokens as they arrive, instead of waiting for a complete response. Provide a documented, reusable pattern with a worked example.

## Current State

- **Existing infrastructure**:
  - `lib/core/network/dio_client.dart` — `DioClient` owns a configured `Dio` (`_baseUrl`, 30s connect/receive/send timeouts, `Content-Type: application/json` + `Accept: application/json` headers, `AuthInterceptor`, debug logging). Exposes `Dio get dio`.
  - `lib/core/network/offline_queue.dart` — Hive-backed request queue with retry; only replays request/response pairs (params map), **cannot** replay a token stream.
  - `lib/core/network/request_executor.dart` — executes queued requests.
  - `lib/core/utils/result.dart` — `Result<T>` with `success / failure / loading` variants plus `dataOrNull / isFailure / isLoading` helpers.
  - `lib/core/connectivity/` — `ConnectivityService` (`isOnline / isPoor / isOffline`), `ConnectivityState` (`online / poor / offline`), `ConnectivityBloc`.
  - `lib/core/utils/connectivity_aware_mixin.dart` — `ConnectivityAwareBlocMixin` used by BLoCs to react to connectivity changes.
- **Missing**:
  - No streaming/SSE support anywhere in the network core.
  - No pattern for consuming a token-by-token response stream.
  - No worked example of a streaming feature.

## Freshness Check

Verified against `main` at revision pass time (2026-08-19):

- `lib/core/network/dio_client.dart` still configures `receiveTimeout: 30s` and `Accept: application/json` on the shared Dio instance (confirmed — the BLOCKER is real and live). No commits have landed on this file since issue #14 was filed; the file:line claims in the critique hold unchanged.
- `lib/core/network/offline_queue.dart` still stores request/response params only — no stream-replay capability. `OfflineQueue` remains incompatible with streaming.
- `lib/core/connectivity/` (`connectivity_service.dart`, `connectivity_state.dart`) exists as cited; `connectivity_aware_mixin.dart` at `lib/core/utils/connectivity_aware_mixin.dart` is the concrete fallback pattern to mirror.
- `lib/features/home/` structure (repository → bloc → page/widgets) confirmed as the template to mirror for `features/chat/`.
- **Disposition: Unchanged.** Issue claims and all critique file:line references still hold against current `main`. Baseline commit: current branch head `session/sdlc-local-14` (plan is committed to the SDLC local branch per pipeline convention, not `main`, while the plan-revising lock is held).

## Research

No external findings needed beyond Dio's documented behavior, which the critique already surfaced and which we encode directly:

- In Dio 5.x, `compose()` merges per-request options with `receiveTimeout ?? baseOpt.receiveTimeout`, so `receiveTimeout: null` silently falls back to the base 30s and a sparse stream (>30s between tokens) still throws `DioException.receiveTimeout`. Only `receiveTimeout: Duration.zero` works: `response_stream_handler.dart` short-circuits the receive-timeout timer when `receiveTimeout <= Duration.zero` (`if (receiveTimeout <= Duration.zero) return;`), so a long-lived stream with sparse tokens survives. This is the verified BLOCKER mechanism we encode. (`dio` 5.11.0 source)
- `ResponseType.stream` on a Dio `Options` returns the raw bytes; the caller decodes. Streaming is available on the existing Dio instance — no new HTTP dependency is required.
- SSE backends commonly buffer unless the client sends `Accept: text/event-stream`; and `text/event-stream` must override the template's default `Accept: application/json` per request.

These three facts drive the BLOCKER resolution (Implementation Note B-1).

## Approach

Add a streaming capability to the network core that composes with the existing `Result<T>` and connectivity-first patterns, without disturbing the request/response path.

**Key decisions**:
1. **Dio's `ResponseType.stream` is the base** — no new HTTP client dependency. The existing, already-configured `DioClient` instance is reused (it exposes `Dio get dio`); a fresh Dio is **not** constructed, so baseUrl, `AuthInterceptor`, and logging are preserved.
2. **A `StreamingClient` abstraction** — a thin wrapper over the injected `DioClient` that returns a `Stream<Result<String>>` of decoded tokens for a request. Keeps the network layer testable and swappable via a mock Dio adapter.
3. **SSE framing handled in one place** — `sse_parser.dart` parses raw stream chunks into SSE events (`data:`, `event:`, `id:`) and yields clean payload strings. This is the part most chat/AI backends emit.
4. **Per-request options override the global defaults** — every streaming request builds `Options(receiveTimeout: Duration.zero, headers: {'Accept': 'text/event-stream'}, responseType: ResponseType.stream)` and merges over the base options, so the global 30s receiveTimeout and `Accept: application/json` are overridden. This is the BLOCKER fix.
5. **Connectivity is read at stream start, not queued** — a token stream cannot be replayed by the Hive-backed `OfflineQueue`. When offline (or poor), `StreamingClient` emits `Result.failure` immediately and does **not** enqueue; a `CancelToken` is cancelled so no orphaned stream lingers. Streaming does not attempt cached replay — that is explicitly deferred.
6. **Worked example** — a `features/chat/` reference feature (mirroring `features/home/`) that streams tokens into a UI, so teams have a copy-paste starting point. This is the first consumer: the kids' chat app in `counsell-home/apps/chat`.

**Out of scope**: the LLM proxy backend, auth, and any provider-specific chat logic. This is the transport layer only.

## Files to Create

### 1. `lib/core/network/sse_parser.dart`
A small parser that turns a raw `Stream<String>`/`Stream<List<int>>` into SSE events, yielding clean payload strings. Handles: multi-line `data:` lines, `[DONE]` sentinel, comments (`:`), `event:`/`id:` fields, and event dispatch. Pure and fully unit-testable.

### 2. `lib/core/network/streaming_client.dart`
A `StreamingClient` that takes the existing `DioClient` (not a fresh Dio), exposes `Stream<Result<String>> stream(String path, {CancelToken? cancelToken, Map<String, dynamic>? queryParameters})`, and uses `sse_parser` to emit tokens. Handles the per-request options override and the connectivity gate. Testable via a mock Dio adapter.

### 3. `lib/features/chat/` (reference feature)
A minimal streaming chat feature mirroring `features/home/`:
- `data/repositories/chat_repository.dart` — calls `StreamingClient`.
- `presentation/bloc/chat_bloc.dart`, `chat_event.dart`, `chat_state.dart` — accumulates streamed tokens into a message, bounded by a max-length guard, with a stop action wired to `CancelToken`.
- `presentation/pages/chat_page.dart`, `presentation/widgets/chat_stream_view.dart` — renders tokens incrementally as they arrive.

### 4. `docs/implemented.md` (update)
Document the streaming pattern: when to use it, how to wire `StreamingClient`, how to parse SSE, the emission contract, and how it composes with connectivity and `Result<T>`.

## Data Flow

1. User sends a message in `features/chat/` → `ChatBloc` emits a `ChatEvent.send` → calls `ChatRepository.stream(message)`.
2. `ChatRepository` calls `StreamingClient.stream('/chat', queryParameters: {'q': message}, cancelToken: _cancelToken)`.
3. `StreamingClient` checks `ConnectivityService.isOffline` (or `isPoor`): if offline/poor, synchronously emits `Result.failure(...)` and does **not** enqueue; otherwise it issues the Dio request with per-request streaming options and returns `ResponseType.stream`.
4. Dio yields the raw chunked body; `sse_parser` frames it into SSE events and yields token strings (`data:` payloads), surfacing `[DONE]` as a distinct terminal marker.
5. `StreamingClient` maps each token to `Result.success(token)` and pushes it onto the returned `Stream<Result<String>>`.
6. `ChatBloc` subscribes and accumulates tokens into the current message, emitting an updated `ChatState` after each; a max-length guard cancels the stream at the bound; a user `stop` event cancels the `CancelToken`.
7. `ChatStreamView` renders the accumulating message text, so text appears incrementally before the full response completes.

## Implementation Notes

Embedded from the critique (all findings are resolved here and reflected in the Steps below):

- **B-1 (BLOCKER: timeout + Accept).** Every streaming request MUST build `Options(receiveTimeout: Duration.zero, headers: {'Accept': 'text/event-stream'}, responseType: ResponseType.stream)` and merge it over the base options so the global 30s `receiveTimeout` and `Accept: application/json` are overridden. Test: a mock adapter delivering tokens >30s apart does **not** throw `DioException.receiveTimeout`; and the request's `Accept` header equals `text/event-stream`.
- **C-1 (emission contract).** Pin the contract in `streaming_client.dart` doc-comment and enforce with tests: emit `Result.loading()` once as the leading item; then one `Result.success(token)` per token; surface `[DONE]` as a distinct terminal event that ends the stream normally (it is **not** emitted as a token); a mid-stream `DioException`/disconnect is converted into a terminal `Result.failure(message, err)` (via `StreamController.addError` or a terminal `add`) — never left hanging. ChatBloc test: an aborted mid-stream does **not** leave a half-accumulated message marked success.
- **C-2 (max-token bound + CancelToken).** Accumulate with a guard in the reducer: `if (message.length >= kMaxMessageChars) { cancelToken?.cancel(); }`. `StreamingClient.stream` exposes `{CancelToken? cancelToken}`; the UI stop action calls `cancel()`. ChatBloc test asserts accumulation halts and the stream closes at the bound.
- **C-3 (reuse existing DioClient).** `StreamingClient` receives the existing `DioClient` (its `dio` getter) and calls `ResponseType.stream` on that instance — NOT a fresh Dio — preserving baseUrl, `AuthInterceptor`, and logging. Mock-Dio-adapter unit tests verify the configured Dio is used.
- **C-4 (connectivity fallback concrete + bounded).** When offline or poor, `StreamingClient` emits `Result.failure` immediately and skips queueing (mirroring `connectivity_aware_mixin.dart`'s offline handling). No cached replay of streams (OfflineQueue cannot replay a token stream) — deferred. Test feeds an offline/poor `ConnectivityState` into `StreamingClient` and asserts the failure result and that no request is enqueued.
- **C-5 (ordered tasks).** Ordered Step-by-Step Tasks below; `sse_parser.dart` + unit tests land first (Step 1), before `StreamingClient` (Step 2), so each step is independently buildable and verifiable.
- **N-1 (user-visible acceptance).** Add: "in `features/chat/`, text appears incrementally before the full response completes." ChatBloc test asserts tokens emitted across multiple stream events appear in the rendered message before completion.
- **N-2 (revision marker).** Frontmatter now carries `revision_applied: true` and `revision_applied_at` (this revision pass), matching sibling plans (`docs_auth_reconcile.md`, `android_scaffolding.md`).

## Risks / Verification / No-Go

**Risks:**
- **R-1 — Silent buffering / timeout** (the BLOCKER). If the per-request options override is missed or merged incorrectly, SSE backends buffer the full body and the 30s global receiveTimeout aborts sparse streams. Mitigation: mandatory B-1 test (tokens >30s apart, `Accept: text/event-stream` asserted on the request) runs before any other streaming test.
- **R-2 — Emission-contract ambiguity.** Without a pinned contract, mock-adapter tests encode whatever the implementer guesses, and consumers mishandle `[DONE]`/mid-stream errors. Mitigation: contract documented in `streaming_client.dart` (C-1) and enforced by the ChatBloc abort test.
- **R-3 — Auth/header regression.** Building a fresh Dio would drop `AuthInterceptor` and baseUrl. Mitigation: `StreamingClient` injects the existing `DioClient` (C-3) and tests run through a mock of that configured Dio.
- **R-4 — Unbounded memory / no abort.** A runaway stream grows memory and a user can't stop. Mitigation: max-length guard + `CancelToken` wiring (C-2), both unit-tested.
- **R-5 — Connectivity fallback undefined.** Streaming that silently queues or hangs offline. Mitigation: concrete offline/poor failure path, no queueing (C-4), tested.
- **R-6 — Dependency drift.** This plan adds no new HTTP dependency (reuses Dio streaming), so dependency drift risk is low; the only new dependency surface is the freezed codegen already used in the template.

**Verification:**
- `flutter test` passes; specifically:
  - `sse_parser` unit tests (multi-line `data:`, `[DONE]`, comments, `event:`/`id:`).
  - `StreamingClient` mock-adapter tests: `Accept: text/event-stream` + `receiveTimeout: Duration.zero` override (B-1); tokens >30s apart don't throw (B-1); offline/poor → immediate `Result.failure`, nothing enqueued (C-4); loading-leading + terminal-failure contract (C-1).
  - `ChatBloc` tests: tokens accumulate across events into the rendered message **before** completion (N-1); mid-stream abort does not mark a half-accumulated message success (C-1); max-length bound halts accumulation and closes the stream (C-2).
- `flutter analyze` passes (no new lint errors).
- Manual smoke: `flutter run -d chrome` on `features/chat/` shows text appearing incrementally.

**No-Go:**
- Do **not** build a fresh Dio inside `StreamingClient` (drops baseUrl/auth/logging).
- Do **not** attempt cached/queued replay of a token stream via `OfflineQueue` (it cannot replay a stream); offline is a terminal `Result.failure`, never a queue.
- Do **not** introduce a new HTTP/SSE package dependency — Dio's `ResponseType.stream` covers this; adding one would be scope creep.
- Do **not** mark a message success if the stream aborted mid-token.
- If `flutter test` on `main` is red at build start for reasons unrelated to this plan, do not treat that as a regression of this work — baseline first.

## Step by Step Tasks

1. **`sse_parser.dart` + unit tests.** Implement the SSE parser (multi-line `data:`, `[DONE]`, comments, `event:`/`id:`). Add `test/core/network/sse_parser_test.dart` covering these cases. Verify: parser tests green.
2. **`StreamingClient` + mock-adapter tests.** Inject existing `DioClient`; implement `Stream<Result<String>> stream(...)` with per-request options override (B-1), connectivity gate (C-4), and the pinned emission contract (C-1). Add `test/core/network/streaming_client_test.dart` covering B-1 (timeout/Accept), C-1 (contract), C-4 (offline), and reuse-of-DioClient (C-3). Verify: streaming tests green.
3. **`features/chat/` reference feature.** Add `ChatRepository`, `ChatBloc`/event/state (accumulation with max-length guard C-2 + `CancelToken` stop), `ChatPage`, and `ChatStreamView`. Mirror `features/home/` structure and `ConnectivityAwareBlocMixin`. Verify: `flutter analyze` clean.
4. **ChatBloc tests.** Add `test/features/chat/chat_bloc_test.dart` asserting incremental render before completion (N-1), mid-stream abort safety (C-1), and max-length halting (C-2). Verify: bloc tests green.
5. **`docs/implemented.md` update.** Document the streaming pattern: when to use, wiring, SSE parsing, emission contract, connectivity composition. Verify: doc read-through.
6. **Full suite + manual smoke.** Run `flutter test` and `flutter analyze`; manual `flutter run -d chrome` on `features/chat/` confirming incremental token render. Verify: all green; smoke shows incremental text.

## Testing

- Unit tests for `sse_parser.dart` against sample SSE payloads (multi-line `data:`, `[DONE]` sentinel, comments, event types).
- Unit tests for `StreamingClient` using a mock Dio adapter: request options override (`Accept: text/event-stream`, `receiveTimeout: Duration.zero`, `ResponseType.stream`), tokens >30s apart don't abort, offline/poor → immediate `Result.failure` with nothing enqueued, and the emission contract (loading-first, terminal failure on mid-stream error, `[DONE]` not emitted as a token).
- A `ChatBloc` test suite: tokens accumulate across events into the rendered message before completion; an aborted mid-stream does not leave a half-accumulated message marked success; accumulation halts and the stream closes at `kMaxMessageChars`; stop action cancels the `CancelToken`.
- `flutter test` passes; `flutter analyze` passes.

## Acceptance Criteria

- [ ] A `StreamingClient` exists in `lib/core/network/` and exposes a `Stream<Result<String>>`, constructed from the existing `DioClient` (reusing baseUrl/auth/logging — no fresh Dio).
- [ ] Every streaming request overrides the global `receiveTimeout: 30s` and `Accept: application/json` with `receiveTimeout: Duration.zero` and `Accept: text/event-stream` (BLOCKER resolved); a mock adapter delivering tokens >30s apart does not throw.
- [ ] SSE framing is parsed in one place (`sse_parser.dart`) and unit-tested.
- [ ] A `features/chat/` reference feature streams tokens into a UI, bounded by a max-length guard with a working `CancelToken` stop action.
- [ ] **User-visible (incremental render):** in `features/chat/`, text appears incrementally before the full response completes (tokens emitted across multiple stream events show in the rendered message before completion).
- [ ] Offline/poor connectivity yields an immediate `Result.failure` with nothing enqueued (no cached/queued replay of a token stream).
- [ ] The pattern (incl. emission contract) is documented in `docs/implemented.md`.
- [ ] `flutter test` passes; `flutter analyze` passes.

## Open Questions

None — the critique's BLOCKER/concerns/nits were all resolvable from codebase context (this is a transport-layer plan with no human-judgment call). Any provider-specific chat logic remains out of scope per the Goal.

## Critique Results

Resolved in this revision — see **Implementation Notes** for the full resolution of each finding and the **Step by Step Tasks** for where each lands.

| Severity | Critic | Finding | Addressed By | Implementation Note |
|----------|--------|---------|--------------|---------------------|
| BLOCKER | Risk & Robustness | Global Dio `receiveTimeout: 30s` + `Accept: application/json` aborts/forces buffering of long SSE streams. | Approach #4; `streaming_client.dart`; Acceptance; Test B-1 | **B-1** — per-request `Options(receiveTimeout: Duration.zero, Accept: text/event-stream, ResponseType.stream)` merged over base options; test delivers tokens >30s apart without `receiveTimeout`. |
| CONCERN | Risk & Robustness / History & Consistency | `Stream<Result<String>>` emission contract unspecified (loading-first? mid-stream error? `[DONE]`?). | Approach #2; `streaming_client.dart`; C-1 test | **C-1** — loading-first, terminal failure on mid-stream error, `[DONE]` not emitted as a token; ChatBloc abort test. |
| CONCERN | Risk & Robustness | No max-token bound / `CancelToken` abort; runaway stream grows memory unbounded. | Files #3; `features/chat/` | **C-2** — `kMaxMessageChars` guard cancels; `CancelToken` exposed + stop action; bloc halting test. |
| CONCERN | History & Consistency | `StreamingClient` must reuse existing `DioClient` (baseUrl/auth), not a fresh Dio. | Files #1; Approach #2 | **C-3** — inject `DioClient`, use its `dio`; mock-adapter test proves reuse. |
| CONCERN | Scope & Value | Connectivity fallback undefined; OfflineQueue can't replay a stream. | Approach #5; C-4 test | **C-4** — offline/poor → immediate `Result.failure`, nothing enqueued; test feeds offline state. Deferred: no cached replay. |
| CONCERN | Scope & Value / History & Consistency | No ordered task breakdown. | Step by Step Tasks | **C-5** — parser first, then StreamingClient, feature, docs, full suite. |
| NIT | Scope & Value | Acceptance criteria all-technical; no user-visible incremental-render criterion. | Acceptance (user-visible) | **N-1** — "text appears incrementally before the full response completes." |
| NIT | History & Consistency | Missing `revision_applied`/`revision_applied_at` marker. | Frontmatter | **N-2** — added, matching sibling plans. |
