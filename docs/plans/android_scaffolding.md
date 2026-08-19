---
status: Planning
type: bug
appetite: Small
owner: yudame
created: 2026-08-19
tracking: https://github.com/yudame/flutter-project-template/issues/13
last_comment_id:
---

# Make the template a runnable Android project (missing Gradle scaffolding)

## Problem

The template's README (line 5) claims it is "a complete, runnable Flutter project template," but the `android/` platform directory is missing the entire Gradle build scaffolding, so the project cannot build for Android.

**Current behavior:**
- `android/` contains only 2 tracked files: `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` and `android/key.properties.example`.
- Missing: `AndroidManifest.xml`, `build.gradle`/`build.gradle.kts`, `settings.gradle`, `gradle-wrapper.properties`, `gradlew`, and the `app/src/main/res/` resources.
- `.gitignore` does not exclude these (it only ignores build artifacts like `/android/app/debug`, `local.properties`, `key.properties`), and no script generates them.
- `make build-android` (`flutter build apk --release`) would fail.

**Desired outcome:**
- A standard, runnable Flutter Android project under `android/` such that `flutter build apk --debug` succeeds from a clean checkout.

## Freshness Check

**Baseline commit:** `e896a34` (`git rev-parse HEAD` at plan time)
**Issue filed at:** 2026-08-19T05:13:59Z
**Disposition:** Unchanged

**File:line references re-verified:**
- `android/` (2 tracked files) — confirmed via `git ls-files android/` — still holds.
- No manifest/gradle/wrapper anywhere — confirmed via `git ls-files | grep -iE 'AndroidManifest|\.gradle|gradlew|gradle-wrapper'` (no matches) — still holds.
- `.gitignore` does not exclude the missing files — confirmed by reading `.gitignore` (only ignores build artifacts, `local.properties`, `key.properties`) — still holds.
- `pubspec.yaml` `name: flutter_template` — confirmed — still holds.
- `docs/setup_reference.md:154-161` documents `minSdk = 23` for `flutter_secure_storage` — confirmed — still holds.

**Cited sibling issues/PRs re-checked:**
- None cited.

**Commits on main since issue was filed (touching referenced files):**
- None — `git log --since="2026-08-19T05:13:59Z"` is empty. HEAD is `e896a34` ("docs: add ## Running section to README").

**Active plans in `docs/plans/` overlapping this area:** none — `docs/plans/scaffolding.md` covers project/feature scaffolding scripts and Claude commands, not the Android Gradle platform scaffolding. No overlap.

**Notes:** The issue's Solution Sketch says to "Confirm the toolchain matches the repo's documented pins (AGP 9.0.1, Gradle 9.1.0, JDK 17, Android SDK 36)." These pins are **not documented anywhere in the repo** (grep for AGP/Gradle 9.1.0/JDK 17/SDK 36 across `*.md`, `*.yaml`, `Makefile` found nothing). They appear to be the default toolchain `flutter create` emits for the installed Flutter 3.44.8 stable. This is flagged as an Open Question; the plan does not hard-pin a toolchain and instead accepts whatever `flutter create` generates.

## Prior Art

No prior issues or merged PRs found related to this work (`gh issue list --state closed --search "android gradle build"` and `gh pr list --state merged --search "android gradle"` both returned empty). This is the first attempt to add Android build scaffolding.

## Research

No relevant external findings — proceeding with codebase context and training data. The approach (`flutter create --platforms=android .`) is the canonical Flutter mechanism for regenerating platform scaffolding and is well-established; no external research needed.

## Spike Results

No spikes needed — Small appetite, the approach is a single well-understood command (`flutter create --platforms=android .`) with a deterministic verification (`flutter build apk --debug`). No verifiable assumptions require time-boxed investigation.

## Data Flow

Not applicable — this is a build-scaffolding fix, not a data-flow change. The change adds build configuration files; no runtime data moves through them.

## Why Previous Fixes Failed

No prior fixes exist (see Prior Art). Section omitted.

## Architectural Impact

- **New dependencies**: None at runtime. Adds the standard Android Gradle build toolchain (AGP, Gradle wrapper, Kotlin DSL) as build-time dependencies pinned by `flutter create`.
- **Interface changes**: None — no Dart/API surface changes.
- **Coupling**: Adds the standard Flutter↔Android platform coupling that was previously absent.
- **Data ownership**: No change.
- **Reversibility**: Fully reversible — the added files are standard generated scaffolding; deleting `android/` restores the prior state.

