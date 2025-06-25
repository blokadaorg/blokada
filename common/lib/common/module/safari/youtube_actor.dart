part of 'safari.dart';

/// Handles state sync between the app and the Safari YouTube extension (blockaweb).
/// Also decides if it's necessary to show the onboarding screen for the extension.
class SafariYoutubeActor with Actor, Logging {
  late final _scheduler = Core.get<Scheduler>();
  late final _app = Core.get<AppStore>();
  late final _account = Core.get<AccountEphemeral>();
  late final _onboardSafari = Core.get<OnboardSafariValue>();
  late final _channel = Core.get<SafariChannel>();
  late final _onboardActor = Core.get<OnboardActor>();
  late final _perm = Core.get<PlatformPermActor>();
  late final _dnsEnabledFor = Core.get<PrivateDnsEnabledForValue>();

  late final _modal = Core.get<CurrentModalValue>();
  late final _modalWidget = Core.get<CurrentModalWidgetValue>();

  late final _appStatus = Core.get<BlockawebAppStatusValue>();
  late final _ping = Core.get<BlockawebPingValue>();

  DateTime _accountActiveUntil = DateTime(0);
  bool _appActive = false;
  bool _freemium = false;
  DateTime? _freemiumYoutubeUntil;

  @override
  onCreate(Marker m) async {
    // Provide the widget factory for the modal this module handles
    _modal.onChange.listen((it) {
      if (it.now == Modal.onboardSafariYoutube) {
        _modalWidget.change(it.m, (context) => const SafariYoutubeOnboardSheetIos());
      }
    });
  }

  @override
  onStart(Marker m) async {
    await _appStatus.fetch(m);

    reactionOnStore((_) => _app.status, (retention) async {
      _appActive = _app.status.isActive();
      await _scheduleSync(m);
    });

    _account.onChangeInstant(_updateStatusFromAccount);
    _dnsEnabledFor.onChangeInstant(showSafariYoutubeOnboard);
  }

  // Safari Youtube onboard in iOS, after DNS perms are granted (but only once)
  showSafariYoutubeOnboard(NullableValueUpdate<DeviceTag> it) async {
    if (Core.act.platform != PlatformType.iOS) return;
    return await log(it.m).trace("maybeShowSafariYoutubeOnboard", (m) async {
      final dnsEnabled = _perm.isPrivateDnsEnabled;
      final needsOnboard = await _needsOnboard(m);
      if (dnsEnabled && needsOnboard) {
        await _modal.change(m, Modal.onboardSafariYoutube);
      }
    });
  }

  Future<bool> _needsOnboard(Marker m) async {
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
    _accountActiveUntil = DateTime.tryParse(it.now.jsonAccount.activeUntil ?? "") ?? DateTime(0);

    // Extract freemium attributes from account
    final attributes = it.now.jsonAccount.attributes ?? {};
    _freemium = attributes['freemium'] as bool? ?? false;

    if (attributes['freemium_youtube_until'] != null) {
      _freemiumYoutubeUntil = DateTime.tryParse(attributes['freemium_youtube_until'] as String);
    } else {
      _freemiumYoutubeUntil = null;
    }

    await _scheduleSync(it.m);
  }

  _scheduleSync(Marker m) async {
    await _scheduler.addOrUpdate(Job(
      "safari:youtube:sync",
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

  doOpenPermsFlow() async {
    await _channel.doOpenPermsFlowForContentFilter();
  }

  markOnboardSeen(Marker m) async {
    _onboardActor.markSafariYoutubeSeen(m);
  }
}
