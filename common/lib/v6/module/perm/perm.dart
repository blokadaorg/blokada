import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/perm/perm.dart';

class V6PermModule with Module {
  @override
  onCreateModule() async {
    await register<PrivateDnsStringProvider>(V6PrivateDnsStringProvider());
    await register<V6PermActor>(V6PermActor());
  }
}

class V6PrivateDnsStringProvider extends PrivateDnsStringProvider {
  late final _device = Core.get<DeviceStore>();
  late final _check = Core.get<PrivateDnsCheck>();

  @override
  String getAndroidDnsString() {
    final tag = _device.deviceTag!;
    final alias = _device.deviceAlias;
    return _check.getAndroidPrivateDnsString(Markers.root, tag, alias);
  }
}

// Will pop the onboarding sheet after successful payment if no dns perms granted.
class V6PermActor with Actor, Logging {
  late final _perm = Core.get<PlatformPermActor>();
  late final _payment = Core.get<PaymentActor>();
  late final _modal = Core.get<CurrentModalValue>();

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentSuccessful, showPermOnboard);
  }

  showPermOnboard(bool restore, Marker m) async {
    return await log(m).trace("maybeShowPermOnboard", (m) async {
      if (!_perm.isPrivateDnsEnabled && !restore) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }
}
