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
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mobx/mobx.dart' as mobx;

class HomeCounter extends StatefulWidget {
  const HomeCounter({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _HomeCounterState();
  }
}

class _HomeCounterState extends State<HomeCounter>
    with TickerProviderStateMixin, WidgetsBindingObserver, Logging {
  final _app = Core.get<AppStore>();
  final _stats = Core.get<StatsStore>();
  final _device = Core.get<DeviceStore>();

  double counter = 0.0;
  double lastCounter = -1.0;
  Future<void>? _pendingFetch;
  late final AnimationController _ticker;
  bool _tickerRunning = false;
  mobx.ReactionDisposer? _deviceAliasDisposer;
  String? _lastFetchedAlias;

  @override
  void initState() {
    super.initState();

    _pendingFetch = _stats.fetchDay(Markers.stats);

    // Track the current alias to avoid double-fetching when it's already set
    _lastFetchedAlias = _device.deviceAlias;

    _deviceAliasDisposer = mobx.reaction<String>(
      (_) => _device.deviceAlias,
      (alias) {
        if (alias.isEmpty) return;
        if (_lastFetchedAlias == alias) return;
        _lastFetchedAlias = alias;
        _stats.fetchDay(Markers.stats, force: true);
      },
      fireImmediately: true,
    );

    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..addStatusListener(_onTick);
    _startTicker();

    mobx.autorun((_) {
      final stats = _stats.stats;

      setState(() {
        if (lastCounter < 0) {
          lastCounter = 0;
        } else {
          lastCounter = counter;
        }
        counter = stats.dayTotal.toDouble();
      });
    });
  }

  void _onTick(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _stats.fetchDay(Markers.stats, force: true);
      _ticker.forward(from: 0);
    }
  }

  void _startTicker() {
    if (_tickerRunning) return;
    _tickerRunning = true;
    _ticker.forward(from: 0);
  }

  void _stopTicker() {
    if (!_tickerRunning) return;
    _tickerRunning = false;
    _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startTicker();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    _ticker.dispose();
    _deviceAliasDisposer?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _onTap() {
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
        big: counter == 0
            ? const Text("...",
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                ))
            : MiniCardCounter(counter: counter, lastCounter: lastCounter),
        small: "",
        footer: "home status detail active".i18n.replaceAll("*", ""),
      ),
    );
  }
}
