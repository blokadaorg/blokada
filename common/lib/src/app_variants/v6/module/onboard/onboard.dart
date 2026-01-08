import 'package:common/src/features/modal/domain/modal.dart';
import 'package:common/src/features/payment/domain/payment.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/perm/dnscheck.dart';
import 'package:common/src/platform/perm/perm.dart';

part 'value.dart';

class V6OnboardModule with Module {
  @override
  onCreateModule() async {
    await register<PrivateDnsStringProvider>(V6PrivateDnsStringProvider());
    await register(V6OnboardActor());
  }
}

// Will pop various onboarding sheets during onboarding
class V6OnboardActor with Actor, Logging {
  late final _perm = Core.get<PlatformPermActor>();
  late final _payment = Core.get<PaymentActor>();
  late final _modal = Core.get<CurrentModalValue>();

  @override
  onCreate(Marker m) async {}

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentSuccessful, showDnsOnboard);
  }

  // DNS onboard, after successful payment if no dns perms granted.
  showDnsOnboard(bool restore, Marker m) async {
    return await log(m).trace("maybeShowPermOnboard", (m) async {
      if (!_perm.isPrivateDnsEnabled && !restore) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }
}
