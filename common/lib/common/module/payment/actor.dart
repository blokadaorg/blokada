part of 'payment.dart';

// Emitted when user successfully finishes the payment flow
// True if the payment was restore flow (could be non-user triggered)
final paymentSuccessful = EmitterEvent<bool>("paymentSuccessful");

enum Placement {
  primary("primary"),
  plusUpgrade("home_plus_upgrade"),
  freemiumStats("stats_freemium"),
  freemiumActivity("activity_freemium"),
  freemiumFilters("filters_freemium");

  final String id;

  const Placement(this.id);
}

class PaymentActor with Actor, Logging, ValueEmitter<bool> {
  late final _accountEphemeral = Core.get<api.AccountEphemeral>();
  late final _account = Core.get<AccountStore>();
  late final _api = Core.get<PaymentApi>();
  late final _onboard = Core.get<CurrentOnboardingStepValue>();
  late final _stage = Core.get<StageStore>();
  late final _channel = Core.get<PaymentChannel>();
  late final _key = Core.get<AdaptyApiKey>();

  bool _adaptyInitialized = false;
  Completer? _preloadCompleter = Completer();
  bool _isOpened = false;
  OnboardingStep? _pendingOnboard;

  Function onPaymentScreenOpened = (bool opened) => {};

  @override
  onCreate(Marker m) async {
    willAcceptOnValue(paymentSuccessful);
  }

  @override
  onStart(Marker m) async {
    await _onboard.fetch(m);

    /// Wait once account is available because we need to do the init as a part
    /// of the startup sequence (meaning we have to block in this call).
    /// We want to make sure the sub restore was tried before user continues.
    final account = await _accountEphemeral.fetch(m);

    /// The Adapty init handling is convoluted because of how they handle profiles.
    /// We do not want to create unnecessary profiles.
    ///
    /// Init flow:
    /// - if existing account id from cloud storage has ever been active, use it
    /// - if account was never active (ie. new user), init without any account ID
    if (account.hasBeenActiveBefore()) {
      // Initialise Adapty with account ID, if account has been active before
      log(m).log(
        msg: "Adapty: initialising",
        attr: {"accountId": account.id},
        sensitive: true,
      );
      _adaptyInitialized = true;
      await _channel.init(m, _key.get(), account.id, !Core.act.isRelease);
      await _syncCustomAttributes(m, account);
      await reportOnboarding(_pendingOnboard);
    } else {
      // Initialise Adapty with no account ID provided (never active)
      log(m).log(msg: "Adapty: initialising without accountId");
      _adaptyInitialized = true;
      await _channel.init(m, _key.get(), account.id, !Core.act.isRelease);
      await _syncCustomAttributes(m, account);
      await reportOnboarding(_pendingOnboard);
    }

    /// After init:
    /// - pass account id to Adapty if it changes, and has been active before
    _accountEphemeral.onChangeInstant((it) async {
      if (it.now.hasBeenActiveBefore()) {
        if (_adaptyInitialized) {
          // Pass account ID to Adapty on change, whenever active
          log(it.m).log(
            msg: "Adapty: identifying",
            attr: {"accountId": it.now.id},
            sensitive: true,
          );
          await _channel.identify(it.now.id);
          await _syncCustomAttributes(it.m, it.now);
        }
      }
    });

    // TODO: change to new Value type
    _account.addOn(accountChanged, _onAccountChanged);

    // Do the preload once on start, and await as a part of the startup sequence
    await _maybePreload(m, account);
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
  _maybePreload(Marker m, AccountState account) async {
    if (_adaptyInitialized && !account.type.isActive()) {
      _preloadCompleter ??= Completer();
      try {
        await _channel.preload(m, Placement.primary);
        log(m).i("Adapty: preloaded paywall");
      } catch (e, s) {
        log(m).e(msg: "Adapty: failed preloading", err: e, stack: s);
      }
    }

    // No matter what we mark it as done
    _preloadCompleter?.complete();
    _preloadCompleter = null;
  }

  reportOnboarding(OnboardingStep? step, {bool reset = false}) async {
    if (step == null) return;
    final current = await _onboard.now();
    if (current == null || current.order < step.order || reset) {
      // Next step reached, report it
      await log(Markers.ui).trace("reportOnboarding", (m) async {
        if (!_adaptyInitialized) {
          log(m).w("Adapty not initialised, queuing onboarding step");
          _pendingOnboard = step;
          return;
        }

        _pendingOnboard = null;
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
        onPaymentScreenOpened(true);
        await reportOnboarding(OnboardingStep.ctaTapped);
      } catch (e, s) {
        onPaymentScreenOpened(false);
        _isOpened = false;
        await handleFailure(m, "Failed creating paywall", e, s: s, temporary: true);
      }
    });
  }

  closePaymentScreen(Marker m) async {
    return await log(m).trace("closePaymentScreen", (m) async {
      await _channel.closePaymentScreen();
      handleScreenClosed(m);
    });
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

        await emitValue(paymentSuccessful, restore, m);
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

  handleScreenClosed(Marker m) {
    log(m).i("Payment screen closed");
    onPaymentScreenOpened(false);
    _isOpened = false;
  }

  _syncCustomAttributes(Marker m, AccountState account) async {
    final attributes = account.jsonAccount.attributes;
    if (attributes == null || attributes.isEmpty) {
      return; // No attributes to sync
    }

    try {
      // Process attributes using Flutter converter
      final processedAttributes = AdaptyAttributeConverter.convertToCustomAttributes(attributes);

      if (processedAttributes.isEmpty) {
        log(m).i("No valid attributes to sync after processing");
        return;
      }

      // Pass processed attributes to platform channel
      await _channel.setCustomAttributes(m, {'custom_attributes': processedAttributes});
      log(m).i("Synced custom attributes to Adapty");
    } catch (e, s) {
      log(m).e(msg: "Failed syncing custom attributes", err: e, stack: s);
      // Don't fail the initialization for this
    }
  }
}
