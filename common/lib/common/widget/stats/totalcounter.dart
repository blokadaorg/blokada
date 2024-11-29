import 'package:common/core/core.dart';
import 'package:common/family/module/stats/stats.dart';
import 'package:common/platform/stage/channel.pg.dart';
import 'package:flutter/material.dart';

import '../../../../common/widget/minicard/header.dart';
import '../../../../common/widget/minicard/minicard.dart';
import '../../../../common/widget/minicard/summary.dart';
import '../../../platform/stage/stage.dart';
import '../../../platform/stats/stats.dart';

class TotalCounter extends StatefulWidget {
  final UiStats stats;

  TotalCounter({Key? key, required this.stats}) : super(key: key);

  @override
  State<StatefulWidget> createState() => TotalCounterState();
}

class TotalCounterState extends State<TotalCounter> with Logging {
  late final _stage = DI.get<StageStore>();

  var allowed = 0.0;
  var blocked = 0;
  var lastAllowed = 0.0;
  var lastBlocked = 0;

  _calculate() {
    //setState(() {
    lastAllowed = allowed;
    lastBlocked = blocked;
    allowed = widget.stats.totalAllowed.toDouble();
    blocked = widget.stats.totalBlocked;
    //});
  }

  Future<void> _shareCounter() async {
    await _stage.showModal(StageModal.adsCounterShare, Markers.userTap);
  }

  @override
  Widget build(BuildContext context) {
    _calculate();
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
