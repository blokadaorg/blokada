import 'package:common/common/module/blockaweb/blockaweb.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/safari/safari_onboard_sheet.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/device/device.dart';
import 'package:common/platform/perm/dnscheck.dart';
import 'package:common/platform/perm/perm.dart';

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
  late final _blockaweb = Core.get<BlockaWebActor>();
  late final _modal = Core.get<CurrentModalValue>();

  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardSafari) {
        _modalWidget.change(it.m, (context) => const SafariOnboardSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentSuccessful, showDnsOnboard);
    _dnsEnabledFor.onChangeInstant(showSafariOnboard);
  }

  // DNS onboard, after successful payment if no dns perms granted.
  showDnsOnboard(bool restore, Marker m) async {
    return await log(m).trace("maybeShowPermOnboard", (m) async {
      if (!_perm.isPrivateDnsEnabled && !restore) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }

  // Safari onboard in iOS, after DNS perms are granted (but only once)
  showSafariOnboard(NullableValueUpdate<DeviceTag> it) async {
    if (Core.act.platform != PlatformType.iOS) return;
    return await log(it.m).trace("maybeShowSafariOnboard", (m) async {
      final dnsEnabled = _perm.isPrivateDnsEnabled;
      final needsOnboard = await _blockaweb.needsOnboard(m);
      if (dnsEnabled && needsOnboard) {
        await _modal.change(m, Modal.onboardSafari);
      }
    });
  }
}
