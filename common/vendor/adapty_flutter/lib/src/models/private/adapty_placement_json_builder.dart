part of '../adapty_placement.dart';

extension AdaptyPlacementJSONBuilder on AdaptyPlacement {
  dynamic get jsonValue => {
        _Keys.developerId: id,
        _Keys.audienceName: audienceName,
        _Keys.revision: revision,
        _Keys.abTestName: abTestName,
        _Keys.placementAudienceVersionId: placementAudienceVersionId,
        if (_isTrackingPurchases != null) _Keys.isTrackingPurchases: _isTrackingPurchases,
      };

  static AdaptyPlacement fromJsonValue(Map<String, dynamic> json) {
    return AdaptyPlacement._(
      json.string(_Keys.developerId),
      json.string(_Keys.audienceName),
      json.integer(_Keys.revision),
      json.string(_Keys.abTestName),
      json.string(_Keys.placementAudienceVersionId),
      json.booleanIfPresent(_Keys.isTrackingPurchases),
    );
  }
}

class _Keys {
  static const developerId = 'developer_id';
  static const audienceName = 'audience_name';
  static const revision = 'revision';
  static const abTestName = 'ab_test_name';
  static const placementAudienceVersionId = 'placement_audience_version_id';
  static const isTrackingPurchases = 'is_tracking_purchases';
}
