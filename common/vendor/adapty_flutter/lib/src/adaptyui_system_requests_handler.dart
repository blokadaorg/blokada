import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adaptyui/adaptyui_permission.dart';
import 'models/adaptyui/adaptyui_permission_result.dart';

abstract class AdaptyUISystemRequestsHandler {
  Future<AdaptyUIPermissionResult> handlePermission(
      AdaptyUIFlowView view, AdaptyUIPermission permission, Map<String, String>? customArgs);

  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async {}
}
