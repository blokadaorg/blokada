import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';

/// Registers the pause-origin flag DeviceStore writes, kept in memory so
/// tests need no Persistence.
PauseIssuedHereValue registerMemoryPauseOrigin() {
  final value = PauseIssuedHereValue()
    ..load = ((_) async => null)
    ..save = ((_, _) async {});
  Core.register<PauseIssuedHereValue>(value);
  return value;
}
