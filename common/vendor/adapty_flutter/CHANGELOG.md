# 4.0.4

- [Android] `restorePurchases()` no longer fails with `noPurchasesToRestore` when there is nothing to restore. It now completes successfully with the current `AdaptyProfile` — check the access level status in the returned profile instead of catching an error. `AdaptyErrorCode.noPurchasesToRestore` is deprecated on Android.
- [Android] Restore now uses currently owned purchases only. The native SDK moved to Google Play Billing Library 8, which removed the purchase history API. Purchases made through Adapty are unaffected, but subscriptions that expired before Adapty was integrated can no longer be imported from the device.
- Fixed text elements in paywalls and flows losing their color and background when the builder sends them under the `text_color` and `text_background` keys. The old `color` and `background` keys are still read, so views built before the change keep rendering as they did. Fixed on both platforms.
- [iOS] Native iOS SDK dependency pinned to `4.0.3`.
- [Android] Native Android SDK dependency bumped to `4.0.2`.

# 4.0.3

- `AdaptyUI.createFlowView` and `AdaptyUIFlowPlatformView` now accept a `locale` — the localization the flow view is rendered with. Since 4.0.0 a flow is localized when its view is built, and there was no way to choose that localization from Dart. Requires the native iOS 4.0.2 and Android 4.0.1 releases.

  Without a `locale` the view is rendered in `en`, falling back to the flow's default localization when the flow has no `en`. Asking for a localization the flow does not have falls back to the flow default as well, without an error. Strings missing from the chosen localization are filled in from the default one.
- `AdaptyUIFlowView` now reports the `locale` the view was actually built with, so you can tell which localization was applied. It is `null` when paired with an older native SDK.
- The `locale` argument of `getFlow` and `getFlowForDefaultAudience` has had no effect on flows since 4.0.0. It is now marked deprecated and logs a warning instead of being silently dropped; pass the locale to `createFlowView` or `AdaptyUIFlowPlatformView` instead.
- Fixed custom gradient assets losing all of their colors when the `LinearGradient` had no explicit `stops`. Affected both platforms.

# 4.0.2

- [iOS] Fixed a crash (`freed pointer was not the last allocation`) when a placement was served from cache, on Xcode 26.3 / Swift 6.2.4 release builds.
- [iOS] Kids Mode: `adapty_flutter_kids` no longer imports `AppTrackingTransparency` — the native ATT surface is now fully compiled out under the kids trait.
- [iOS] Native iOS SDK dependency pinned to `4.0.1`.

# 4.0.1

- [iOS] Pin the native iOS SDK dependency to exactly `4.0.0` (was `from: "4.0.0"`). The Flutter bridge targets this exact native version, so the plugin no longer resolves to newer 4.x native releases it wasn't built against.

# 4.0.0

> ⚠️ Major release with breaking API changes. The "paywall" concept is generalized into "flow"; most `Paywall`/`paywall` UI symbols are renamed to `Flow`/`flow`, and previously deprecated aliases are removed.

### ⚠️ Breaking Changes

