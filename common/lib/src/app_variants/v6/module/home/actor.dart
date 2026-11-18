part of 'home.dart';

/// A value that holds null, which here means "no trial line".
class TrialHomeValue<T> {
  T _now;
  final _changes = StreamController<T>.broadcast();

  TrialHomeValue(this._now);

  T get now => _now;

  set now(T value) {
    if (value == _now) return;
    _now = value;
    _changes.add(value);
  }

  Stream<T> get onChange => _changes.stream;
}

/// Loads what Home's trial line shows: the store trial and what Blokada
/// blocked since it started.
///
/// Home calls it only while it is on screen; nothing here runs at startup,
/// so the store's profile read never delays launch.
class TrialHomeActor with Logging, Actor {
  late final _account = Core.get<AccountStore>();
  late final _payment = Core.get<PaymentChannel>();
  late final _statsStore = Core.get<StatsStore>();
  late final _stats = Core.get<StatsController>();

  /// The store free trial, or null outside one.
  final trial = TrialHomeValue<TrialProgress?>(null);

  /// Requests blocked since the trial started; null until loaded.
  final trialBlocked = TrialHomeValue<int?>(null);

  /// Bumped when the account switches; a load started for the previous
  /// account drops its result instead of showing that account's trial.
  int _generation = 0;

  /// Per-loader request counters: when calls of one loader overlap, only the
  /// latest one publishes.
  int _trialRead = 0;
  int _trialBlockedRead = 0;

  /// The count is summed from two weeks of daily stats; once the trial
  /// started earlier than that it would leave out the first days, so the
  /// line shows the day only.
  static const _countedHistory = Duration(days: 13);

  /// The refresh an account listener started last, for tests: the
  /// listeners do not wait for it (see [onAccountChanged]).
  @visibleForTesting
  Future<void>? lastBackgroundRefresh;

  @override
  Future<void> onStart(Marker m) async {
    _account.addOn(accountChanged, onAccountChanged);
    _account.addOn(accountIdChanged, onAccountIdChanged);
  }

  bool _publish(int generation, void Function() write, {bool latest = true}) {
    if (generation != _generation || !latest) return false;
    write();
    return true;
  }

  /// Whether the account was active on the last account change; null before
  /// the first.
  bool? _wasActive;

  /// A trial that converts or lapses, or a purchase that starts one, changes
  /// the account: re-read it then. An account that can no longer have the
  /// line clears it at once, which also drops a store read still running.
  /// Every other account refresh (each app foreground) skips the store read;
  /// Home reads the trial when it shows.
  ///
  /// Checkout and restore wait for the account listeners, so the read runs
  /// in the background rather than holding them up.
  @visibleForTesting
  Future<void> onAccountChanged(Marker m) async {
    final active = _account.type.isActive();
    final becameActive = active && _wasActive == false;
    _wasActive = active;
    if (_eligible && trial.now == null && !becameActive) return;
    _refreshInBackground(m);
  }

  /// Another account (a restore): nothing loaded for the previous one may
  /// stay on screen. The read on [accountChanged] ran before this reset, so
  /// it is read again.
  @visibleForTesting
  Future<void> onAccountIdChanged(Marker m) async {
    _generation++;
    trial.now = null;
    trialBlocked.now = null;
    _refreshInBackground(m);
  }

  bool get _eligible => _account.type.isActive() && !_account.isFreemium;

  void _refreshInBackground(Marker m) {
    final refresh = refreshTrial(m).catchError((Object e, StackTrace s) {
      log(m).e(msg: "trialHome: background refresh failed", err: e, stack: s);
    });
    lastBackgroundRefresh = refresh;
    unawaited(refresh);
  }

  /// Re-reads the store's access levels for the trial line. Any failure only
  /// hides the line.
  Future<void> refreshTrial(Marker m) async {
    final generation = _generation;
    final read = ++_trialRead;
    if (!_eligible) {
      _publish(generation, () => trial.now = null);
      await refreshTrialBlocked(m);
      return;
    }
    TrialProgress? progress;
    try {
      final subscriptions = await _payment.fetchActiveSubscriptions(m);
      progress = resolveTrialProgress(subscriptions, accountId: _account.id);
    } catch (e, s) {
      log(m).e(msg: "trialHome: failed reading trial", err: e, stack: s);
      progress = null;
    }
    final published = _publish(generation, () {
      // A count summed for another trial start must not sit next to this
      // one's day while it is summed again.
      if (progress?.startedAt != trial.now?.startedAt) trialBlocked.now = null;
      trial.now = progress;
    }, latest: read == _trialRead);
    if (!published) return;
    await refreshTrialBlocked(m);
  }

  /// Re-sums what was blocked since the trial started; Home calls it with
  /// each stats refresh. The two week stats are cached, so this is cheap.
  Future<void> refreshTrialBlocked(Marker m) async {
    final generation = _generation;
    final read = ++_trialBlockedRead;
    final progress = trial.now;
    if (progress == null || DateTime.now().difference(progress.startedAt) > _countedHistory) {
      _publish(generation, () => trialBlocked.now = null);
      return;
    }
    int? blocked;
    try {
      final since = await _statsStore.blockedSince(m, progress.startedAt, accountId: _account.id);
      // The daily buckets fill in with a lag, so today's blocks may be in the
      // hourly stats only: never show less than the last 24 hours.
      blocked = since == null ? null : trialBlockedSoFar(since, _stats.stats.now.data);
    } catch (e, s) {
      log(m).e(msg: "trialHome: failed reading trial blocks", err: e, stack: s);
      blocked = null;
    }
    _publish(generation, () => trialBlocked.now = blocked, latest: read == _trialBlockedRead);
  }
}
