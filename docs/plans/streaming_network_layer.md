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
