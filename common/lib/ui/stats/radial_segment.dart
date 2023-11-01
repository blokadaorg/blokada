import 'package:common/service/I18nService.dart';
import 'package:countup/countup.dart';
import 'package:flutter/material.dart';

import 'package:mobx/mobx.dart' as mobx;

import '../../stats/stats.dart';
import '../../util/di.dart';
import '../../util/mobx.dart';
import '../theme.dart';
import 'radial_chart.dart';

class RadialSegment extends StatefulWidget {
  final bool autoRefresh;

  const RadialSegment({Key? key, required this.autoRefresh}) : super(key: key);

  @override
  State<StatefulWidget> createState() => RadialSegmentState();
}

class RadialSegmentState extends State<RadialSegment> {
  final _store = dep<StatsStore>();

  var stats = UiStats.empty();
  var blocked = 0.0;
  var allowed = 0.0;
  var total = 0.0;
  var lastBlocked = 0.0;
  var lastAllowed = 0.0;
  var lastTotal = 0.0;

  @override
  void initState() {
    super.initState();
    setState(() {
      stats = _store.statsForSelectedDevice();
    });

    if (widget.autoRefresh) {
      reactionOnStore((_) => _store.deviceStatsChangesCounter, (_) async {
        setState(() {
          stats = _store.statsForSelectedDevice();

          lastAllowed = allowed;
          lastBlocked = blocked;
          lastTotal = total;
          allowed = stats.dayAllowed.toDouble();
          blocked = stats.dayBlocked.toDouble();
          total = stats.dayTotal.toDouble();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).extension<BlokadaTheme>()!;
    return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("stats label blocked".i18n,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xffff3b30),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        )),
                    Countup(
                      begin: lastBlocked,
                      end: blocked,
                      duration: const Duration(seconds: 1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: SizedBox(
                  height: 44,
                  child: VerticalDivider(
                    color: theme.divider,
                    thickness: 1.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("stats label allowed".i18n,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xff33c75a),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        )),
                    Countup(
                      begin: lastAllowed,
                      end: allowed,
                      duration: const Duration(seconds: 1),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Padding(
              //   padding: const EdgeInsets.only(top: 4.0),
              //   child: SizedBox(
              //     height: 44,
              //     child: VerticalDivider(
              //       color: theme.divider,
              //       thickness: 1.0,
              //     ),
              //   ),
              // ),
              // Padding(
              //   padding: const EdgeInsets.all(4.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text("stats label total".i18n,
              //           maxLines: 1,
              //           style: const TextStyle(
              //             color: Color(0xff838383),
              //             fontSize: 14,
              //             fontWeight: FontWeight.w600,
              //           )),
              //       // Countup(
              //       //   begin: lastTotal,
              //       //   end: total,
              //       //   duration: Duration(seconds: 1),
              //       //   style: TextStyle(
              //       //     fontSize: 20,
              //       //     fontWeight: FontWeight.w600,
              //       //   ),
              //       Text(_formatCounter(total.toInt()),
              //           style: const TextStyle(
              //             fontSize: 20,
              //             fontWeight: FontWeight.w600,
              //           )),
              //     ],
              //   ),
              // ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 96,
            height: 96,
            child: RadialChart(stats: stats),
          ),
        ]);
  }
}

String _formatCounter(int counter) {
  if (counter >= 1000000) {
    return "${(counter / 1000000.0).toStringAsFixed(2)}M";
    //} else if (counter >= 1000) {
    //  return "${(counter / 1000.0).toStringAsFixed(1)}K";
  } else {
    return "$counter";
  }
}
