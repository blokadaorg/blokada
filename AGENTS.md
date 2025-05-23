# Agent Notes

This repository contains the Android and iOS projects for Blokada 6. The main directories are:

- `common/` – Flutter module shared between Android and iOS.
- `android/` – Gradle project building the Android apps.
- `ios/` – Xcode project for iOS.
- `scripts/` – helper scripts.
- `deps/` and other archives – tools bundled with the repository.

The top level `Makefile` orchestrates building both platforms. Flutter related
work is handled in `common/Makefile`.

Makefiles are tab indented, so be careful when editing them.

## Tests

`make test` runs the Flutter tests located in `common/`. These require the
Flutter dependencies to be available locally.
