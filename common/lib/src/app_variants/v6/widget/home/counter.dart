import 'dart:async';

import 'package:common/src/shared/navigation.dart';
import 'package:common/src/shared/ui/minicard/counter.dart';
import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/minicard/summary.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/app/app.dart';
import 'package:common/src/platform/app/channel.pg.dart';
import 'package:common/src/platform/device/device.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart' as mobx;

/// Home's "Last 24h" card: the number of requests blocked on this device in
/// the last 24 hours.
///
/// It stays mounted while protection is off (slid off screen by HomeActions),
/// so it refreshes only while protection is on, the app is in the foreground
/// and Home is not covered by another route.
class HomeCounter extends StatefulWidget {
  const HomeCounter({super.key});

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

const _refreshInterval = Duration(seconds: 30);

class _HomeCounterState extends State<HomeCounter> with WidgetsBindingObserver, Logging {
  final _app = Core.get<AppStore>();
  final _stats = Core.get<StatsStore>();
  final _device = Core.get<DeviceStore>();

  double counter = 0.0;
  double lastCounter = 0.0;
  bool _hasStats = false;

  Timer? _refreshTimer;
  bool _active = false;
  bool _foreground = true;
  ValueListenable<bool>? _tickerMode;
  String? _lastFetchedAlias;

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
        _syncRefresh();
      }),
    );

    // A new alias means a different device name for the stats query.
    _lastFetchedAlias = _device.deviceAlias;
    _disposers.add(
      mobx.reaction<String>((_) => _device.deviceAlias, (alias) {
        if (alias.isEmpty || alias == _lastFetchedAlias) return;
        _lastFetchedAlias = alias;
        if (_shouldRefresh) _fetch(force: true);
      }),
    );

    _disposers.add(
      mobx.autorun((_) {
        final blocked = _stats.stats.dayBlocked.toDouble();
        final hasStats = _stats.hasStats;
        // Refreshes usually return the same numbers; rebuilding would replay the count-up.
        if (!mounted || (blocked == counter && hasStats == _hasStats)) return;
        setState(() {
          lastCounter = counter;
          counter = blocked;
          _hasStats = hasStats;
        });
      }),
    );
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
    if (_shouldRefresh) {
      if (_refreshTimer != null) return;
      _fetch(force: false);
      _refreshTimer = Timer.periodic(_refreshInterval, (_) => _fetch(force: true));
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _fetch({required bool force}) {
    _stats.fetchDay(Markers.stats, force: force).catchError((Object e) {
      log(Markers.stats).e(msg: "homeCounter: fetchDay failed: $e");
      return _stats.stats;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tickerMode?.removeListener(_syncRefresh);
    for (final dispose in _disposers) {
      dispose();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTap() {
    Navigation.open(Paths.privacyPulse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
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
        big: _hasStats
            ? MiniCardCounter(counter: counter, lastCounter: lastCounter)
            : const Text("...", style: TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
        small: "",
        footer: "home counter caption blocked".i18n,
      ),
    );
  }
}
