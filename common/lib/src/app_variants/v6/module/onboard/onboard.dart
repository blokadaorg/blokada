import 'package:common/src/app_variants/v6/module/activation/activation.dart';
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
    await register(V6ActivationActor());
    await register(V6OnboardActor());
  }
}

// Will pop various onboarding sheets during onboarding
class V6OnboardActor with Actor, Logging {
  late final _perm = Core.get<PlatformPermActor>();
  late final _payment = Core.get<PaymentActor>();
  late final _modal = Core.get<CurrentModalValue>();
  late final _activation = Core.get<V6ActivationActor>();

  @override
  onCreate(Marker m) async {}

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentSuccessful, showDnsOnboard);
  }

  // After a successful payment: the guided activation for its cohort (#457),
  // otherwise the DNS onboard if no DNS perms are granted (#129).
  showDnsOnboard(bool restore, Marker m) async {
    return await log(m).trace("maybeShowPermOnboard", (m) async {
      if (_activation.runsFor(restore)) {
        await _activation.begin(m);
        return;
      }
      if (!_perm.isPrivateDnsEnabled && !restore) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }
}
