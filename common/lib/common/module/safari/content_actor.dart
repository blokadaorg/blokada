part of 'safari.dart';

/// Handles state sync between the app and the Safari content filter extension.
class SafariContentActor with Actor, Logging {
  late final _channel = Core.get<SafariChannel>();
  late final _app = Core.get<AppStore>();
  late final _account = Core.get<AccountStore>();
  late final _payment = Core.get<PaymentActor>();

  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardSafari) {
        _modalWidget.change(it.m, (context) => const SafariContentOnboardSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    _payment.addOnValue(paymentClosed, checkFreemiumStateAfterPaywall);
    _app.addOn(appStatusChanged, syncContentFilterStateWithAppState);
  }

  // Safari content filter onboard on iOS, after paywall closed with purchase
  checkFreemiumStateAfterPaywall(bool ignored, Marker m) async {
    return await log(m).trace("checkFreemiumStateAfterPaywall", (m) async {
      if (_app.status.isActive()) return;
      if (!_account.isFreemium) return;

      // Show onboard if freemium is not active, but only once per a few seconds
      // This is because _modal has no notion of what is currently open, and we don't want
      // to double show it.
      final isActive = await _syncContentFilterState(m);
      if (!isActive) {
        await sleepAsync(const Duration(seconds: 1));
        log(m).w("got here");
        await _modal.change(m, Modal.onboardSafari);
        return;
      }

      // If the content filter is already active, make sure app state is active
      await _updateAppStateToActive(m);
    });
  }

  // Whenever app state changes, also sync the content filter state (the lists)
  syncContentFilterStateWithAppState(Marker m) async {
    await _syncContentFilterState(m);
  }

  Future<bool> _syncContentFilterState(Marker m) async {
    return await log(m).trace("syncContentFilterState", (m) async {
      final isActive = await _channel.doGetStateOfContentFilter();

      // The extension is turned off (only user can turn it on)
      if (!isActive) return false;

      // If the content filter is active, update its filters since those we can manage.
      if (_account.isFreemium && _app.status == AppStatus.activatedFreemium) {
        await _channel.doUpdateContentFilterRules(true);
      } else {
        await _channel.doUpdateContentFilterRules(false);
      }

      return true;
    });
  }

  doOpenPermsFlow(Marker m) async {
    // Real flow to implement TODO
    //await _channel.doOpenPermsFlowForContentFilter();
    await _updateAppStateToActive(m);
  }

  _updateAppStateToActive(Marker m) async {
    await _app.reconfiguring(m);

    // Needs to happen after the wait from unpauseApp
    // MARK1
    await sleepAsync(const Duration(seconds: 3));

    await _app.freemiumActivated(m, true);
  }
}