## Appetite

**Size:** Small

**Team:** Solo dev

**Interactions:**
- PM check-ins: 0
- Review rounds: 1

## Prerequisites

| Requirement | Check Command | Purpose |
|-------------|---------------|---------|
| Flutter SDK on PATH | `flutter --version` | `flutter create` and `flutter build apk` require the Flutter toolchain |
| Android toolchain configured | `flutter doctor` (Android toolchain section) | `flutter build apk` requires Android SDK + licenses |

## Solution

### Key Elements

- **Regenerate Android scaffolding**: Run `flutter create --platforms=android .` in the repo root to generate the missing `android/` Gradle scaffolding (manifest, gradle files, wrapper, resources). `flutter create` on an existing project adds missing platform files without overwriting existing user files, so the 2 tracked files are preserved.
- **Re-apply template customizations**: Set `minSdk = 23` in the generated `android/app/build.gradle.kts` (required by `flutter_secure_storage` 9.x, per `docs/setup_reference.md`), and confirm the generated release-signing block is consistent with the existing `android/key.properties.example`.
- **Verify build**: Run `flutter build apk --debug` and confirm it succeeds.

### Flow

Repo root → `flutter create --platforms=android .` → generated `android/` scaffolding → edit `build.gradle.kts` (minSdk 23) → `flutter build apk --debug` → success

### Technical Approach

- Run `flutter create --platforms=android .` from the repo root. This regenerates only the Android platform scaffolding and does not touch other platform dirs or `pubspec.yaml`.
- The generated Android applicationId/package derives from the pubspec `name: flutter_template`, satisfying the acceptance criterion that the package name matches `pubspec.yaml`.
- Edit `android/app/build.gradle.kts`: change `minSdk = flutter.minSdkVersion` to `minSdk = 23` (per `docs/setup_reference.md:154-161`).
- Verify the generated `build.gradle.kts` release-signing block reads `key.properties` in the same format as `android/key.properties.example` (storePassword/keyPassword/keyAlias/storeFile). If the generated block's format diverges, update `key.properties.example` to match so the documented example stays accurate.
- Verify `flutter build apk --debug` succeeds. Debug builds do not require signing config, so this is the correct gate per the acceptance criteria. (Release builds via `make build-android` require a real `key.properties` + keystore, which is out of scope — see No-Gos.)

## Failure Path Test Strategy

### Exception Handling Coverage
No exception handlers in scope — this change adds build configuration files, not runtime code.

### Empty/Invalid Input Handling
Not applicable — no functions or input processing are added.

### Error State Rendering
Not applicable — no user-visible output is added. The relevant failure path is a build failure, which surfaces as a non-zero exit from `flutter build apk --debug` and is caught by the Verification gate.

## Test Impact

No existing tests affected — this change adds build scaffolding and does not modify any Dart code, tests, or runtime behavior. The verification is the build itself (`flutter build apk --debug`), not the unit/integration test suite.

## Rabbit Holes

- **Hand-tuning the generated Gradle files**: Do not manually author `build.gradle.kts`, `settings.gradle`, or the wrapper. Let `flutter create` generate them so they match the installed Flutter version's expected format. Only the `minSdk` line is edited.
- **Chasing the AGP/Gradle/JDK/SDK toolchain pins**: The issue cites pins (AGP 9.0.1, Gradle 9.1.0, JDK 17, SDK 36) that are not documented in the repo. Do not spend time reconciling against undocumented pins — accept the toolchain `flutter create` emits for Flutter 3.44.8.
- **Regenerating other platforms**: `--platforms=android` limits scope to Android. Do not regenerate iOS or web scaffolding.

## Risks

### Risk 1: `flutter create` overwrites or conflicts with the existing 2 tracked files
**Impact:** The existing `GeneratedPluginRegistrant.java` or `key.properties.example` could be modified or lost.
**Mitigation:** `flutter create` on an existing project preserves user files and only adds missing ones. Verify with `git status` after generation that the 2 existing files are unchanged (or that `GeneratedPluginRegistrant.java` was regenerated identically, which is expected and harmless).

