import 'package:common/common/module/blockaweb/blockaweb.dart';
import 'package:common/common/module/modal/modal.dart';
import 'package:common/common/module/payment/payment.dart';
import 'package:common/common/widget/safari/safari_content_onboard_sheet.dart';
import 'package:common/common/widget/safari/safari_youtube_onboard_sheet.dart';
import 'package:common/core/core.dart';
import 'package:common/platform/account/account.dart';
import 'package:common/platform/app/app.dart';
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
  late final _account = Core.get<AccountStore>();
  late final _app = Core.get<AppStore>();

  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardSafariYoutube) {
        _modalWidget.change(it.m, (context) => const SafariYoutubeOnboardSheetIos());
      } else if (it.now == Modal.onboardSafari) {
        _modalWidget.change(it.m, (context) => const SafariContentOnboardSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentSuccessful, showDnsOnboard);
    _payment.addOnValue(paymentClosed, showSafariContentOnboard);
    _dnsEnabledFor.onChangeInstant(showSafariYoutubeOnboard);
  }

  // DNS onboard, after successful payment if no dns perms granted.
  showDnsOnboard(bool restore, Marker m) async {
    return await log(m).trace("maybeShowPermOnboard", (m) async {
      if (!_perm.isPrivateDnsEnabled && !restore) {
        await _modal.change(m, Modal.onboardPrivateDns);
      }
    });
  }

  // Safari Youtube onboard in iOS, after DNS perms are granted (but only once)
  showSafariYoutubeOnboard(NullableValueUpdate<DeviceTag> it) async {
    if (Core.act.platform != PlatformType.iOS) return;
    return await log(it.m).trace("maybeShowSafariYoutubeOnboard", (m) async {
      final dnsEnabled = _perm.isPrivateDnsEnabled;
      final needsOnboard = await _blockaweb.needsOnboard(m);
      if (dnsEnabled && needsOnboard) {
        await _modal.change(m, Modal.onboardSafariYoutube);
      }
    });
  }

  // Safari content filter onboard on iOS, after paywall closed with purchase
  showSafariContentOnboard(bool ignored, Marker m) async {
    return await log(m).trace("maybeShowSafariContentOnboard", (m) async {
      if (_app.status.isActive()) return;
      if (!_account.isFreemium) return;

      //final needsOnboard = await _blockaweb.needsOnboard(m);
      final needsOnboard = true;
      if (needsOnboard) {
        await sleepAsync(const Duration(seconds: 1));
        await _modal.change(m, Modal.onboardSafari);
      }
    });
  }
}
