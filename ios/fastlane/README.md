fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

### load_asc_api_key

```sh
[bundle exec] fastlane load_asc_api_key
```

Load ASC API Key information to use in subsequent lanes

### prepare_signing

```sh
[bundle exec] fastlane prepare_signing
```

Check certs and profiles

### build_release

```sh
[bundle exec] fastlane build_release
```

Build the app for release

### upload_release

```sh
[bundle exec] fastlane upload_release
```

Upload to TestFlight / ASC

### build_v6

```sh
[bundle exec] fastlane build_v6
```

Build app v6

### build_family

```sh
[bundle exec] fastlane build_family
```

Build family

### build_upload_testflight_v6

```sh
[bundle exec] fastlane build_upload_testflight_v6
```

Build and upload to TestFlight v6

### build_upload_testflight_family

```sh
[bundle exec] fastlane build_upload_testflight_family
```

Build and upload to TestFlight family

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