### Risk 2: Generated release-signing block diverges from `key.properties.example`
**Impact:** The documented signing example becomes stale, misleading future users.
**Mitigation:** Compare the generated `build.gradle.kts` signing block against `key.properties.example` and update the example if the format differs.

### Risk 3: `flutter build apk --debug` fails due to local Android toolchain state
**Impact:** The build gate fails for environment reasons unrelated to the scaffolding.
**Mitigation:** Confirm `flutter doctor` shows a healthy Android toolchain (Prerequisites) before building. The acceptance criterion is that the build succeeds from a clean checkout on a properly configured machine.

## Race Conditions

No race conditions identified — all operations are synchronous and single-threaded (a single `flutter create` invocation followed by a single `flutter build`).

## No-Gos (Out of Scope)

- [SEPARATE-SLUG] Release signing setup (creating a real `key.properties` + keystore and verifying `make build-android` / `flutter build apk --release`) — out of scope because it requires a real keystore and secrets that must not be committed. The acceptance criteria only require the debug build. Filed as a follow-up concern in Open Questions rather than a separate issue at this time.
- [EXTERNAL] Installing/verifying the Android SDK, JDK, or licenses on a developer machine — a human/environment action, not a repo change.

## Update System

No update system changes required — this is a build-scaffolding fix internal to the template repo. The `/update` skill and any downstream propagation are unaffected.

## Agent Integration

No agent integration required — this change adds build configuration only and exposes no new tool/MCP surface.

## Documentation

### Feature Documentation
No new feature docs required — this is a bug fix restoring standard platform scaffolding.

### External Documentation Site
No documentation site changes required.

### Inline Documentation
- [ ] If the generated release-signing block format diverges from `android/key.properties.example`, update the example file to match (see Risk 2).

## Success Criteria

- [ ] `flutter build apk --debug` succeeds from a clean checkout.
- [ ] `android/` contains the standard manifest, gradle files, wrapper, and resources.
- [ ] The Android applicationId/package matches the template's `pubspec.yaml` name (`flutter_template`).
- [ ] `minSdk = 23` is set in `android/app/build.gradle.kts` (for `flutter_secure_storage`).
- [ ] The existing 2 tracked files (`GeneratedPluginRegistrant.java`, `key.properties.example`) are preserved.
- [ ] `git status` shows only the intended new `android/` files added.

## Team Orchestration

When this plan is executed, the lead agent orchestrates work using Task tools. The lead NEVER builds directly - they deploy team members and coordinate.

### Team Members

- **Builder (android-scaffold)**
  - Name: android-builder
  - Role: Regenerate Android scaffolding, apply minSdk customization, verify build
  - Agent Type: builder
  - Resume: true

- **Validator (android-verify)**
  - Name: android-validator
  - Role: Verify build succeeds and acceptance criteria met
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

### 1. Regenerate Android scaffolding
- **Task ID**: build-android-scaffold
- **Depends On**: none
- **Validates**: `flutter build apk --debug` succeeds
- **Informed By**: none
- **Assigned To**: android-builder
- **Agent Type**: builder
- **Parallel**: true
- Run `flutter create --platforms=android .` from the repo root.
- Confirm via `git status` that the 2 existing tracked files are preserved and only new `android/` files were added.

### 2. Apply template customizations
- **Task ID**: build-android-customize
- **Depends On**: build-android-scaffold
- **Validates**: `minSdk = 23` present in `android/app/build.gradle.kts`
- **Informed By**: none
- **Assigned To**: android-builder
- **Agent Type**: builder
- **Parallel**: false
- Edit `android/app/build.gradle.kts`: set `minSdk = 23`.
- Compare the generated release-signing block against `android/key.properties.example`; update the example if the format diverges.

### 3. Verify debug build
- **Task ID**: validate-android-build
- **Depends On**: build-android-customize
- **Assigned To**: android-validator
- **Agent Type**: validator
- **Parallel**: false
- Run `flutter build apk --debug` and confirm exit code 0.
- Confirm `android/` contains manifest, gradle files, wrapper, and resources.
- Confirm the applicationId/package matches `flutter_template`.
- Report pass/fail status.

### 4. Final Validation
- **Task ID**: validate-all
- **Depends On**: validate-android-build
- **Assigned To**: android-validator
- **Agent Type**: validator
- **Parallel**: false
- Run all verification checks (see Verification).
- Verify all success criteria met.
- Generate final report.

