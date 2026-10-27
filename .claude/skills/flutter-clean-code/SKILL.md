---
name: flutter-clean-code
description: Use when implementing or refactoring Flutter features, screens, widgets, models, or services in the mobile/ app — any Dart code change in this repo's Flutter project.
---

# Flutter Clean Code

## 1. Inspect First

- Read the root CLAUDE.md (if present) and inspect the existing Flutter project in `mobile/`.
- Check `pubspec.yaml`, `analysis_options.yaml`, routing, state management, networking, and existing feature conventions.
- Reuse the existing architecture unless a concrete problem requires change.
- Do not recreate project files or replace dependencies without justification.

## 2. File and Folder Organization

Use feature-first organization when appropriate:

```
mobile/lib/
  main.dart
  app/          # application setup, routing, and theme
  core/         # shared infrastructure: config, networking, error handling, constants, utils
  shared/       # reusable widgets shared across features
  features/
    auth/
    wallet/
    vouchers/
    transactions/
```

Feature folder internals (only as the feature grows — do not create empty scaffolding):

```
features/vouchers/
  data/         # models, API clients, repositories
  presentation/ # screens, widgets
```

## 3. Code Rules

- Keep files under 300 lines where practical; split when exceeded.
- Clear naming: `VoucherListScreen`, `VoucherRepository`, `voucher_provider.dart`.
- Every screen/list that loads data must handle loading, error, and empty states.
- No commented-out code, no dead code, no speculative abstractions.

## 4. Validate Before Reporting Done

Run from `mobile/`:

```bash
flutter analyze
flutter test
```

Both must pass. Report failures honestly with output.

## 5. Boundaries

- Do not commit or push — that is the git-workflow skill's job.
- Do not touch `service/` (backend) unless the task explicitly asks.
