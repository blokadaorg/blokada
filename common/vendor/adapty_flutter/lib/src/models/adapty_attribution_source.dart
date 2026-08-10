//
//  adapty_attribution_source.dart
//  Adapty
//

import 'package:meta/meta.dart' show immutable;

/// Identifier of an attribution source applied to the profile and available for segmentation.
///
/// Modelled as an open wrapper over a raw string (mirroring the iOS SDK's
/// `RawRepresentable` value) so unknown identifiers emitted by future backend
/// versions remain valid. Use the predefined static constants
/// (e.g. [AdaptyAttributionSource.appleAds]) for comparisons against
/// known values.
@immutable
class AdaptyAttributionSource {
  final String rawValue;

  const AdaptyAttributionSource(this.rawValue);

  static const appleAds = AdaptyAttributionSource('apple_search_ads');

  @override
  bool operator ==(Object other) =>
      other is AdaptyAttributionSource && other.rawValue == rawValue;

  @override
  int get hashCode => rawValue.hashCode;

  @override
  String toString() => rawValue;
}
