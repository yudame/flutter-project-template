---
status: Ready
type: chore
appetite: Small
owner: orchestrator
created: 2026-08-19
tracking: https://github.com/yudame/flutter-project-template/issues/15
last_comment_id:
revision_applied: true
revision_applied_at: 2026-08-19T06:20:20Z
---

# Reconcile Template Docs and Optional-Auth Story

## Problem

The template's documentation contradicts its actual state, and the auth layer's optionality is undocumented — both of which mislead anyone (human or AI) using the template.

**Current behavior:**
- `CLAUDE.md` says "This is a documentation-only Flutter architecture template... It contains no source code," but the repo has full source under `lib/` (core, features, shared, l10n, main.dart).
- The auth layer (`lib/core/auth/`, 335 lines across 4 files) is present but not wired into DI — `injection.dart` has the auth registrations commented out under an "Auth (uncomment after implementing AuthRepository)" block. This optionality is not documented.
- No documented pattern for Android's `network_security_config.xml` (needed by LAN apps that talk to a local host over cleartext HTTP, which Android blocks by default on API 28+).

**Desired outcome:**
- Docs match reality: CLAUDE.md describes the actual source-bearing template.
- Auth is documented as optional (how to enable or strip it).
- A documented network-security-config pattern for LAN apps.

## Freshness Check

**Baseline commit:** `e896a34b8e7f80106c72f3db06eec2b77d5332dc`
**Issue filed at:** 2026-08-19T05:14:27Z
**Disposition:** Unchanged

**File:line references re-verified:**
- `CLAUDE.md` (Repository Overview) — claims "documentation-only... contains no source code" — still holds; the repo has full source under `lib/`.
- `lib/core/di/injection.dart` — auth registrations (`AuthRepository`, `AuthBloc`) are commented out under an "Auth (uncomment after implementing AuthRepository)" block — still holds; `AuthTokenManager` is wired, but the auth BLoC/repository are not.
- `lib/core/auth/` — 4 files present (auth_repository.dart, auth_event.dart, auth_bloc.dart, auth_state.dart), 335 lines total — still holds.
- No `network_security_config.xml` anywhere in the repo — still holds; `android/app/src/main/` contains only `java/io/flutter/plugins/GeneratedPluginRegistrant.java` (no manifest, no `res/`).

**Cited sibling issues/PRs re-checked:**
- #3 (Add Authentication Flow Documentation & Examples) — CLOSED. Its plan (`docs/plans/authentication.md`) added auth docs and examples. This issue #15 is a follow-up reconciliation of the *current* state, not a re-do of #3.

**Commits on main since issue was filed (touching referenced files):**
- None. `git log --since=2026-08-19T05:14:27Z` returns nothing; HEAD predates the issue.

