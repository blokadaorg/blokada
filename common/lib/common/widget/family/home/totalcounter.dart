import 'package:common/stage/channel.pg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:vistraced/via.dart';

import '../../../model.dart';
import '../../../widget.dart';
import '../../../../stats/stats.dart';
import '../../../../util/trace.dart';

part 'totalcounter.g.dart';

class FamilyTotalCounter extends StatefulWidget {
  FamilyTotalCounter({Key? key, required bool this.autoRefresh})
      : super(key: key);

  final bool autoRefresh;

  @override
  State<StatefulWidget> createState() => _$FamilyTotalCounterState();
}

@Injected(onlyVia: true, immediate: true)
class FamilyTotalCounterState extends State<FamilyTotalCounter>
    with TraceOrigin {
  FamilyTotalCounterState();

  late final _stats = Via.as<UiStats>()..also(rebuild);
  late final _modal = Via.as<StageModal?>();

  var allowed = 0.0;
  var blocked = 0;
  var lastAllowed = 0.0;
  var lastBlocked = 0;

  @override
  void initState() {
    super.initState();

    // if (autoRefresh) {
    //   reactionOnStore((_) => _stats.deviceStatsChangesCounter, (_) async {
    //     if (!mounted) return;
    //     final stats = _stats.totalStats();
    //     setState(() {
    //       lastAllowed = allowed;
    //       lastBlocked = blocked;
    //       allowed = stats.totalAllowed.toDouble();
    //       blocked = stats.totalBlocked;
    //     });
    //   });
    // }
  }

  rebuild() {
    setState(() {
      final stats = _stats.now;
      setState(() {
        lastAllowed = allowed;
        lastBlocked = blocked;
        allowed = stats.totalAllowed.toDouble();
        blocked = stats.totalBlocked;
      });
    });
  }

  Future<void> _shareCounter() async {
    traceAs("tappedShareAdsCounter", (trace) async {
      await _modal.set(StageModal.adsCounterShare);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniCard(
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(StatsStoreBase.formatCounter(blocked),
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
