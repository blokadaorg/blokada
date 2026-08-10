import '../../constants/argument.dart';

class AdaptyUIPermissionResult {
  final bool granted;
  final String? detail;

  const AdaptyUIPermissionResult.granted([this.detail]) : granted = true;

  const AdaptyUIPermissionResult.denied([this.detail]) : granted = false;

  Map<String, dynamic> get jsonValue => {
        Argument.status: granted ? 'granted' : 'denied',
        if (detail != null) Argument.detail: detail,
      };
}
