part of 'safari.dart';

/// Handles state sync between the app and the Safari extension (blockaweb).
/// Also decides if it's necessary to show the onboarding screen for the extension.
///
/// There are two main cases / flows for the safari extension:
/// - optional flow: for active accounts, the extension is optional and mostly about YT
/// - mandatory flow: for freemium accounts, the extension is mandatory
class SafariActor with Actor, Logging {
  // Deps for both flows
  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();
  late final _app = Core.get<AppStore>();
  late final _channel = Core.get<SafariChannel>();
  late final _appStatus = Core.get<BlockawebAppStatusValue>();
  late final _ping = Core.get<BlockawebPingValue>();
  late final _stage = Core.get<StageStore>();
  late final _perm = Core.get<PlatformPermActor>();

  // Deps for the optional flow
  late final _scheduler = Core.get<Scheduler>();
  late final _account = Core.get<AccountEphemeral>();
  late final _onboardSafari = Core.get<OnboardSafariValue>();
  late final _onboardActor = Core.get<OnboardActor>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();

  // Deps for the mandatory flow
  late final _accountStore = Core.get<AccountStore>();
  late final _payment = Core.get<PaymentActor>();

  DateTime _accountActiveUntil = DateTime(0);
  bool _appActive = false;
  bool _freemium = false;
  DateTime? _freemiumYoutubeUntil;

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardSafari) {
        _modalWidget.change(it.m, (context) => const SafariOnboardSheetIos());
      } else if (it.now == Modal.onboardSafariYoutube) {
        _modalWidget.change(it.m, (context) => const SafariOnboardYtSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    await _appStatus.fetch(m);

    reactionOnStore((_) => _app.status, (retention) async {
      _appActive = _app.status.isActive();
      await _scheduleSyncBlockaweb(m);
    });

    _dnsEnabledFor.onChangeInstant(_maybeShowOptionalOnboard);
    _account.onChangeInstant(_updateStatusFromAccount);

    _payment.addOnValue(paymentClosed, _maybeShowMandatoryOnboard);

    _stage.addOnValue(routeChanged, (route, m) async {
      if (!route.isBecameForeground()) return;
      _scheduleSyncFreemiumState(m);
    });

    await _scheduleSyncFreemiumState(m);
  }

  // Opens the browser url that leads to extension installation
  openSafariSetup() async {
    await _channel.doOpenSafariSetup();
  }

  // Optional flow will show only once
  markOptionalOnboardSeen(Marker m) async {
    _onboardActor.markSafariYoutubeSeen(m);
  }

  // Safari optional (YT) onboard in iOS, after DNS perms are granted (but only once)
  _maybeShowOptionalOnboard(NullableValueUpdate<DeviceTag> it) async {
    if (!Core.act.isIos) return;
    return await log(it.m).trace("maybeShowSafariOptionalOnboard", (m) async {
      final dnsEnabled = _perm.isPrivateDnsEnabled;
      final needsOnboard = await _needsOptionalOnboard(m);
      if (dnsEnabled && needsOnboard) {
        await _modal.change(m, Modal.onboardSafariYoutube);
      }
    });
  }

  Future<bool> _needsOptionalOnboard(Marker m) async {
    final ping = await _ping.fetch(m);
    final userSkipped = await _onboardSafari.now();

    // Uer skipped onboarding, leave them alone
    if (userSkipped) return false;

    // Fresh onboarding case, show onboard
    if (ping == null) return true;

    // // Extension seen long ago, show onboard
    // final oneDayAgo = DateTime.now().subtract(const Duration(minutes: 5));
    // if (ping.timestamp.isBefore(oneDayAgo)) {
    //   return true;
    // }

    // Extension seen recently, no need to onboard
    return false;
  }

  _updateStatusFromAccount(ValueUpdate<AccountState> it) async {
    _accountActiveUntil = it.now.jsonAccount.getActiveUntil();
    _freemium = it.now.jsonAccount.isFreemium();
    _freemiumYoutubeUntil = it.now.jsonAccount.getFreemiumYoutubeUntil();
    await _scheduleSyncBlockaweb(it.m);
  }

  // Safari mandatory onboard on iOS, after paywall closed with purchase
  _maybeShowMandatoryOnboard(bool isError, Marker m) async {
    if (isError) return;
    return await log(m).trace("maybeShowMandatoryOnboard", (m) async {
      if (_app.status.isActive()) return;
      if (!_accountStore.isFreemium) return;

      final ping = await _ping.fetch(m, force: true);
      final isActive = _isPingValidAndActive(m, ping);
      if (!isActive) {
        await sleepAsync(const Duration(seconds: 1));
        await _modal.change(m, Modal.onboardSafari);
        return;
      }

      // Status is active, so we can proceed with the app state sync
      await _app.appPaused(false, m);
      await _app.reconfiguring(m);
      await _syncFreemiumStateOnForeground(m);
    });
  }

  // Syncs the app state with the blockaweb extension (using scheduler for debouncing)
  _scheduleSyncBlockaweb(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      "safari:sync:blockaweb",
      m,
      before: DateTime.now(),
      callback: _syncBlockaweb,
    ));
  }

  Future<bool> _syncBlockaweb(Marker m) async {
    final newStatus = JsonBlockaweb(
      timestamp: _accountActiveUntil,
      active: _appActive,
      freemium: _freemium,
      freemiumYoutubeUntil: _freemiumYoutubeUntil,
    );

    await _appStatus.change(m, newStatus);
    await _ping.fetch(m, force: true);
    return false;
  }

  // Syncs the app freemium state with the blockaweb extension (using scheduler for debouncing)
  _scheduleSyncFreemiumState(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      "safari:sync:freemium",
      m,
      before: DateTime.now(),
      callback: _syncFreemiumStateOnForeground,
    ));
  }

  Future<bool> _syncFreemiumStateOnForeground(Marker m) async {
    if (!_accountStore.isFreemium) return false;

    final ping = await _ping.fetch(m, force: true);
    final isActivated = _isPingValidAndActive(m, ping);

    if (isActivated && _app.status == AppStatus.activatedFreemium) return false;
    if (!isActivated && _app.status != AppStatus.activatedFreemium) return false;

    if (isActivated) {
      // Auto-unpause app only when Safari extension transitions from inactive to active
      // This handles the case where user completes Safari onboarding and returns to app
      // but NOT when user has explicitly turned off the app power
      if (!_app.conditions.freemiumEnabled && _app.conditions.appPaused) {
        // Will only ask if not granted
        await _perm.askNotificationPermissions(m, checkForPerms: true);

        // Auto-unpause the app since Safari extension is now active for the first time
        await _app.appPaused(false, m);
      }
    }

    await _app.freemiumActivated(m, isActivated);
    return false;
  }

  bool _isPingValidAndActive(Marker m, JsonBlockaweb? ping) {
    final isValid = _ping.isPingValidAndActive(ping);
    log(m).pair("ping timestamp valid", isValid);
    return isValid;
  }
}
