part of 'payment.dart';

enum Placement {
  primary("primary"),
  plusUpgrade("home_plus_upgrade");

  final String id;

  const Placement(this.id);
}

class PaymentActor with Actor, Logging {
  late final _accountEphemeral = Core.get<api.AccountEphemeral>();
  late final _account = Core.get<AccountStore>();
  late final _api = Core.get<PaymentApi>();
  late final _family = Core.get<FamilyActor>();
  late final _onboard = Core.get<CurrentOnboardingStepValue>();
  late final _stage = Core.get<StageStore>();
  late final _channel = Core.get<PaymentChannel>();
  late final _key = Core.get<AdaptyApiKey>();

  bool _adaptyInitialized = false;
  bool _preloaded = false;
  Completer? _preloadCompleter;
  bool _isOpened = false;

  Function onPaymentScreenOpened = () => {};

  @override
  onStart(Marker m) async {
    await _onboard.fetch(m);

    /// The Adapty init handling is convoluted because of how they handle profiles.
    /// We do not want to create unnecessary profiles.
    ///
    /// Init flow:
    /// - if existing account id from cloud storage has ever been active, use it
    /// - if account was never active (ie. new user), init without any account ID
    ///
    /// After init:
    /// - pass account id to Adapty if it changes, and has been active before
    _accountEphemeral.onChangeInstant((it) async {
      if (it.now.hasBeenActiveBefore()) {
        if (!_adaptyInitialized) {
          // Initialise Adapty with account ID, if account has been active before
          log(it.m).log(
            msg: "Adapty: initialising",
            attr: {"accountId": it.now.id},
            sensitive: true,
          );
          _adaptyInitialized = true;
          await _channel.init(it.m, _key.get(), it.now.id, !Core.act.isRelease);
        } else {
          // Pass account ID to Adapty on change, whenever active
          log(it.m).log(
            msg: "Adapty: identifying",
            attr: {"accountId": it.now.id},
            sensitive: true,
          );
          await _channel.identify(it.now.id);
        }
      } else {
        if (!_adaptyInitialized) {
          // Initialise Adapty with no account ID provided (never active)
          log(it.m).log(msg: "Adapty: initialising without accountId");
          _adaptyInitialized = true;
          await _channel.init(it.m, _key.get(), it.now.id, !Core.act.isRelease);
        } else {
          // Inactive account: changed manually, or new load
        }
      }

      await _maybePreload(it);
    });

    // TODO: change to new Value type
    _account.addOn(accountChanged, _onAccountChanged);
  }

  _onAccountChanged(Marker m) async {
    if (_account.type.isActive()) {
      reportOnboarding(OnboardingStep.accountActivated);
    }
  }

  // Basic preload to avoid lag when tapping CTA
  // Only if Adapty is initialised and account is inactive
  // No expiration check, we assume user will open the paywall soon
  // And that adapty is ok with preloading
  _maybePreload(ValueUpdate<AccountState> it) async {
    if (!_preloaded && _preloadCompleter == null && _adaptyInitialized && !it.now.type.isActive()) {
      _preloadCompleter = Completer();
      try {
        await _channel.preload(it.m, Placement.primary);
        log(it.m).i("Adapty: preloaded paywall");
      } catch (e, s) {
        log(it.m).e(msg: "Adapty: failed preloading", err: e, stack: s);
      } finally {
        // No matter what we mark it as done
        _preloaded = true;
        _preloadCompleter?.complete();
        _preloadCompleter = null;
      }
    }
  }

  reportOnboarding(OnboardingStep step, {bool reset = false}) async {
    final current = await _onboard.now();
    if (current == null || current.order < step.order || reset) {
      // Next step reached, report it
      await log(Markers.ui).trace("reportOnboarding", (m) async {
        await _channel.logOnboardingStep("primaryOnboard", step);
        await _onboard.change(m, step);
      });
    }
  }

  openPaymentScreen(Marker m, {Placement placement = Placement.primary}) async {
    return await log(m).trace("openPaymentScreen", (m) async {
      if (_isOpened) return;
      _isOpened = true;
      await _preloadCompleter?.future;
      try {
        await _channel.showPaymentScreen(m, placement, forceReload: false);
        onPaymentScreenOpened();
        await reportOnboarding(OnboardingStep.ctaTapped);
      } catch (e, s) {
        _isOpened = false;
        await handleFailure(m, "Failed creating paywall", e,
            s: s, temporary: true);
      }
    });
  }

  closePaymentScreen() async {
    await _channel.closePaymentScreen();
    handleScreenClosed();
  }

  checkoutSuccessfulPayment(String profileId, {bool restore = false}) async {
    await log(Markers.ui).trace("checkoutSuccessfulPayment", (m) async {
      try {
        final account = await _api.postCheckout(m, profileId);

        final type = AccountType.values.byName(account.type ?? "unknown");
        await _account.propose(account, m);
        if (!type.isActive()) throw Exception("Account inactive after restore");

        log(m).log(
          msg: "purchased/restored active account",
          attr: {"accountId": account.id},
          sensitive: true,
        );

        // TODO: make it for both not only family
        if (Core.act.isFamily) {
          await _family.activateCta(m);
        }
      } catch (e, s) {
        await handleFailure(m, "Failed checkout", e, s: s, restore: restore);
      }
    });
  }

  handleFailure(Marker m, String msg, Object e,
      {StackTrace? s, bool restore = false, bool temporary = false}) async {
    log(m).e(msg: "Adapty: $msg", err: e, stack: s);

    var sheet = StageModal.paymentFailed;
    if (restore) {
      sheet = StageModal.accountRestoreFailed;
    } else if (temporary) {
      sheet = StageModal.paymentTempUnavailable;
    }

    await sleepAsync(const Duration(seconds: 1));
    await _stage.showModal(sheet, m);
  }

  handleScreenClosed() {
    log(Markers.ui).i("Payment screen closed");
    _isOpened = false;
  }
}
