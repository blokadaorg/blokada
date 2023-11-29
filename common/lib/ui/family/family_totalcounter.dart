import 'package:common/service/I18nService.dart';
import 'package:common/stage/channel.pg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../../stage/stage.dart';
import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../../util/trace.dart';
import '../minicard/counter.dart';
import '../minicard/header.dart';
import '../minicard/minicard.dart';
import '../minicard/summary.dart';

class FamilyTotalCounter extends StatefulWidget {
  FamilyTotalCounter({Key? key, required bool this.autoRefresh})
      : super(key: key);

  final bool autoRefresh;

  @override
  State<StatefulWidget> createState() {
    return FamilyTotalCounterState(autoRefresh: this.autoRefresh);
  }
}

class FamilyTotalCounterState extends State<FamilyTotalCounter>
    with TraceOrigin {
  FamilyTotalCounterState({required bool this.autoRefresh});

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
    final stats = _stats.totalStats();
    setState(() {
      lastAllowed = allowed;
      lastBlocked = blocked;
      allowed = stats.totalAllowed.toDouble();
      blocked = stats.totalBlocked;
    });

    if (autoRefresh) {
      reactionOnStore((_) => _stats.deviceStatsChangesCounter, (_) async {
        if (!mounted) return;
        final stats = _stats.totalStats();
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
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(_stats.formatCounter(blocked),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                )),
            SizedBox(width: 32),
            Icon(Icons.ios_share_outlined),
          ],
        ),
      ),
      onTap: () {
        _shareCounter();
      },
    );
  }
}
