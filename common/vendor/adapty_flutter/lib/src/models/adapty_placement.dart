import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';

part 'private/adapty_placement_json_builder.dart';

@immutable
class AdaptyPlacement {
  final String id;

  final String audienceName;

  final int revision;

  final String abTestName;

  final String placementAudienceVersionId;

  final bool? _isTrackingPurchases;

  bool get isTrackingPurchases => _isTrackingPurchases ?? false;

  const AdaptyPlacement._(
    this.id,
    this.audienceName,
    this.revision,
    this.abTestName,
    this.placementAudienceVersionId,
    this._isTrackingPurchases,
  );
}
