//
//  adapty_access_level_json_builder.dart
//  Adapty
//
//  Created by Alexey Goncharov on 10.11.2024.
//

import 'package:meta/meta.dart' show immutable;

import 'adapty_customer_identity.dart';
import 'adapty_log_level.dart';
import '../adapty_version.dart';

part 'private/adapty_configuration_json_builder.dart';

enum AdaptyServerCluster {
  defaultCluster,
  eu,
  cn,
}

@immutable
class AdaptyUIMediaCacheConfiguration {
  final int memoryStorageTotalCostLimit;
  final int memoryStorageCountLimit;
  final int diskStorageSizeLimit;

  const AdaptyUIMediaCacheConfiguration({
    required this.memoryStorageTotalCostLimit,
    required this.memoryStorageCountLimit,
    required this.diskStorageSizeLimit,
  });

  static const defaultValue = AdaptyUIMediaCacheConfiguration(
    memoryStorageTotalCostLimit: 100 * 1024 * 1024, // 100MB
    memoryStorageCountLimit: 2147483647, // 2^31 - 1, max int value in Dart
    diskStorageSizeLimit: 100 * 1024 * 1024, // 100MB
  );
}

class AdaptyConfiguration {
  final String _apiKey;
  String? _customerUserId = null;
  AdaptyCustomerIdentity? _customerIdentity;
  bool _observerMode = false;
  bool _ipAddressCollectionDisabled = false;
  bool? _appleClearDataOnBackup = null;
  bool _appleIdfaCollectionDisabled = false;
  bool _googleAdvertisingIdCollectionDisabled = false;
  bool _googleEnablePendingPrepaidPlans = false;
  bool _googleLocalAccessLevelAllowed = false;
  String? _backendProxyHost;
  int? _backendProxyPort;
  String? _serverCluster;
  AdaptyUIMediaCacheConfiguration _mediaCache = AdaptyUIMediaCacheConfiguration.defaultValue;

  AdaptyLogLevel? _logLevel = AdaptyLogLevel.info;
  bool _activateUI = true;
  String _crossPlatformSDKName = 'flutter';
  String _crossPlatformSDKVersion = adaptySDKVersion;

  /// Initializes the configuration with the given API key.
  ///
  /// **Parameters:**
  /// - [apiKey]: You can find it in your app settings in [Adapty Dashboard](https://app.adapty.io/) *App settings* > *General*.
  AdaptyConfiguration({
    required String apiKey,
  }) : _apiKey = apiKey;

  /// **Parameters:**
  /// - [customerUserId]: User identifier in your system
  /// - [iosAppAccountToken]: iOS App Account Token (UUID string)
  /// - [androidObfuscatedAccountId]: Android Obfuscated Account ID
  void withCustomerUserId(String customerUserId, {String? iosAppAccountToken, String? androidObfuscatedAccountId}) {
    _customerUserId = customerUserId;
    _customerIdentity = AdaptyCustomerIdentity(
      iosAppAccountToken,
      androidObfuscatedAccountId,
    );
  }

  /// **Parameters:**
  /// - [observerMode]: A boolean value controlling [Observer mode](https://docs.adapty.io/docs/observer-vs-full-mode/). Turn it on if you handle purchases and subscription status yourself and use Adapty for sending subscription events and analytics
  void withObserverMode(bool observerMode) {
    _observerMode = observerMode;
  }

  /// **Parameters:**
  /// - [appleIdfaCollectionDisabled]: A boolean value controlling Apple IDFA collection logic
  void withAppleIdfaCollectionDisabled(bool appleIdfaCollectionDisabled) {
    _appleIdfaCollectionDisabled = appleIdfaCollectionDisabled;
  }

  /// **Parameters:**
  /// - [googleAdvertisingIdCollectionDisabled]: A boolean value controlling Google Advertising ID collection logic
  void withGoogleAdvertisingIdCollectionDisabled(bool googleAdvertisingIdCollectionDisabled) {
    _googleAdvertisingIdCollectionDisabled = googleAdvertisingIdCollectionDisabled;
  }

  /// **Parameters:**
  /// - [googleEnablePendingPrepaidPlans]: A boolean value controlling Google enable pending prepaid plans
  void withGoogleEnablePendingPrepaidPlans(bool googleEnablePendingPrepaidPlans) {
    _googleEnablePendingPrepaidPlans = googleEnablePendingPrepaidPlans;
  }

  void withGoogleLocalAccessLevelAllowed(bool googleLocalAccessLevelAllowed) {
    _googleLocalAccessLevelAllowed = googleLocalAccessLevelAllowed;
  }

  /// **Parameters:**
  /// - [ipAddressCollectionDisabled]: A boolean value controlling IP address collection logic
  void withIpAddressCollectionDisabled(bool ipAddressCollectionDisabled) {
    _ipAddressCollectionDisabled = ipAddressCollectionDisabled;
  }

  /// **Parameters:**
  /// - [clearDataOnBackup]: A boolean value controlling whether the SDK will create a new profile when the app is restored from an iCloud backup
  void withAppleClearDataOnBackup(bool appleClearDataOnBackup) {
    _appleClearDataOnBackup = appleClearDataOnBackup;
  }

  /// **Parameters:**
  /// - [logLevel]: A log level for the SDK
  void withLogLevel(AdaptyLogLevel logLevel) {
    _logLevel = logLevel;
  }

  void withBackendProxyHost(String backendProxyHost) {
    _backendProxyHost = backendProxyHost;
  }

  void withBackendProxyPort(int backendProxyPort) {
    _backendProxyPort = backendProxyPort;
  }

  void withCrossPlatformSDKName(String crossPlatformSDKName) {
    _crossPlatformSDKName = crossPlatformSDKName;
  }

  void withCrossPlatformSDKVersion(String crossPlatformSDKVersion) {
    _crossPlatformSDKVersion = crossPlatformSDKVersion;
  }

  void withServerCluster(AdaptyServerCluster serverCluster) {
    switch (serverCluster) {
      case AdaptyServerCluster.eu:
        _serverCluster = 'eu';
        break;
      case AdaptyServerCluster.cn:
        _serverCluster = 'cn';
        break;
      default:
        _serverCluster = 'default';
    }
  }

  void withActivateUI(bool activateUI) {
    _activateUI = activateUI;
  }

  void withMediaCacheConfiguration(AdaptyUIMediaCacheConfiguration mediaCacheConfiguration) {
    _mediaCache = mediaCacheConfiguration;
  }
}
