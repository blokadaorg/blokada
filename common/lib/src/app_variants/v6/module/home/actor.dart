part of 'home.dart';

/// One section of the daily Home: the current value and its changes. Unlike
/// [Value] it holds null, which here means "nothing to show".
class DailyHomeValue<T> {
  T _now;
  final _changes = StreamController<T>.broadcast();

  DailyHomeValue(this._now);

  T get now => _now;

  set now(T value) {
    if (value == _now) return;
    _now = value;
    _changes.add(value);
  }

  Stream<T> get onChange => _changes.stream;
}

/// Today's headline pick, kept across restarts so the headline does not
/// change through the day.
class HomeHeadlinePickValue extends JsonPersistedValue<HomeHeadlinePick> {
  HomeHeadlinePickValue() : super('home:headline_pick');

  @override
  Map<String, dynamic> toJson(HomeHeadlinePick value) => value.toJson();

  // An unreadable pick (an older build's kind) counts as from no day, so
  // today's pick is made afresh.
  @override
  HomeHeadlinePick fromJson(Map<String, dynamic> json) =>
      HomeHeadlinePick.fromJson(json) ?? const HomeHeadlinePick('', HomeHeadlineKind.weekly);
}

/// Mocked builds only: forces the Home variant, so both arms can be shown on
/// the simulator without changing the dev account (see ios/SIMULATOR.md).
const _mockHomeVariant = String.fromEnvironment('MOCK_HOME_VARIANT');

/// Loads what the daily Home (#460) shows beyond the existing stats: the
/// trial line, today's headline, when the last block happened and, once the
/// subscription ended, what Blokada blocked in total. It also decides which
/// Home an account gets.
///
/// Home calls it only while it is on screen; nothing here runs at startup,
/// so the store's profile read never delays launch.
class DailyHomeActor with Logging, Actor {
  late final _account = Core.get<AccountStore>();
  late final _payment = Core.get<PaymentChannel>();
  late final _statsStore = Core.get<StatsStore>();
  late final _stats = Core.get<StatsController>();
  late final _device = Core.get<DeviceStore>();
  late final _journal = Core.get<JournalActor>();
  late final _toplists = Core.get<ToplistStore>();
  late final _pick = Core.get<HomeHeadlinePickValue>();

  /// The store free trial, or null outside one.
  final trial = DailyHomeValue<TrialProgress?>(null);

  /// Requests blocked since the trial started; null until loaded.
  final trialBlocked = DailyHomeValue<int?>(null);

  /// Today's headline; null means the 24 hour counter takes its place.
  final headline = DailyHomeValue<HomeHeadline?>(null);

  /// When the last request was blocked; only known with activity logging on.
  final lastBlockAt = DailyHomeValue<DateTime?>(null);

  /// All-time blocked count for the expired card; null when unknown.
  final expiredBlocked = DailyHomeValue<int?>(null);

  /// Accounts seen in the daily cohort this session. A refresh that drops
  /// the attributes (an offline expiry used to) must not flip the layout
  /// under the user.
  final _dailyAccounts = <String>{};

  /// The weekly event computed today, so the generation (a two week stats
  /// fetch and four toplists) runs at most once a day.
  String? _weeklyDay;
  WeeklyReportEvent? _weeklyEvent;

  bool _headlineLoading = false;

  @override
  Future<void> onStart(Marker m) async {
    _account.addOn(accountChanged, _onAccountChanged);
  }

  Future<void> _onAccountChanged(Marker m) async {
    // A trial that converts or lapses changes the account; drop a stale line.
    if (!_account.type.isActive()) {
      trial.now = null;
      trialBlocked.now = null;
    }
  }

  /// The Home variant for [account]. Mocked builds may force it with the
  /// MOCK_HOME_VARIANT define.
  HomeVariant variantFor(AccountState? account) {
    if (Core.act.isMocked && _mockHomeVariant.isNotEmpty) {
      return HomeVariant.fromApiValue(_mockHomeVariant);
    }
    if (account == null) return HomeVariant.control;
    if (_dailyAccounts.contains(account.id)) return HomeVariant.daily;
    final variant = account.jsonAccount.getHomeVariant();
    if (variant == HomeVariant.daily) _dailyAccounts.add(account.id);
    return variant;
  }

  /// The daily Home with protection on came on screen.
  Future<void> onActiveShown(Marker m) async {
    return await log(m).trace("homeDaily:shown", (m) async {
      await Future.wait([refreshTrial(m), refreshHeadline(m), refreshLastBlock(m)]);
    });
  }