## Verification

| Check | Command | Expected |
|-------|---------|----------|
| Debug APK builds | `flutter build apk --debug` | exit code 0 |
| Manifest present | `test -f android/app/src/main/AndroidManifest.xml` | exit code 0 |
| Gradle wrapper present | `test -f android/gradlew` | exit code 0 |
| minSdk set to 23 | `grep -n 'minSdk = 23' android/app/build.gradle.kts` | exit code 0 |
| Package matches pubspec | `grep -rn 'applicationId' android/app/build.gradle.kts` | output contains `flutter_template` |
| Existing files preserved | `git status --porcelain android/` | output does not contain `D ` (no deletions) |

## Critique Results

<!-- Populated by /do-plan-critique (war room). Leave empty until critique is run. -->
| Severity | Critic | Finding | Addressed By | Implementation Note |
|----------|--------|---------|--------------|---------------------|
| CONCERN | Risk & Robustness / History & Consistency | Success criterion 6 ("git status shows only the intended new `android/` files added") conflicts with Risk 1 / Task 1, which accept that `GeneratedPluginRegistrant.java` is regenerated; if regenerated content differs it reports as `M` (modified) and fails criterion 6 while the Verification gate (greps only for absence of `D `) still passes — a self-contradictory gate. | Success Criteria 6; Task 1; Verification table | Reword criterion 6 to: "git status shows only new `android/` files added and `key.properties.example` unchanged; `GeneratedPluginRegistrant.java` may appear as `M` (content-identical or content-drifted regeneration is acceptable) — only a deletion of `key.properties.example` or an unexpected new top-level file fails the gate." Align the Verification row's Expected column to the same rule. |
| CONCERN | Scope & Value | The issue's headline symptom is "`make build-android` (`flutter build apk --release`) would fail," but every success criterion and the verification gate exercise only `flutter build apk --debug`; after this fix `make build-android` can still fail (release signing needs a real `key.properties` + keystore). The headline path is never verified and only deferred to Open Question 2. | Open Questions 2; No-Gos | Convert Open Question 2 into a concrete follow-up issue (owner: yudame) titled "Release signing: key.properties + keystore for make build-android", linked to #13, and add a line in No-Gos / Success Criteria: "Release build (`make build-android`) is NOT verified by this fix; it depends on the release-signing follow-up." Record the follow-up issue number in the completion note. |
| CONCERN | History & Consistency / Risk & Robustness | Open Question 1 (toolchain pins: accept vs. hard-pin AGP 9.0.1 / Gradle 9.1.0 / JDK 17 / SDK 36) is framed as open, but the act of running `flutter create` and committing the generated Gradle files inherently hard-pins whatever the author's Flutter 3.44.8 emits — the first task decides the question implicitly, risking a later mismatch on a different-machine developer's build. | Open Questions 1; Rabbit Holes; Task 3 | Resolve the question as decision (a) in the plan text, and in Task 3 / validate report capture and record the concrete generated versions (AGP via `android/settings.gradle.kts`, Gradle wrapper via `android/gradle/wrapper/gradle-wrapper.properties`, compileSdk/minSdk) in the completion note, so the committed toolchain is explicit rather than emergent. |
| NIT | Scope & Value | Verification row "Package matches pubspec" greps `applicationId` for `flutter_template`, but `flutter create` sets the Android applicationId to `com.example.flutter_template` (com.example prefix) — the criterion is a substring match, not the literal package name the wording implies. | Verification table; Success Criteria | Reword the criterion to "the generated Android applicationId/package derives from the pubspec name (contains `flutter_template`)", and confirm that prefix is acceptable (or specify an explicit applicationId override). |

---

## Open Questions

1. **Toolchain pins source**: The issue's Solution Sketch says to "Confirm the toolchain matches the repo's documented pins (AGP 9.0.1, Gradle 9.1.0, JDK 17, Android SDK 36)," but these pins are not documented anywhere in the repo. Should the plan (a) accept whatever `flutter create` generates for Flutter 3.44.8 (current plan), or (b) hard-pin these specific versions in the generated Gradle files? If (b), where do these pins come from?
2. **Release signing follow-up**: Should a separate issue be filed to set up release signing (real `key.properties` + keystore) and verify `make build-android` (`flutter build apk --release`)? The acceptance criteria only require the debug build, so this is currently deferred.
