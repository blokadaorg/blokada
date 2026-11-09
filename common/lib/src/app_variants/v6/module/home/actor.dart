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

  /// The scope every load runs in. Bumped when the account switches or
  /// activity logging is turned on or off; a load started in an older scope
  /// drops its result (see [_publish]) instead of showing the previous
  /// account's data, or domains the user just stopped logging.
  int _generation = 0;

  /// Activity logging as last seen on a device refresh; null until the first.
  bool? _seenLogging;

  /// Per-loader request counters: when calls of one loader overlap, only the
  /// latest one publishes.
  int _trialRead = 0;
  int _trialBlockedRead = 0;
  int _lastBlockRead = 0;

  /// The scope the running headline load belongs to, or null when none runs.
  /// A refresh for a newer scope still runs; the older one drops its result.
  int? _headlineLoadingFor;

  /// Trials longer than the two weeks of daily stats get no count, which
  /// would leave out their first days.
  static const _maxCountedTrialDays = 14;

  @override
  Future<void> onStart(Marker m) async {
    _account.addOn(accountChanged, _onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);
    _device.addOn(deviceChanged, onDeviceChanged);
  }

  bool get _logging => _device.retention == "24h";

  /// The single gate for every load's result, on success and failure alike:
  /// [write] runs only while [generation] is the current scope and, for
  /// loaders whose calls overlap, this call is still the [latest].
  bool _publish(int generation, void Function() write, {bool latest = true}) {
    if (generation != _generation || !latest) return false;
    write();
    return true;
  }

  /// A headline that names domains, which only activity logging may show.
  static bool _namesDomains(HomeHeadline headline) =>
      headline.kind == HomeHeadlineKind.topBlocked ||
      headline.weekly?.type == WeeklyReportEventType.toplistChange;

  /// A trial that converts or lapses changes the account: re-read it. Only
  /// the daily cohort shows a trial, so nobody else pays for the store read.
  Future<void> _onAccountChanged(Marker m) async {
    if (variantFor(_account.account) != HomeVariant.daily) return;
    await refreshTrial(m);
  }

  /// Another account (a restore): nothing loaded for the previous one may
  /// stay on screen, including a headline naming its domains. The trial read
  /// on [accountChanged] ran before this reset, so it is read again.
  @visibleForTesting
  Future<void> onAccountIdChanged(Marker m) async {
    _generation++;
    _weeklyDay = null;
    _weeklyEvent = null;
    trial.now = null;
    trialBlocked.now = null;
    headline.now = null;
    lastBlockAt.now = null;
    expiredBlocked.now = null;
    await _onAccountChanged(m);
  }

  /// Activity logging turned on or off: loads still running were started
  /// under the old setting. Turning it off also hides what it allowed. The
  /// headline and last block load again with the next stats refresh.
  @visibleForTesting
  Future<void> onDeviceChanged(Marker m) async {
    final logging = _logging;
    final seen = _seenLogging;
    _seenLogging = logging;
    // The first refresh only tells the setting, it does not change it.
    if (seen == null || seen == logging) return;
    _generation++;
    _weeklyDay = null;
    _weeklyEvent = null;
    if (!logging) {
      final shown = headline.now;
      if (shown != null && _namesDomains(shown)) headline.now = null;
      lastBlockAt.now = null;
    }
    // The bump also dropped any trial read in flight, which logging does not
    // affect.
    await _onAccountChanged(m);
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
    final generation = _generation;
    final read = ++_trialRead;
    if (!_account.type.isActive()) {
      _publish(generation, () => trial.now = null);
      await refreshTrialBlocked(m);
      return;
    }
    TrialProgress? progress;
    try {
      final subscriptions = await _payment.fetchActiveSubscriptions(m);
      progress = resolveTrialProgress(subscriptions, accountId: _account.id);
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading trial", err: e, stack: s);
      progress = null;
    }
    if (!_publish(generation, () => trial.now = progress, latest: read == _trialRead)) return;
    await refreshTrialBlocked(m);
  }

  /// Re-sums what was blocked since the trial started; Home calls it with
  /// each stats refresh. The two week stats are cached, so this is cheap.
  Future<void> refreshTrialBlocked(Marker m) async {
    final generation = _generation;
    final read = ++_trialBlockedRead;
    final progress = trial.now;
    if (progress == null || progress.length > _maxCountedTrialDays) {
      _publish(generation, () => trialBlocked.now = null);
      return;
    }
    int? blocked;
    try {
      final since = await _statsStore.blockedSince(m, progress.startedAt);
      // The daily buckets fill in with a lag, so today's blocks may be in the
      // hourly stats only: never show less than the last 24 hours.
      blocked = since == null ? null : trialBlockedSoFar(since, _stats.stats.now.data);
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading trial blocks", err: e, stack: s);
      blocked = null;
    }
    _publish(generation, () => trialBlocked.now = blocked, latest: read == _trialBlockedRead);
  }

  /// Rebuilds the headline candidates and applies today's pick. Cheap after
  /// the first call of the day: the toplist is cached and the weekly event is
  /// computed once a day.
  Future<void> refreshHeadline(Marker m) async {
    final generation = _generation;
    if (_headlineLoadingFor == generation) return;
    _headlineLoadingFor = generation;
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

      if (generation != _generation) return;
      final previous = await _pick.fetch(m);
      if (generation != _generation) return;
      // Logging may have been turned off while the candidates loaded.
      if (!_logging) candidates.removeWhere(_namesDomains);
      final result = pickHomeHeadline(candidates, previous: previous, today: today);
      if (result != null &&
          (previous?.day != result.pick.day || previous?.kind != result.pick.kind)) {
        await _pick.change(m, result.pick);
      }
      final shown = result?.headline;
      final published = _publish(generation, () {
        headline.now = shown != null && _namesDomains(shown) && !_logging ? null : shown;
      });
      if (published) log(m).pair("homeHeadline", headline.now?.kind.name ?? "none");
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed building headline", err: e, stack: s);
    } finally {
      if (_headlineLoadingFor == generation) _headlineLoadingFor = null;
    }
  }

  /// The most blocked domain in the last 24 hours. Toplists exist only with
  /// activity logging on.
  Future<HomeHeadline?> _topBlocked(Marker m) async {
    if (!_logging) return null;
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
  /// not touch the weekly notification's own pick. The caller drops a
  /// toplist event while logging is off.
  Future<WeeklyReportEvent?> _weekly(Marker m, String today) async {
    if (_weeklyDay == today) return _weeklyEvent;
    WeeklyReportEvent? best;
    final generation = _generation;
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
    // Totals that failed to load (offline, no device name yet) are not "no
    // event today": leave the day uncached so the next refresh tries again.
    final loaded = await context.totals(m) != null;
    final cached = _publish(generation, () {
      if (!loaded) return;
      _weeklyDay = today;
      _weeklyEvent = best;
    });
    return cached ? best : null;
  }

  /// When the last request was blocked, from the journal. Without activity
  /// logging there is no journal, and the status line shows today's count.
  Future<void> refreshLastBlock(Marker m) async {
    final generation = _generation;
    final read = ++_lastBlockRead;
    if (!_logging) {
      _publish(generation, () => lastBlockAt.now = null);
      return;
    }
    try {
      final entries = await _journal.fetchPreview(
        m,
        action: UiJournalAction.block,
        deviceName: _device.deviceAlias,
        limit: 1,
      );
      _publish(generation, () {
        lastBlockAt.now = _logging ? entries.firstOrNull?.timestamp : null;
      }, latest: read == _lastBlockRead);
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading last block", err: e, stack: s);
    }
  }

  /// Loads the all-time blocked count once for the expired card. The Home
  /// refresh timer only runs while protection is on, so it has to ask.
  Future<void> refreshExpired(Marker m) async {
    final generation = _generation;
    int? total;
    try {
      await _statsStore.fetchDay(m);
      total = _statsStore.hasStats ? _statsStore.stats.totalBlocked : null;
    } catch (e, s) {
      log(m).e(msg: "homeDaily: failed reading expired total", err: e, stack: s);
      total = null;
    }
    _publish(generation, () => expiredBlocked.now = total);
  }
}