  /// Re-reads the store's access levels for the trial line. Any failure only
  /// hides the line.
  Future<void> refreshTrial(Marker m) async {
    if (!_account.type.isActive()) {
      trial.now = null;
      trialBlocked.now = null;
      return;
    }
    TrialProgress? progress;
    try {
      final subscriptions = await _payment.fetchActiveSubscriptions(m);
      progress = resolveTrialProgress(subscriptions, accountId: _account.id, now: DateTime.now());
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading trial", err: e, stack: s);
      progress = null;
    }
    trial.now = progress;
    if (progress == null) {
      trialBlocked.now = null;
      return;
    }
    try {
      trialBlocked.now = await _statsStore.blockedSince(m, progress.startedAt);
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading trial blocks", err: e, stack: s);
      trialBlocked.now = null;
    }
  }

  /// Rebuilds the headline candidates and applies today's pick. Cheap after
  /// the first call of the day: the toplist is cached and the weekly event is
  /// computed once a day.
  Future<void> refreshHeadline(Marker m) async {
    if (_headlineLoading) return;
    _headlineLoading = true;
    try {
      final now = DateTime.now();
      final today = homeHeadlineDay(now);
      final candidates = <HomeHeadline>[];

      final stats = _stats.stats.now.data;
      if (stats != null) {
        final busiest = busiestHourHeadline(stats, now);
        if (busiest != null) candidates.add(busiest);
      }

      final top = await _topBlocked(m);
      if (top != null) candidates.add(top);

      final weekly = await _weekly(m, today);
      if (weekly != null) candidates.add(weeklyHeadline(weekly));

      final previous = await _pick.fetch(m);
      final result = pickHomeHeadline(candidates, previous: previous, today: today);
      if (result != null &&
          (previous?.day != result.pick.day || previous?.kind != result.pick.kind)) {
        await _pick.change(m, result.pick);
      }
      headline.now = result?.headline;
      log(m).pair("homeHeadline", result?.headline.kind.name ?? "none");
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed building headline", err: e, stack: s);
    } finally {
      _headlineLoading = false;
    }
  }

  /// The most blocked domain in the last 24 hours. Toplists exist only with
  /// activity logging on.
  Future<HomeHeadline?> _topBlocked(Marker m) async {
    if (_device.retention != "24h") return null;
    final deviceName = _device.deviceAlias;
    if (deviceName.isEmpty) return null;
    try {
      final response = await _toplists.fetch(
        m: m,
        deviceName: deviceName,
        level: 1,
        action: "blocked",
        limit: 1,
        range: "24h",
        ttl: const Duration(minutes: 10),
      );
      final entry = response.toplist.expand((bucket) => bucket.entries).firstOrNull;
      return topBlockedHeadline(entry?.name, entry?.count ?? 0);
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading toplist", err: e, stack: s);
      return null;
    }
  }

  /// Today's best Privacy Pulse weekly event, generated once a day. It does
  /// not touch the weekly notification's own pick.
  Future<WeeklyReportEvent?> _weekly(Marker m, String today) async {
    if (_weeklyDay == today) return _weeklyEvent;
    WeeklyReportEvent? best;
    final context = WeeklyReportGenerationContext(WeeklyReportRepository());
    for (final source in [WeeklyTotalsDeltaSource(), ToplistMovementSource()]) {
      try {
        final events = await source.generate(context, m);
        for (final event in events) {
          if (best == null || event.score > best.score) best = event;
        }
      } catch (e, s) {
        log(m).e(msg: "homeDaily: weekly source ${source.name} failed", err: e, stack: s);
      }
    }
    _weeklyDay = today;
    _weeklyEvent = best;
    return best;
  }

  /// When the last request was blocked, from the journal. Without activity
  /// logging there is no journal, and the status line shows today's count.
  Future<void> refreshLastBlock(Marker m) async {
    if (_device.retention != "24h") {
      lastBlockAt.now = null;
      return;
    }
    try {
      final entries = await _journal.fetchPreview(
        m,
        action: UiJournalAction.block,
        deviceName: _device.deviceAlias,
        limit: 1,
      );
      lastBlockAt.now = entries.firstOrNull?.timestamp;
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading last block", err: e, stack: s);
    }
  }

  /// Loads the all-time blocked count once for the expired card. The Home
  /// refresh timer only runs while protection is on, so it has to ask.
  Future<void> refreshExpired(Marker m) async {
    try {
      await _statsStore.fetchDay(m);
      expiredBlocked.now = _statsStore.hasStats ? _statsStore.stats.totalBlocked : null;
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading expired total", err: e, stack: s);
      expiredBlocked.now = null;
    }
  }
}
