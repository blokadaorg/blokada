part of '../adapty_installation_details.dart';

extension AdaptyInstallationDetailsJSONBuilder on AdaptyInstallationDetails {
  // dynamic get jsonValue => {
  //       _Keys.installId: installId,
  //       _Keys.installTime: installTime.toIso8601String(),
  //       _Keys.appLaunchCount: appLaunchCount,
  //       _Keys.payload: payload,
  //     };

  static AdaptyInstallationDetails fromJsonValue(Map<String, dynamic> json) {
    return AdaptyInstallationDetails._(
      json.stringIfPresent(_Keys.installId),
      json.dateTime(_Keys.installTime),
      json.integer(_Keys.appLaunchCount),
      json.stringIfPresent(_Keys.payload),
    );
  }
}

class _Keys {
  static const String installId = 'install_id';
  static const String installTime = 'install_time';
  static const String appLaunchCount = 'app_launch_count';
  static const String payload = 'payload';
}

extension AdaptyInstallationStatusJSONBuilder on AdaptyInstallationStatus {
  static AdaptyInstallationStatus fromJsonValue(Map<String, dynamic> json) {
    final status = json[Argument.status];

    switch (status) {
      case 'not_available':
        return AdaptyInstallationStatusNotAvailable();
      case 'not_determined':
        return AdaptyInstallationStatusNotDetermined();
      case 'determined':
        final details = AdaptyInstallationDetailsJSONBuilder.fromJsonValue(json[Argument.details]);
        return AdaptyInstallationStatusDetermined(details);
      default:
        throw AdaptyError(
          'Unknown installation status: $status',
          AdaptyErrorCode.internalPluginError,
          null,
        );
    }
  }
}
