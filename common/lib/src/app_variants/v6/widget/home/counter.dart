import 'dart:async';

import 'package:common/src/features/stats/domain/controller.dart';
import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/counter.dart';
import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/minicard/summary.dart';
import 'package:common/src/shared/ui/placeholder.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

/// Home's "Last 24h" card: the number of requests blocked on this device in
/// the last 24 hours.
///
/// It stays mounted while protection is off (slid off screen by HomeActions),
/// so it asks [StatsController] to refresh only while protection is on, the
/// app is in the foreground and Home is not covered by another route. The
/// controller owns the fetching and the timer; the card only draws.
class HomeCounter extends StatefulWidget {
  const HomeCounter({super.key});

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter> with WidgetsBindingObserver, Logging {
  final _app = Core.get<AppStore>();
  final _stats = Core.get<StatsController>();

  double counter = 0.0;
  double lastCounter = 0.0;
  bool _hasStats = false;
  bool _error = false;

  bool _active = false;
  bool _foreground = true;
  bool _refreshing = false;
  ValueListenable<bool>? _tickerMode;
  StreamSubscription? _statsSub;

  final List<mobx.ReactionDisposer> _disposers = [];

  bool get _shouldRefresh => _active && _foreground && (_tickerMode?.value ?? true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Null before the first lifecycle event; a background launch reports a non-resumed state.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _active = _app.status.isActive();

    _disposers.add(
      mobx.reaction<bool>((_) => _app.status.isActive(), (active) {
        _active = active;
        // The placeholder only shimmers while protection is on.
        if (mounted) setState(() {});
        _syncRefresh();
      }),
    );

    _apply(_stats.stats.now, initial: true);
    _statsSub = _stats.stats.onChange.listen((it) => _apply(it.now));
  }

  void _apply(StatsSection<UiStats> section, {bool initial = false}) {
    final data = section.data;
    final hasStats = data != null;
    final blocked = data?.dayBlocked.toDouble() ?? counter;
    final error = section.isError;
    // Refreshes usually return the same numbers; rebuilding would replay the count-up.
    if (blocked == counter && hasStats == _hasStats && error == _error) return;

    void update() {
      lastCounter = counter;
      counter = blocked;
      _hasStats = hasStats;
      _error = error;
    }

    if (initial) {
      update();
    } else if (mounted) {
      setState(update);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Disabled while a route covers Home.
    final tickerMode = TickerMode.getNotifier(context);
    if (tickerMode != _tickerMode) {
      _tickerMode?.removeListener(_syncRefresh);
      _tickerMode = tickerMode..addListener(_syncRefresh);
    }
    _syncRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncRefresh();
  }

  void _syncRefresh() {
    final refresh = _shouldRefresh;
    if (refresh == _refreshing) return;
    _refreshing = refresh;
    _stats.setHomeRefresh(refresh);
  }

  @override
  void dispose() {
    if (_refreshing) _stats.setHomeRefresh(false);
    _statsSub?.cancel();
    _tickerMode?.removeListener(_syncRefresh);
    for (final dispose in _disposers) {
      dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // A failed refresh keeps the last count on screen; the retry is only for
  // a card that has nothing to show.
  bool get _showRetry => _error && !_hasStats;

  void _onTap() {
    if (_showRetry) {
      unawaited(_stats.retry(Markers.userTap, StatsPart.stats));
      return;
    }
    Navigation.open(Paths.privacyPulse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    final Widget big;
    if (_showRetry) {
      big = Icon(Icons.refresh, size: 34, color: theme.textSecondary);
    } else if (_hasStats) {
      big = MiniCardCounter(counter: counter, lastCounter: lastCounter);
    } else {
      // Still loading. Off screen while protection is off, so no shimmer then.
      big = LoadingPlaceholder(
        animate: _active,
        child: const SizedBox(
          height: 40,
          child: Center(child: PlaceholderBar(width: 96, height: 28, radius: 6)),
        ),
      );
    }

    return MiniCard(
      onTap: _onTap,
      outlined: true,
      child: MiniCardSummary(
        header: MiniCardHeader(
          text: "stats header day".i18n,
          icon: Icons.shield_outlined,
          color: (_app.status == AppStatus.activatedPlus) ? theme.accent : theme.cloud,
          chevronIcon: Icons.bar_chart,
        ),
        big: big,
        small: "",
        footer: _showRetry
            ? "universal action try again".i18n
            : "home counter caption blocked".i18n,
      ),
    );
  }
}
