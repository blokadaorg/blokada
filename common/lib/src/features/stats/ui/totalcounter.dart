import 'package:common/src/features/config/domain/config.dart';
import 'package:common/src/core/core.dart';
import 'package:common/src/platform/stats/model.dart';
import 'package:common/src/platform/stats/stats.dart';
import 'package:common/src/shared/ui/motion.dart';
import 'package:common/src/shared/ui/theme.dart';
import 'package:flutter/material.dart';

import 'package:common/src/shared/ui/minicard/header.dart';
import 'package:common/src/shared/ui/minicard/minicard.dart';
import 'package:common/src/shared/ui/minicard/summary.dart';

class TotalCounter extends StatefulWidget {
  final UiStats stats;

  TotalCounter({Key? key, required this.stats}) : super(key: key);

  @override
  State<StatefulWidget> createState() => TotalCounterState();
}

class TotalCounterState extends State<TotalCounter> with Logging {
  late final _channel = Core.get<ConfigChannel>();

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
    log(Markers.userTap).trace("tappedShareAdsCounter", (m) async {
      await _channel.doShareText("main share message".i18n.withParams(blocked));
    });
  }

  /// Counts up to the total, like the other Pulse numbers, keeping the
  /// short 12.3K form on the way. With Reduce Motion it shows the total.
  Widget _buildBig(BuildContext context) {
    final style = context.theme.text.display;
    if (Motion.reduced(context)) {
      return Text(StatsStoreBase.formatCounter(blocked), style: style);
    }
    // Starts from zero once, then moves from the shown value to a new total.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: blocked.toDouble()),
      duration: const Duration(seconds: 1),
      builder: (context, value, _) =>
          Text(StatsStoreBase.formatCounter(value.round()), style: style),
    );
  }

  @override
  Widget build(BuildContext context) {
    _calculate();
    return MiniCard(
      child: MiniCardSummary(
        header: MiniCardHeader(
          text: "stats header all time".i18n,
          icon: Icons.timelapse,
          color: context.theme.blocked,
          textColor: context.theme.textBlocked,
          chevronIcon: Icons.ios_share_outlined,
        ),
        // bigText: _formatCounter(blocked),
        big: _buildBig(context),
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