- **Paywall → Flow rename.** `AdaptyPaywall` is split into `AdaptyFlow` (+ `AdaptyFlowPaywall`); `AdaptyUIPaywallView` → `AdaptyUIFlowView`; `Adapty().getPaywall(...)` → `getFlow(...)` and `getPaywallForDefaultAudience(...)` → `getFlowForDefaultAudience(...)`; `AdaptyUI().createPaywallView(...)` → `createFlowView(...)`; `logShowPaywall(...)` → `logShowFlow(...)`.
- **Events observer renamed.** `AdaptyUIPaywallsEventsObserver` → `AdaptyUIFlowsEventsObserver` (`setPaywallsEventsObserver` → `setFlowsEventsObserver`); all `paywallViewDid*` callbacks → `flowViewDid*`. The separate rendering-failure callback is folded into `flowViewDidReceiveError`.
- `AdaptyPaywallViewConfiguration` is no longer exposed; the view configuration is now opaque.
- Removed APIs that were deprecated back in 3.x: `Adapty.setFallbackPaywalls()` (use `setFallback()`), `AdaptyConfigurationBuilder.withIdfaCollectionDisabled()` (use `withAppleIdfaCollectionDisabled()`), `AdaptyFlow.placementId` / `AdaptyFlow.revision` (use `placement.id` / `placement.revision`), `AdaptyPurchaseResultSuccess.jwsTransaction` (use `appleJwsTransaction`), and `AdaptyUIFlowView.paywallVariationId` (use `variationId`).
- Dismissing a flow or onboarding view now releases it from memory by default; a dismissed view can no longer be re-presented — create a new one instead.
- The Android system back button no longer dismisses a flow by default. Handle `AndroidSystemBackAction` in your events observer if you want it to close the flow.
- [iOS] Minimum deployment target raised to iOS 15.
- [iOS] Requires Xcode 26 or newer (the native iOS SDK uses Swift tools 6.2).
- [iOS] CocoaPods support dropped; the iOS native SDK is distributed via Swift Package Manager only.
- Minimum Flutter raised to 3.32.0 (Dart 3.8.0).
- [iOS] Because the iOS SDK is SwiftPM-only, apps on Flutter 3.32–3.43 must enable Swift Package Manager once with `flutter config --enable-swift-package-manager`; Flutter 3.44+ enables it by default.

### New

- `AdaptyUISystemRequestsHandler` — handle flow system requests (OS permission prompts and App Store review requests) triggered by flow actions. Register via `AdaptyUI().setSystemRequestsHandler(...)`.
- `AdaptyUIObserverModeResolver` — drive purchases and restores initiated from flows while running in Observer Mode. Register via `AdaptyUI().setObserverModeResolver(...)`.
- `flowViewDidReceiveAnalyticEvent` — receive customer-facing analytic events emitted by a flow.
- `Adapty.openWebPaywall` and `Adapty.createWebPaywallUrl` now accept an `AdaptyFlowPaywall` in addition to an `AdaptyPaywallProduct`.
- `setFlowsEventsObserver` / `setOnboardingsEventsObserver` now accept `null` to detach a previously set observer, so the SDK no longer retains it (useful for cleanup).

### Deprecated

- The Onboarding Feature is deprecated; migrate to Flows. `AdaptyOnboarding`, `AdaptyUIOnboardingView`, `AdaptyUIOnboardingPlatformView`, `AdaptyUIOnboardingsEventsObserver`, the onboarding state / input / analytics models, and the related `Adapty`/`AdaptyUI` methods (`getOnboarding`, `getOnboardingForDefaultAudience`, `create`/`present`/`dismissOnboardingView`, `register`/`unregister`/`setOnboardingsEventsObserver`) are now annotated `@Deprecated`.

# 3.17.2

- [iOS] Updated native iOS SDK to 3.17.3, fixing a crash when a placement was served from cache on recent Xcode / Swift Release builds.

# 3.17.1

- [Android] Updated native Android SDK to 3.17.2.
- [Android] Fixed AGP 9 and Built-In Kotlin support.

# 3.17.0

### New

- `OpenUrlAction` now carries an `openIn` parameter (`AdaptyWebPresentation`) indicating where the URL should be opened — external browser or in-app browser.
- [iOS] Added Swift Package Manager support. The plugin now ships a `Package.swift` alongside the CocoaPods podspec, so apps with SwiftPM enabled build it via SwiftPM while CocoaPods keeps working unchanged.
- `AdaptyProfile` now exposes `appliedAttributionSources` (`List<AdaptyAttributionSource>`), reporting which attribution sources have been applied to the profile (e.g. `appleSearchAds`).

### ⚠️ Breaking Changes

- `OpenUrlAction` constructor signature changed: it now requires a second positional argument `openIn` of type `AdaptyWebPresentation`. The action instances are normally produced by the SDK from native events, so most integrations are unaffected; direct constructions need an explicit `openIn`.

### Native

- [iOS] Updated native iOS SDK to 3.17.2.
- [Android] Updated native Android SDK to 3.17.1.

# 3.15.5

