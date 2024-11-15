import 'package:common/common/state/state.dart';
import 'package:common/platform/device/device.dart';

class SelectedDeviceTag extends NullableValue<DeviceTag> {
  @override
  Future<DeviceTag?> doLoad() async => null;
}
