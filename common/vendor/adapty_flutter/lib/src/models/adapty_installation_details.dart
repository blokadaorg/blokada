import 'adapty_error.dart';
import 'adapty_error_code.dart';
import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';
import '../constants/argument.dart';

part 'private/adapty_installation_details_json_builder.dart';

@immutable
class AdaptyInstallationDetails {
  final String? installId;
  final DateTime installTime;
  final int appLaunchCount;
  final String? payload;

  const AdaptyInstallationDetails._(
    this.installId,
    this.installTime,
    this.appLaunchCount,
    this.payload,
  );

  @override
  String toString() => '(installId: $installId, '
      'installTime: $installTime, '
      'appLaunchCount: $appLaunchCount, '
      'payload: $payload)';
}

sealed class AdaptyInstallationStatus {
  const AdaptyInstallationStatus();
}

class AdaptyInstallationStatusNotAvailable extends AdaptyInstallationStatus {
  const AdaptyInstallationStatusNotAvailable();
}

class AdaptyInstallationStatusNotDetermined extends AdaptyInstallationStatus {
  const AdaptyInstallationStatusNotDetermined();
}

class AdaptyInstallationStatusDetermined extends AdaptyInstallationStatus {
  final AdaptyInstallationDetails details;

  const AdaptyInstallationStatusDetermined(this.details);
}