- [iOS] Updated native iOS SDK to 3.15.7.

# 3.15.4

- [iOS] Fixed backend errors handling.

# 3.15.3

- [iOS] Fixed a bug where the `placementId` value was incorrect for `AdaptyUIPaywallView`.

# 3.15.2

- Onboardings: External links now work correctly. You can configure which browser is used by passing the `externalUrlsPresentation` parameter to the `.createOnboardingView` method or to the `AdaptyUIOnboardingPlatformView` constructor (`.inAppBrowser` by default).
- [iOS] Now it is possible to prevent a new profile from being created after restoring a device from an iCloud backup by using the `.withAppleClearDataOnBackup()` setting in `AdaptyConfiguration`.

# 3.15.1

- [Android] Custom tags, timers, and assets now work correctly with `AdaptyUIPaywallPlatformView`

# 3.15.0

### 🎉 Meet the Adapty Flutter SDK 3.15.0!

### New

- Support for Local Access Levels, allowing the SDK to verify purchases directly with the store even when Adapty servers are unreachable. [Read More.](http://adapty.io/docs/local-access-levels)
- Support for StoreKit Testing in Xcode. [Read More.](http://adapty.io/docs/local-sk-files)
- Added `accessLevelId` property for `AdaptyPaywallProduct`
- [Android] Added support for Web Paywall: use `.createWebPaywallUrl()` or `.openWebPaywall()` to navigate users to an external webpage with alternative checkout options. [Read More.](https://docs.adapty.io/docs/web-paywall)
- [Android] AdaptyUI: Added support for Web Paywall button. [Read More.](https://adapty.io/docs/web-paywall#step-2a-add-a-web-purchase-button)
- The `.openWebPaywall()` method now supports a new `openIn` parameter. Available options: `externalBrowser` (default) and `inAppBrowser`.

### Fixes

- [iOS] Fixed a bug that prevented purchases with a promo offer from being made when `customerUserId` is in [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) format.

### ⚠️ Breaking Changes

- `.withBackendBaseUrl()`, `.withBackendFallbackBaseUrl()`, `.withBackendConfigsBaseUrl()`, `.withBackendUABaseUrl()` methods of `AdaptyConfiguration` were being removed, please use `.withServerCluster()` method to configure the SDK

❗️ Don't forget to update your [local fallback file](https://adapty.io/docs/fallback-paywalls) if needed.

# 3.11.4

- [iOS] Fixed a bug where custom timers would start at zero. [#174](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/174)

# 3.11.3

- [Android] Fixed onboarding dismiss issue

# 3.11.2

- Support for Adapty Android SDK 3.11.1
- Various bug fixes and improvements

# 3.11.1

- [Android] Fixed `AdaptyUIOnboardingPlatformView` events

# 3.11.0

- Onboarding Builder now supports localizations. [Read More.](https://adapty.io/docs/localize-onboardings)

# 3.10.0

- AdaptyUI: added support for purchase button animations
- AdaptyUI: added support for `productPurchaseParams` in `.createPaywallView` method.

**Deprecations:**

- In `.makePurchase` method instead of `subscriptionUpdateParams` and `isOfferPersonalized` arguments use `parameters`.
- In `AdaptyPaywall` model instead of `vendorProductIds` use `productIdentifiers`.

# 3.9.0

- Added support for the User Acquisition feature. [Read more](https://adapty.io/docs/user-acquisition).
- Minimum required Xcode version is now 16.0.
- Various bug fixes and improvements.

# 3.8.4

- Changed the `makePurchase()` method signature when using parameters other than `product` – they have been extracted into `AdaptyPurchaseParameters`
- [Android] Migrated to PBL v7
- [Android] Added support for `obfuscatedProfileId` and `obfuscatedAccountId`
- [iOS] Fixed support for Xcode 26

# 3.8.3

- [Android] Fixed AdaptyUI rendering issues

# 3.8.2

- [Android] Fixed AdaptyUI rendering issues

# 3.8.1

- [iOS] Fixed dependency issue

# 3.8.0

### Meet the Adapty iOS SDK 3.8.0!

🎉 With this version we're introducing support for [the Onboarding Builder](https://adapty.io/docs/onboardings) that allows your non-technical teams to create attractive and customizable onboarding flows without coding. [Read More.](https://adapty.io/docs/onboarding-sdk)

### New

- AdaptyUI: added support for Onboarding Builder.
- AdaptyUI: added `assetsResolver` parameter to `getPaywallConfiguration` method.
- AdaptyUI: added `paywallPlacementId` and `paywallVariationId` public fields for `AdaptyPaywallController`.

### ⚠️ Breaking Changes

- `setFallbackPaywalls(fileURL:)` renamed to `setFallback(fileURL:)`.
- AdaptyUI: `AdaptyUIView` was renamed to `AdaptyUIPaywallView`.

# 3.6.1

- [Android] Fix AdaptyUI video support

# 3.6.0

- **Adapty**:
  - **Crossplacement A/B Test**: Introduced support for Crossplacement A/B testing – a test type that spans multiple placements within your app. [Read more](https://adapty.io/docs/ab-tests#ab-test-types).
  - **Support for Web Paywall**: use `.createWebPaywallUrl` or `.openWebPaywall` to navigate users to an external webpage with alternative checkout options. [Read More.](https://docs.adapty.io/docs/web-paywall)
  - Resolved an issue where, in some cases, a `profileWasChanged` error could be thrown when calling `.getPaywall` immediately after activating the sdk with a `customerUserId`.
- **AdaptyUI**:
  - Added support for Web Paywall button. [Read More.](https://adapty.io/docs/web-paywall#step-2a-add-a-web-purchase-button)
  - Fixed various rendering issues.

# 3.4.1

- Fixed support for Xcode 16.3

# 3.4.0

- Added `audienceName` property to `AdaptyPaywall` struct.
- Added `updateCollectingRefundDataConsent` and `updateRefundPreference` methods. [Read More.](https://adapty.io/docs/refund-saver#set-an-individual-refund-preference-with-the-sdk)
- Unified `reportTransaction` behaviour for iOS and Android.

# 3.3.2

- AdaptyConfiguration: add `withAppleIdfaCollectionDisabled` parameter.
- AdaptyConfiguration: add `withGoogleAdvertisingIdCollectionDisabled` parameter.
- AdaptyConfiguration: `withIdfaCollectionDisabled` is now deprecated, use `withAppleIdfaCollectionDisabled` instead.
- [Android] Fix support for Flutter 3.29.0 ([issue 151](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/151))
- Fix [issue 142](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/142)
- Fix [issue 143](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/143)
- Fix [issue 152](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/152)

# 3.3.1

- [Android] Fix AdaptyUI Close button

# 3.3.0

### ⚠️ Breaking Changes

#### Activation

- You no longer need to activate AdaptyUI separately, as it is now handled automatically during the usual activation process. Use `.withMediaCacheConfiguration` in AdaptyConfiguration if you wish to override the default settings:

```
await Adapty().activate(
  configuration: AdaptyConfiguration(apiKey: 'YOUR_API_KEY')
    ..withMediaCacheConfiguration(...),
);
```

#### Integrations and Attribution Configuration. [Read More](https://adapty.io/docs/migration-to-flutter330#update-3d-party-integration-sdk-configuration).

- **New Method for Setting Integration Identifiers**:
  - Introduced `setIntegrationIdentifier(key:value:)`:
    - Previously, integrations were configured using the `updateProfile` method, passing integration IDs to the builder.
    - Now, use `setIntegrationIdentifier` to set integration identifiers with a `key` and `value`.

- **Updated `updateAttribution` Method**:
  - The `source` parameter is now a `String` instead of an enum.
  - The `networkUserId` parameter has been removed. Use `setIntegrationIdentifier` to set the `networkUserId` instead.

#### Observer Mode. [Read More](https://adapty.io/docs/migration-to-flutter330#update-observer-mode-implementation).

- ‼️ Transactions must now be explicitly reported when using Observer Mode:
  - Replace calls to `setVariationId()` with `reportTransaction(transactionId:,variationId:)` after every `transaction.finish()`.
  - The `variationId` parameter in `reportTransaction` is now optional.

# 3.2.5

- [iOS] Fix errors in Xcode 15.0 (#100).
- [iOS] Fix an issue where an unwanted profile was sometimes created after the `identify` method was called

# 3.2.4

- [iOS] Added support for Xcode 16.2
- [iOS] Fixed support for Xcode 15.x

# 3.2.3

- AdaptyUI: Internal improvements to paywall rendering
- Fixed an issue where `isActivated()` method returned incorrect value
- Fixed an issue where `content` field of `AdaptyUIDialog` was not displaying correctly
- Fixed an issue with `subscriptionUpdateParams` wrong serialization
- Added `setupAfterHotRestart` method to Adapty and AdaptyUI which allows you to initialize the plugin after hot restart. Please check `isActivated` before calling this method. Please consider using this method in debug builds only to avoid any unexpected issues in release builds.

# 3.2.2

- added missing models exports

# 3.2.1

- `AdaptyErrorCode` change `final` to `const`
- [Android] Plugin fix

# 3.2.0

🎉 Meet the Adapty Flutter SDK 3.2.0!

With this version we're introducing support for the new paywall builder that offers more templates and layout flexibility. Note that:

- This version doesn't support paywalls created in the legacy (current) paywall builder
- But you can easily migrate those with a single press of a button in Adapty Dashboard

On top of that, this version also offers complete support of StoreKit 2 and Swift 6 on the iOS side. [See more here](https://github.com/adaptyteam/AdaptySDK-iOS/releases/tag/3.2.0).

**Breaking Changes:**

- Adapty and AdaptyUI are now a single module, so you don't need to import them separately.
- `makePurchase` now returns `AdaptyPurchaseResult` instead of `AdaptyPurchasedInfo`.
- `getProductsIntroductoryOfferEligibility(products:)` has been removed. The `getPaywallProducts` function now returns a product object with prepopulated offer information. Consider using the `getPaywallProductsWithoutDeterminingOffer(paywall:)` method if you need to load products without determining offer eligibilities.
- `paywallViewDidFinishPurchase` now accepts `AdaptyPurchaseResult` instead of `AdaptyPurchasedInfo`.
- `paywallViewDidSelectProduct` now accepts `String` (productId) instead of `AdaptyPaywallProduct`.
- `paywallViewDidCancelPurchase` has been removed. Please use the `purchaseResult` from `paywallViewDidFinishPurchase` to detect purchase cancellations.

# 2.10.4

- [Android] Add parameters to `activate` method

# 2.10.3

- Support for Flutter 3.22+

# 2.10.2

- Support for Flutter 3.22+

# 2.10.1

- Support for Adapty iOS SDK 2.10.3
- Support for Adapty Android SDK 2.10.4

# 2.10.0

⚠️ **Warning:** In this version, we have changed the minimal supported versions:

- The minimal iOS version is now 12.2.
- The minimal Xcode version is now 15.0.

⚠️ **Breaking Changes:**

- [iOS] We are no longer support `AdaptyStoreKit2Usage` parameter in the the `Adapty-Info.plist` method. Adapty SDK now utilizes the StoreKit 2 method for introductory offer eligibility checks if available.

# 2.9.3

- [Android] Fixed the incorrect format of some analytics events in rare cases.

# 2.9.2

- Added support for AdaptyUI 2.1.x
- [iOS] Fixed an issue with wrong device name in some cases on MacOS.

# 2.9.1

- [iOS] Fixed support for Swift 5.7.x (Xcode 14.0 - 14.2)
- [iOS] Fixed an issue with repeated calls to the API when the device is offline
- [Android] Redesigned analytics event system
- [Android] Improved mechanism for usage logs collection

# 2.9.0

⚠️ **Warning**:
This version relies on StoreKit 2 instead of StoreKit 1. Starting from this version, you must connect your account to [Apple In-App Purchase API](https://docs.adapty.io/docs/in-app-purchase-api-storekit-2) in Adapty Dashboard. Otherwise, we won't be able to make or validate purchases.

**New**:

- Since this version we are using CDN. This technology helps us to synchronize data much faster.
- Added an option to retrieve paywalls from local cache by passing `fetchPolicy` parameter into `.getPaywall()` method
- Added an option to specify paywall fetching timeout by passing `loadTimeout` parameter into `.getPaywall()` method

Read More in our [documentation](https://docs.adapty.io/docs/displaying-products#getpaywall-parameters).

**Breaking Changes**:

- `placementId` parameter has been added to the `getPaywall` method, replacing the previously unnamed parameter `id`. [Read More](https://docs.adapty.io/docs/displaying-products)
- `AdaptyEnableUsageLogs` of `Adapty-Info.plist` is no longer supported, since this feature is enabled by default. [Read More](https://docs.adapty.io/docs/flutter-configuring#collecting-usage-logs-ios-only)
- If you will not put the `AdaptyStoreKit2Usage` parameter to `Adapty-Info.plist`, the default value will be `.forIntroEligibilityCheck` (this means that by default we will fetch introductory offers eligibility using StoreKit 2). [Read More](https://docs.adapty.io/docs/flutter-configuring#storekit-2-usage)

# 2.7.1

- [Android] fixes for AdaptyUI library

# 2.7.0

- [iOS] Update Adapty-iOS dependency to 2.7.0
- [Android] Update Adapty-Android dependency to 2.7.0

# 2.6.2

- [Android] Updated retry logic according to new PBL error.

# 2.6.1

- [Android] Fixed error on purchase validation.
- [Android] Support for [Google Billing Library v5+](https://developer.android.com/google/play/billing/compatibility). [Read More](https://github.com/adaptyteam/AdaptySDK-Android/releases/tag/2.6.0)
- [iOS] Since this version, the Adapty SDK will observe StoreKit 2 transactions, which will be helpful if you are using observer mode.
- [iOS] Introduced a new functionality for retrieving introductory offers eligibility using StoreKit 2. To fetch it, you should now use a separate method called .getProductsIntroductoryOfferEligibility. The behavior of this function depends on your Adapty SDK configuration. It will utilize StoreKit 2 if available or fallback to a legacy logic based on receipt analysis. For more detailed information, please refer to our documentation. [Read more](https://docs.adapty.io/docs/displaying-products#adapty-sdk-version-250-and-higher)
- `AdaptyPaywallProduct` now has a unified structure for both systems.

# 2.6.0

- [Android] Support for [Google Billing Library v5+](https://developer.android.com/google/play/billing/compatibility). [Read More](https://github.com/adaptyteam/AdaptySDK-Android/releases/tag/2.6.0)
- [iOS] Since this version, the Adapty SDK will observe StoreKit 2 transactions, which will be helpful if you are using observer mode.
- [iOS] Introduced a new functionality for retrieving introductory offers eligibility using StoreKit 2. To fetch it, you should now use a separate method called .getProductsIntroductoryOfferEligibility. The behavior of this function depends on your Adapty SDK configuration. It will utilize StoreKit 2 if available or fallback to a legacy logic based on receipt analysis. For more detailed information, please refer to our documentation. [Read more](https://docs.adapty.io/docs/displaying-products#adapty-sdk-version-250-and-higher)
- `AdaptyPaywallProduct` now has a unified structure for both systems.

# 2.4.4

- Added `hasViewConfiguration` for `AdaptyPaywall` object

# 2.4.3

- [iOS] Improved variation_id delivery mechanism when validating purchases (iOS 2.4.4)
- [iOS] Improved mechanism for [Usage Logs](https://docs.adapty.io/docs/ios-configuring#collecting-usage-logs) collection (iOS 2.4.5)
- [iOS] Fixed a bug which caused wrong error codes from StoreKit to be passed to the cross platform SDKs (iOS 2.4.5)

# 2.4.2

- Redesigned analytics event system
- Added an option to activate usage logs
- `isOneTime` property of `AdaptyProfile.NonSubscription` was deprecated, use `isConsumable` instead

# 2.4.1

- [Android] fixed subscription change functionality

# 2.4.0

- Changed the logic of working with fallback paywalls - now the SDK will not wait for the creation of a profile
- Added an option to set `airbridgeDeviceId` to user profile
- The logging system has been improved: all requests and responses from the server are now logged in verbose mode, and the computation required for logging has been optimized
- Increased the length and number of custom attributes

# 2.3.1

- [Android] updated dependency to 2.3.2

# 2.3.0

- Added an option to specify the [paywall locale](https://docs.adapty.io/docs/paywall#localizations).
- [iOS] updated dependency to 2.3.3
- [Android] updated dependency to 2.3.1

# 2.2.5

- [iOS] Fixed a bug that caused a new anonymous user to be created when migrating from earlier versions of the SDK.

# 2.2.4

- [iOS] Fixed `didUpdateProfileStream` serialization bug.

# 2.2.3

- Added integration with Firebase and Google Analytics. [Read more.](https://docs.adapty.io/docs/firebase-and-google-analytics)
- [Android] Fixed a bug when products returned in a wrong order

# 2.2.2

- [iOS] Fixed a bug when some additional purchase parameters were not sent in Observer Mode.

# 2.2.1

- [Android] fixed parsing error for free trial fields.
- Updated errors documentation.

# 2.2.0

Meet the second version of the Adapty SDK 🎉

See our [What's new in Adapty Flutter SDK 2.0 doc](https://docs.adapty.io/v2.0/docs/migration-to-flutter-2) for API updates.
Adapty 2.0 introduces the following updates:

## Breaking changes:

- Adapty now is singleton. Use `Adapty().someMethodCall()` instead of `Adapty.someMethodCall()`
- User-initiated purchases are now automatically processed by the system, so we have removed the `deferredPurchasesStream` and `makeDeferredPurchase()` method.
- We are no longer support Visual Paywalls and Promo Campaigns features, so you should remove the calls to the corresponding methods, if there were any
- Instead of getting all paywalls in one request with the `.getPaywalls()`, it must be done separately for each paywall using `.getPaywall(id:)`
- Products are no longer part of the paywall, they must be loaded separately with `.getPaywallProducts(paywall:)`
- It is no longer possible to use products outside of the paywall. If you need to handle a product, create a separate paywall for it (or for multiple products).
- `introductoryOfferEligibility` – instead of true/false we give a more extended list of options
- The `AdaptyProfileParametersBuilder` is redesigned:
  - Methods, related to custom attributes now can throw an exception, if key or value didn't pass validation
  - Added an option to pass null values to builder functions for more convenience
  - You can now remove customAttributes with the function `.removeCustomAttribute("key")`
  - You have to use `.build()` method and pass resulting `AdaptyProfileParameters` object to `.updateProfile` method
- `.setAnalyticsDisabled()` method has been eliminated. Use the `.setAnalyticsDisabled` method of `AdaptyProfileParametersBuilder`.
- The `forceUpdate` parameter was removed from the `getPaywall` method. The result will always be up to date if it is possible to retrieve data from the server

## Renames

- `PurchaserInfo` renamed to `AdaptyProfile`
- `.getPurchaserInfo` renamed to `.getProfile`
- `didReceivePurchaserInfoStream` was also renamed to `.didUpdateProfileStream`
- `developerId` field of `AdaptyPaywall` was renamed to `id`
- `AdaptyAttributionNetwork` renamed to `AdaptyAttributionSource`

## Fixes

- Fixed wrong behavior of fallback paywalls in some cases
- `.setFallbackPaywalls()` method now does not return errors related to StoreKit product retrieval
- Incorrect user segmentation in some rare cases

## Additions:

- Ability to log onboard screens with `.logShowOnboarding()`. [Read more](https://docs.adapty.io/docs/onboarding-screens-tracking)
- Added ability to get previously set `customAttributes`, now it is part of `AdaptyProfile`

## Under the hood:

- The server interaction layer was rewritten from scratch.
- The initial request sequence has been optimized and simplified
- Reduced the number of API calls made by SDK. Some of the request are now faster and transfer less data.
- Independent requests can be executed simultaneously
- StoreKit interaction layer was refactored

Full documentation can be found in [here](https://docs.adapty.io/v2.0/docs/).

# 1.0.14

- Fixed type cast in the `makeDeferredPurchase` method

# 1.0.13

- Upgraded with iOS SDK version 1.17.7 and Android SDK version 1.11.0

# 1.0.12

- [Android] fixed localized properties

# 1.0.11

- Support for Flutter 3.0

# 1.0.10

- Ability to use Adapty-Info.plist for storing initialization parameters

# 1.0.9

- The `getPromo` method now works for Android [Issue 34](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/34)
- Fixed typo in word "deferred" [Issue 35](https://github.com/adaptyteam/AdaptySDK-Flutter/issues/35)

# 1.0.8

- Updated `PurchaserInfoModel` property `profileId` access level to public

# 1.0.7

- [iOS] Added support for disabling IDFA collection
- [Android] Improved handling clicks on push notifications

# 1.0.6

- [iOS] Added support for AdServices attribution tracking
- [Android] internal sdk improvements

# 1.0.5

- [Android] added logLevel ALL, logLevel VERBOSE doesn't include analytical logs, but ALL does
- changed example for updating custom attribution
- various improvements

# 1.0.4

- added toString for `AdaptyAccessLevelInfo`, `AdaptySubscriptionInfo`, `AdaptyNonSubscriptionInfo` models

# 1.0.3

- Added new log level "all"
- Fallback paywalls offline work
- [iOS] Added optional `offerId` parameter to `makePurchase` method

# 1.0.2

- [iOS] Updated AdaptyProfileParameterBuilder to work with ATTrackingManager.AuthorizationStatus
- Removed usage of dart ffi
- Made receipt validation api method private

# 1.0.1

- [Android] Added support for fallback paywalls

# 1.0.0

- Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

# 1.0.0-nullsafety.0

- Enable null safety
- Require Dart 2.12 or greater.

# 0.3.6

- [Android] fixed localizedTitle in product

# 0.3.5

- [iOS] Added `isFamilyShareable` property to product for iOS 14+.
- [iOS] Added `.presentCodeRedemptionSheet()` to public SDK API

# 0.3.4

- [Android] Small fix in requests

# 0.3.3

- [iOS] Added retry for `createProfile` request in case of poor connection or if server is down.
- [Android] Added gzip support
- Removed unnecessary event channel invocations for `.getPaywalls()` and `.getPurchaserInfo()` methods

# 0.3.2

- Fixed `.getPaywalls()` callback without an internet connection (Android only)

# 0.3.1

- Added `.setFacebookAnonymousId` method to `AdaptyProfileParameterBuilder`
- Added `freeTrialPeriod` property of `AdaptyProduct` model (Android only)

# 0.3.0

- Added ability to connect observer mode purchase with a paywall it was made from using `.setTransactionVariationId` method
- Added ability to opt-out from external analytics services using `.setExternalAnalyticsEnabled` method
- Added public `abTestName` and `name` properties to `AdaptyPaywall` and to nested products array.
- Paywall views must be reported using `.logShowPaywall(paywall)` method from now on, otherwise, views will not be collected.

# 0.2.0

- Plugin initialization scheme changed to prevent missing transaction on iOS.
- Added `.logShowPaywall(paywall)` to manually record paywall show event.
- Added `apnsTokenString` to public properties.
- Removed `state` from `.getPurchaserInfo()` callback. Added `forceUpdate` as an optional request parameter.
- Removed `state` from `.getPaywalls()` callback. Added `forceUpdate` as an optional request parameter.

# 0.1.2

- empty string custom payload fixed
- `updateAttribution()` fixed on Android
- `getPurchaserInfo()` stability improved
- `verbose logLevel` removed as default

# 0.1.1

- `customPayloadString` added to Paywall
- birthday fix in `updateProfile`

# 0.1.0

- Initial release