**Active plans in `docs/plans/` overlapping this area:** `authentication.md` (issue #3) — closed, and its scope (adding auth docs/examples) is distinct from this reconciliation. No active overlap.

**Notes:** The android platform scaffolding in this template is intentionally minimal (no `AndroidManifest.xml`, no `res/`). The network-security-config deliverable is therefore a *documented pattern* (a doc section with the XML snippet and wiring instructions), not a committed file — matching the issue's "Add a documented ... pattern" wording.

## Prior Art

- **[Issue #3 / `docs/plans/authentication.md`]**: Add Authentication Flow Documentation & Examples — CLOSED. Added auth documentation, an abstract `AuthRepository` interface, `AuthBloc`, and route-guard patterns. Relevant as the origin of the current auth layer; this issue reconciles the docs with the layer's actual (optional, unwired) state rather than re-adding auth content.

## Research

**Queries used:**
- "Android network_security_config.xml cleartext traffic local LAN host API 28 domain-config"

**Key findings:**
- Android 9 (API 28+) disables cleartext HTTP by default; LAN apps hitting a local host over HTTP get "CLEARTEXT communication to [ip] not permitted by network security policy." — [Android Developers: Network security configuration](https://developer.android.com/privacy-and-security/security-config)
- `domain-config` requires explicit hostnames/IPs — you **cannot** wildcard or CIDR-match a LAN subnet (e.g. `192.168.1.x`). For LAN apps with unpredictable host IPs, the practical pattern is `base-config cleartextTrafficPermitted="true"` (simplest) or per-domain `domain-config` for known hosts. — [Stack Overflow: cleartext only on local LAN](https://stackoverflow.com/questions/70338305/android-network-security-config-to-choose-cleartext-communication-only-on-local)
- `base-config` and `domain-config` can coexist; setting `android:networkSecurityConfig` makes `android:usesCleartextTraffic` ignored; the most-specific matching `domain-config` wins. — [Android Developers: Cleartext communications](https://developer.android.com/privacy-and-security/risks/cleartext-communications)
- API 37+ includes an implicit localhost cleartext config; API 28–36 must configure localhost explicitly. — [OWASP MASTG: Android Network Security Configuration](https://mas.owasp.org/MASTG/knowledge/android/MASVS-NETWORK/MASTG-KNOW-0014/)

These findings shape the documented pattern: recommend `base-config cleartextTrafficPermitted="true"` for LAN apps (with a note on the security tradeoff and the per-domain alternative for known hosts), plus the manifest `android:networkSecurityConfig` wiring.

## Spike Results

No spikes needed — this is a Small-appetite, documentation-only chore with no verifiable code assumptions. All claims were confirmed directly in the Freshness Check.

## Data Flow

Not applicable — this is a documentation-only change with no runtime data flow.

## Why Previous Fixes Failed

Not applicable — no prior failed fixes for this specific reconciliation. Issue #3 (auth docs) succeeded; this is a distinct follow-up.

## Architectural Impact

- **New dependencies**: None — documentation only.
- **Interface changes**: None — no code changes.
- **Coupling**: None — docs only.
- **Data ownership**: None.
- **Reversibility**: Trivial — doc edits are easily reverted.

## Appetite

**Size:** Small

**Team:** Solo dev

**Interactions:**
- PM check-ins: 0
- Review rounds: 1

## Prerequisites

No prerequisites — this work has no external dependencies and requires no environment setup.

## Solution

### Key Elements

- **CLAUDE.md rewrite**: Replace the "documentation-only... no source code" framing with an accurate description of the source-bearing template (structure under `lib/`, the implemented patterns, and the docs that accompany them).
- **Auth optionality documentation**: Document the auth layer as optional — how to enable it (uncomment the DI block in `injection.dart`, implement `AuthRepository`) and how to strip it (remove `lib/core/auth/` and the `AuthTokenManager` wiring).
- **network-security-config pattern**: Add a documented pattern (XML snippet + manifest wiring + security tradeoff) for LAN apps that talk to a local host over cleartext HTTP.

### Flow

**CLAUDE.md** → accurate template description → **Auth section** → enable-or-strip guidance → **Network section** → network-security-config pattern for LAN apps → **Docs match reality**

### Technical Approach

- **CLAUDE.md**: Rewrite the Repository Overview and Project Structure sections to describe the actual source tree (`lib/core/`, `lib/features/`, `lib/shared/`, `lib/l10n/`, `main.dart`). Keep the architecture principles (two-layer, freezed, connectivity-first, BLoC, get_it) — they already match the code. Change "When Implemented" framing to "Implemented."
- **Auth optionality**: Add a dedicated section in `CLAUDE.md` (primary, resolved location) with a pointer from `docs/architecture.md`, covering: (a) what ships (the 4 auth files, `AuthTokenManager` wired into DI), (b) how to enable (uncomment the `AuthRepository`/`AuthBloc` block in `injection.dart`, implement the concrete repository), (c) how to strip — the full removal closure (verified against the actual source so following it verbatim compiles):
  - Delete `lib/core/auth/` (auth_bloc.dart, auth_event.dart, auth_repository.dart, auth_state.dart) and `test/core/auth/` (auth_bloc_test.dart imports `lib/core/auth/*`, so it must go with the layer).
  - Remove the `AuthTokenManager` registration from `injection.dart` (lines 14, 66-68) and its injections into `DioClient` (line 80) and `RequestExecutor` (line 100).
  - `lib/core/network/dio_client.dart`: remove the `AuthTokenManager` field/constructor param (lines 11, 21), the `AuthInterceptor` instantiation in `_dio.interceptors.addAll(...)` (lines 41-45), and BOTH imports — `auth_interceptor.dart` (line 5) and `auth_token_manager.dart` (line 6).
  - `lib/core/network/request_executor.dart`: remove the `AuthTokenManager` field/constructor param (lines 9, 13-14), the `_getValidAuthToken()` method (lines 56-61), the three `final token = await _getValidAuthToken();` call sites and their `Options(headers: {'Authorization': 'Bearer $token'})` (lines 29-34, 38-44, 48-53), and the `auth_token_manager.dart` import (line 3).
  - Delete `lib/core/network/auth_interceptor.dart` (the third `AuthTokenManager` consumer, instantiated at `dio_client.dart:41`).
  - Delete `lib/core/network/auth_token_manager.dart` (orphaned dead code once the consumers above drop it).
  - `lib/core/network/auth_exception.dart`: NOT cleanly orphaned — `offline_queue.dart` still imports it (line 9) and catches `on AuthException` (line 88). A full strip must also drop that catch from `offline_queue.dart` (and its import), otherwise `auth_exception.dart` must remain. Note this explicitly so the strip does not leave a dangling reference.
- **network-security-config pattern**: Add a documented pattern in `docs/setup_reference.md` (resolved location) with the `base-config cleartextTrafficPermitted="true"` snippet for LAN apps, the manifest `android:networkSecurityConfig` wiring, the per-domain alternative for known hosts, and the security tradeoff note. Do NOT commit the file into the template's minimal android scaffolding — document the pattern for teams to apply.

## Failure Path Test Strategy

### Exception Handling Coverage
No exception handlers in scope — this is a documentation-only change with no code paths.

### Empty/Invalid Input Handling
Not applicable — no functions or inputs are introduced.

### Error State Rendering
Not applicable — no user-visible output is introduced.

## Test Impact

No existing tests affected — this is a documentation-only change; no test files reference the docs being rewritten, and no code or interfaces change.

## Rabbit Holes

- **Committing the actual `network_security_config.xml` into the template's android scaffolding**: the template's android dir is intentionally minimal (no manifest, no `res/`). The deliverable is a documented pattern, not a committed file. Adding real android files expands scope beyond the issue.
- **Rewriting auth code or wiring auth into DI**: out of scope — this issue documents optionality, it does not change the auth layer.
- **Over-engineering the network-security-config doc with CIDR/wildcard tricks**: Android does not support subnet wildcards in `domain-config`; document the supported `base-config`/`domain-config` approaches and stop.

## Risks

### Risk 1: Docs drift again after this reconciliation
**Impact:** The template's docs and code fall out of sync again, re-creating the original problem.
**Mitigation:** The rewrite anchors CLAUDE.md to the actual `lib/` tree and the auth DI state, making future drift visible on review.

### Risk 2: The network-security-config pattern is applied too broadly (global cleartext)
**Impact:** Teams copy the `base-config cleartextTrafficPermitted="true"` pattern into production apps that don't need cleartext, weakening security.
**Mitigation:** Document the security tradeoff explicitly and present the per-domain `domain-config` alternative for known hosts, so the global pattern is a deliberate choice for LAN apps only.

## Race Conditions

No race conditions identified — this is a synchronous, single-threaded documentation change with no concurrent state.

## No-Gos (Out of Scope)

- [SEPARATE-SLUG] Wiring auth into DI or otherwise changing the auth layer's code — this issue documents optionality only; any code change to enable auth is a separate implementation task.
- [SEPARATE-SLUG] Committing a real `network_security_config.xml` (and supporting android manifest/res files) into the template — the template's android scaffolding is intentionally minimal; the deliverable is a documented pattern.

## Update System

No update system changes required — this is a documentation-only change with no deploy/update propagation.

## Agent Integration

No agent integration required — this is a docs-only change; no tool/MCP surface or entry point is affected.

## Documentation

### Feature Documentation
- [ ] Rewrite `CLAUDE.md` to describe the actual source-bearing template (Repository Overview, Project Structure).
- [ ] Add auth-optionality section (enable or strip) to `CLAUDE.md`, with a pointer from `docs/architecture.md`.
- [ ] Add network-security-config pattern for LAN apps to `docs/setup_reference.md`.

### External Documentation Site
No Sphinx/Read-the-Docs/MkDocs site in this repo — skip.

### Inline Documentation
None — no code changes.

## Success Criteria

- [ ] `CLAUDE.md` accurately describes the template as containing source code (no "documentation-only" / "no source code" framing).
- [ ] Auth optionality is documented: how to enable (uncomment DI block, implement `AuthRepository`) and how to strip (remove `lib/core/auth/` and `AuthTokenManager` wiring).
- [ ] A network-security-config pattern for LAN apps is documented (XML snippet + manifest wiring + security tradeoff).

## Team Orchestration

When this plan is executed, the lead agent orchestrates work using Task tools. The lead NEVER builds directly — they deploy team members and coordinate.

### Team Members

- **Builder (docs)**
  - Name: docs-builder
  - Role: Rewrite CLAUDE.md, add auth-optionality and network-security-config documentation
  - Agent Type: documentarian
  - Resume: true

- **Validator (docs)**
  - Name: docs-validator
  - Role: Verify docs match the actual source tree and all success criteria are met
  - Agent Type: validator
  - Resume: true

### Available Agent Types

**Tier 1 — Core (default choices):**
- `builder` - General implementation (default for most work)
- `validator` - Read-only verification (no Write/Edit tools)
- `code-reviewer` - Code review, security checks
- `test-engineer` - Test implementation and strategy
- `documentarian` - Documentation updates
- `plan-maker` - Planning subagent
- `frontend-tester` - Browser testing

## Step by Step Tasks

### 1. Rewrite CLAUDE.md
- **Task ID**: build-claude-md
- **Depends On**: none
- **Validates**: CLAUDE.md content (grep for "documentation-only" / "no source code" returns no matches)
- **Informed By**: Freshness Check (confirmed source tree under `lib/`)
- **Assigned To**: docs-builder
- **Agent Type**: documentarian
- **Parallel**: true
- Rewrite the Repository Overview to describe the actual source-bearing template.
- Update the Project Structure section to reflect the implemented `lib/` tree (drop "When Implemented" framing).

### 2. Document auth optionality
- **Task ID**: build-auth-docs
- **Depends On**: none
- **Validates**: auth-optionality section present in CLAUDE.md and/or docs/architecture.md
- **Informed By**: Freshness Check (auth present but commented out of `injection.dart`)
- **Assigned To**: docs-builder
- **Agent Type**: documentarian
- **Parallel**: true
- Document how to enable auth (uncomment the `AuthRepository`/`AuthBloc` block in `injection.dart`, implement the concrete repository).
- Document how to strip auth — the full removal closure (verified against the actual source so following it verbatim compiles): delete `lib/core/auth/` and `test/core/auth/` (auth_bloc_test.dart imports `lib/core/auth/*`); remove the `AuthTokenManager` registration and injections from `injection.dart` (registration lines 14/66-68; `DioClient` line 80; `RequestExecutor` line 100); in `lib/core/network/dio_client.dart` remove the `AuthTokenManager` field/param (11, 21), the `AuthInterceptor` instantiation in `_dio.interceptors.addAll(...)` (41-45), and both the `auth_interceptor.dart` (5) and `auth_token_manager.dart` (6) imports; in `lib/core/network/request_executor.dart` remove the `AuthTokenManager` field/param (9, 13-14), the `_getValidAuthToken()` method (56-61), the three `final token = await _getValidAuthToken();` call sites and their `Options(headers: {'Authorization': 'Bearer $token'})` (29-34, 38-44, 48-53), and the `auth_token_manager.dart` import (3); delete `lib/core/network/auth_interceptor.dart` and the now-orphaned `lib/core/network/auth_token_manager.dart`; and note `lib/core/network/auth_exception.dart` is still referenced by `offline_queue.dart` (import line 9, `on AuthException` catch line 88) — the strip must drop that catch/import too or the file must remain.

### 3. Document network-security-config pattern
- **Task ID**: build-netsec-docs
- **Depends On**: none
- **Validates**: network-security-config pattern section present in docs
- **Informed By**: Research (base-config vs domain-config, no subnet wildcards, API 28+ default block)
- **Assigned To**: docs-builder
- **Agent Type**: documentarian
- **Parallel**: true
- Add the `base-config cleartextTrafficPermitted="true"` pattern for LAN apps with manifest `android:networkSecurityConfig` wiring.
- Include the per-domain `domain-config` alternative for known hosts and the security tradeoff note.

### 4. Validate docs
- **Task ID**: validate-docs
- **Depends On**: build-claude-md, build-auth-docs, build-netsec-docs
- **Assigned To**: docs-validator
- **Agent Type**: validator
- **Parallel**: false
- Verify CLAUDE.md no longer claims "documentation-only" / "no source code".
- Verify auth optionality (enable + strip) is documented.
- Verify the network-security-config pattern is documented.
- Report pass/fail against all three success criteria.

## Verification

| Check | Command | Expected |
|-------|---------|----------|
| CLAUDE.md no longer claims documentation-only | `grep -n "documentation-only\|no source code" CLAUDE.md` | exit code 1 |
| Auth optionality documented | `grep -rn "AuthRepository\|AuthBloc" CLAUDE.md docs/architecture.md` | exit code 0 |
| Network-security-config pattern documented | `grep -rn "network_security_config\|cleartextTrafficPermitted" docs/` | exit code 0 |

## Critique Results

<!-- Populated by /do-plan-critique (war room). Leave empty until critique is run. -->
| Severity | Critic | Finding | Addressed By | Implementation Note |
|----------|--------|---------|--------------|---------------------|
| High | do-plan-critique | Strip-auth guidance omits the third AuthTokenManager consumer `lib/core/network/auth_interceptor.dart` (instantiated at `dio_client.dart:41`); following the strip verbatim leaves a dangling AuthInterceptor and won't compile. | Task 2 (`build-auth-docs`) + Technical Approach (Auth optionality) | Embed the full removal closure: delete `lib/core/auth/`; remove `AuthTokenManager` registration from `injection.dart` (and injection into `DioClient`/`RequestExecutor`); in `dio_client.dart` remove the `AuthTokenManager` field/param and the `AuthInterceptor` instantiation in `_dio.interceptors.addAll(...)` plus its `auth_interceptor.dart` import; remove `AuthTokenManager` from `request_executor.dart`; delete `lib/core/network/auth_interceptor.dart`. |
| Medium | do-plan-critique | Success Criterion 4 ("Documentation updated via /do-docs") maps to no task and no verification row, while Task 4 `validate-docs` reports "against all three success criteria" — count mismatch. | Success Criteria section | Drop SC4; the remaining three criteria align 1:1 with Task 4's three verification bullets and the Verification table's three rows. |
| Nit | do-plan-critique | Freshness-check citation path `android/app/src/main/GeneratedPluginRegistrant.java` is incomplete. | Freshness Check | Include the `java/io/flutter/plugins/` subtree: `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java`. |
| Block (round 2) | do-plan-critique | Strip-auth closure incomplete for `lib/core/network/request_executor.dart` — won't compile. It only removes the AuthTokenManager field/param, but the file also has `_getValidAuthToken()` calling `_authManager.isTokenExpired()/.refreshAccessToken()/.getAccessToken()` (lines 56-61) and all three `_execute*` methods call it and set `Options(headers: {'Authorization': 'Bearer $token'})` (29-34, 38-44, 48-53), plus the `auth_token_manager.dart` import (line 3). | Technical Approach (Auth optionality) + Task 2 (`build-auth-docs`) | Embed: delete `_getValidAuthToken()`, the three `final token = await _getValidAuthToken();` call sites and their `Options(headers: {...})`, and the `auth_token_manager.dart` import. |
| Concern (round 2) | do-plan-critique | Closure omits the auth test file and leaves `lib/core/network/auth_token_manager.dart` / `auth_exception.dart` as orphaned dead code. `test/core/auth/auth_bloc_test.dart` imports `lib/core/auth/*` (4 imports), so it breaks when `lib/core/auth/` is deleted. | Technical Approach (Auth optionality) + Task 2 (`build-auth-docs`) | Embed: strip also removes `test/core/auth/` (and its auth-related expectations) and deletes the now-orphaned `lib/core/network/auth_token_manager.dart`. Corrected against source: both files are in `lib/core/network/`, not `lib/core/auth/`, and `auth_exception.dart` is still referenced by `offline_queue.dart` (import line 9, `on AuthException` catch line 88) — so the strip must drop that catch/import too, or the file remains. |
| Nit (round 2) | do-plan-critique | `lib/core/network/dio_client.dart`'s `auth_token_manager.dart` import (line 6) is unlisted in the closure. | Technical Approach (Auth optionality) + Task 2 (`build-auth-docs`) | Add removing the `auth_token_manager.dart` import (line 6) to the dio_client.dart strip steps (alongside the existing `auth_interceptor.dart` import removal). |

---
