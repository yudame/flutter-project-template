# Overview

## What Is This?

This is a **documentation-only Flutter architecture template** for small teams (2-5 people) using AI-assisted development. It contains no source code — only architecture guides and setup documentation to copy into new Flutter projects.

## Who Is It For?

- Small development teams building Flutter mobile apps
- Teams using AI-assisted development workflows (Claude Code, Cursor, etc.)
- Projects that need a solid architectural foundation without reinventing the wheel

## Architecture at a Glance

- **Two-layer architecture** — Presentation + Data only (no separate domain layer)
- **Freezed everywhere** — Models, BLoC events, and states use sealed unions
- **Connectivity-first** — Explicit handling of online/poor/offline states
- **BLoC pattern** — State management with `flutter_bloc` + `hydrated_bloc`
- **get_it** — Service locator for dependency injection

## How to Use

1. **Read the docs** — Start with [Implemented Features](implemented.md) to understand what's already been built and tested
2. **Review the architecture** — Check [Architecture](architecture.md) for guidelines and planned features
3. **Copy patterns** — Bring the patterns, conventions, and code examples into your own Flutter project
4. **Reference setup** — Use the [Setup Reference](setup_reference.md) for critical implementation details and common pitfalls

## Documentation Structure

| Document | What It Covers |
|----------|---------------|
| [Implemented Features](implemented.md) | Already-built patterns: connectivity, network, offline queue, BLoC |
| [Architecture](architecture.md) | Reference guidelines + planned features (database layer) |
| [Setup Reference](setup_reference.md) | Critical implementation details, auth flows, retry logic, pitfalls |

## Project Structure (When Implemented)

```
lib/
├── core/
│   ├── theme/              # App theme
│   ├── routes/             # go_router setup
│   ├── network/            # DioClient, offline queue
│   ├── database/           # DatabaseService, StorageService
│   ├── connectivity/       # ConnectivityBloc & service
│   ├── di/                 # get_it configuration
│   └── utils/              # Logger, constants, extensions
├── features/
│   └── [feature_name]/
│       ├── data/
│       │   ├── models/     # Freezed models
│       │   ├── repositories/
│       │   └── datasources/
│       └── presentation/
│           ├── bloc/       # BLoC + Freezed events/states
│           ├── pages/
│           └── widgets/
└── shared/
```
