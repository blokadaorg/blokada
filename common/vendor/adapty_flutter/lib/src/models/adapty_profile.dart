//
//  adapty_profile.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';
import 'adapty_access_level.dart';
import 'adapty_attribution_source.dart';
import 'adapty_non_subscription.dart';
import 'adapty_subscription.dart';

part 'private/adapty_profile_json_builder.dart';

@immutable
class AdaptyProfile {
  /// An identifier of a user in Adapty.
  final String profileId;

  final String _segmentId;

  /// An identifier of a user in your system.
  ///
  /// [Nullable]
  final String? customerUserId;

  /// Previously set user custom attributes with `.updateProfile()` method.
  final Map<String, dynamic> customAttributes;

  /// The keys are access level identifiers configured by you in Adapty Dashboard.
  /// The values are Can be null if the customer has no access levels.
  final Map<String, AdaptyAccessLevel> accessLevels;

  /// The keys are product ids from a store. The values are information about subscriptions.
  /// Can be null if the customer has no subscriptions.
  final Map<String, AdaptySubscription> subscriptions;

  /// The keys are product ids from the store. The values are arrays of information about consumables.
  /// Can be null if the customer has no purchases.
  final Map<String, List<AdaptyNonSubscription>> nonSubscriptions;

  /// Identifiers of attribution sources applied to the profile and available for segmentation.
  /// Known values: [AdaptyAttributionSource.appleAds]. Other identifiers may be emitted
  /// in future versions — clients must tolerate unknown values via [AdaptyAttributionSource.rawValue].
  final List<AdaptyAttributionSource> appliedAttributionSources;

  final int _version;

  /// Indicates if the profile belongs to a test devices.
  /// Read more about test devices in [Adapty documentation](https://adapty.io/docs/test-devices).
  final bool isTestUser;

  const AdaptyProfile._(
    this.profileId,
    this._segmentId,
    this.customerUserId,
    this.customAttributes,
    this.accessLevels,
    this.subscriptions,
    this.nonSubscriptions,
    this.appliedAttributionSources,
    this._version,
    this.isTestUser,
  );

  @override
  String toString() => '(profileId: $profileId, '
      '_segmentId: $_segmentId, '
      'customerUserId: $customerUserId, '
      'customAttributes: $customAttributes, '
      'accessLevels: $accessLevels, '
      'subscriptions: $subscriptions, '
      'nonSubscriptions: $nonSubscriptions, '
      'appliedAttributionSources: $appliedAttributionSources, '
      '_version: $_version, '
      'isTestUser: $isTestUser)';
}
