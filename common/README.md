# six-common

The common module used in both iOS and Android apps of Blokada 6.

It contains the new Home screen with the analytics.

## Module layout

- Feature-first: code lives under `lib/src/features` (including tiered features like `plus`), variant overrides under `lib/src/app_variants/{v6,family}`, and shared UI under `lib/src/shared`.
- Platform/Pigeon bindings are generated into `lib/src/platform/**/channel.pg.dart`; `lib/platform/**` is intentionally removed.
- Public surface is re-exported from `lib/common.dart` (Modules, core Act types, navigation, and app shell). Keep `lib/src/**` internal for package consumers.

See the [root README](../README.md) for community, issues, and contributing.
