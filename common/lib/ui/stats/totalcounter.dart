import 'package:common/service/I18nService.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/widget/minicard/header.dart';
import '../../common/widget/minicard/minicard.dart';
import '../../common/widget/minicard/summary.dart';
import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';

class TotalCounter extends StatefulWidget {
  TotalCounter({Key? key, required bool this.autoRefresh}) : super(key: key);

  final bool autoRefresh;

  @override
  State<StatefulWidget> createState() {
    return TotalCounterState(autoRefresh: this.autoRefresh);
  }
}

class TotalCounterState extends State<TotalCounter> with TraceOrigin {
  TotalCounterState({required bool this.autoRefresh});

  static const shareChannel = MethodChannel('share');

  final bool autoRefresh;

  final _stats = dep<StatsStore>();
  final _stage = dep<StageStore>();

  var allowed = 0.0;
  var blocked = 0;
  var lastAllowed = 0.0;
  var lastBlocked = 0;

  @override
  void initState() {
    super.initState();
    final stats = _stats.statsForSelectedDevice();
    setState(() {
      lastAllowed = allowed;
      lastBlocked = blocked;
      allowed = stats.totalAllowed.toDouble();
      blocked = stats.totalBlocked;
    });

    if (autoRefresh) {
      reactionOnStore((_) => _stats.deviceStatsChangesCounter, (_) async {
        if (!mounted) return;
        final stats = _stats.statsForSelectedDevice();
        setState(() {
          lastAllowed = allowed;
          lastBlocked = blocked;
          allowed = stats.totalAllowed.toDouble();
          blocked = stats.totalBlocked;
        });
      });
    }
  }

  Future<void> _shareCounter() async {
    traceAs("tappedShareAdsCounter", (trace) async {
      await _stage.showModal(trace, StageModal.adsCounterShare);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniCard(
      child: MiniCardSummary(
        header: MiniCardHeader(
          text: "stats header all time".i18n,
          icon: Icons.timelapse,
          color: Colors.red,
          chevronIcon: Icons.ios_share_outlined,
        ),
        // bigText: _formatCounter(blocked),
        big: Text(StatsStoreBase.formatCounter(blocked),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
            )),
        small: "",
        footer: _getBlockedText(),
      ),
      onTap: () {
        _shareCounter();
      },
    );
  }
}

// To not introduce another string, a bit lame
String _getBlockedText() {
  return "home status detail active with counter"
      .i18n
      .replaceAll("*", "")
      .split("%s")
      .map((e) => e.trim())
      .join(" ");
}
